//! `fish -c` hands POSIX shell code to a POSIX shell.
//!
//! Tools that run commands through the login shell (sshd, CI runners, agents) send bash
//! one-liners. When fish is the login shell, a command string that fish cannot run as fish
//! is executed by `$FISH_POSIX_SHELL` (default `/bin/bash`) instead.
//!
//! `$FISH_POSIX_FALLBACK` controls it: `0` turns it off, `always` hands every `-c` string to the
//! POSIX shell, and anything else (or unset) does so only for strings that are not fish.

use crate::{
    ast::{self, Kind, Node as _, Traversal},
    parse_constants::ParseTreeFlags,
    parse_util::detect_parse_errors_in_ast,
    prelude::*,
};

/// Commands that exist in POSIX shells but not in fish, so fish could only fail on a job that
/// runs them.
const POSIX_ONLY_COMMANDS: &[&str] = &[
    "compgen",
    "declare",
    "done",
    "esac",
    "fi",
    "getopts",
    "let",
    "local",
    "mapfile",
    "readarray",
    "readonly",
    "select",
    "shopt",
    "then",
    "typeset",
    "unset",
    "until",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Off,
    NotFish,
    Always,
}

impl Mode {
    pub fn from_env(value: Option<&std::ffi::OsStr>) -> Self {
        match value.and_then(|v| v.to_str()) {
            Some("0") => Self::Off,
            Some("always") => Self::Always,
            _ => Self::NotFish,
        }
    }
}

/// Whether `src` should be run by a POSIX shell: it does not parse as fish, or it calls a
/// command that only POSIX shells have, or it uses bash's `set` options.
pub fn is_posix_only(src: &wstr) -> bool {
    let ast = ast::parse(src, ParseTreeFlags::default(), None);
    if ast.errored() || detect_parse_errors_in_ast(&ast, src, None).is_err() {
        return true;
    }
    Traversal::new(ast.top()).any(|node| match node.kind() {
        Kind::DecoratedStatement(stmt) => statement_is_posix_only(stmt, src),
        _ => false,
    })
}

/// Whether an argument of `src` has a `*` outside quotes. fish fails a command whose wildcard
/// matches nothing, where POSIX shells pass the word on: `rm -f *.tmp && …` stops in fish.
pub fn has_unquoted_wildcard(src: &wstr) -> bool {
    let ast = ast::parse(src, ParseTreeFlags::default(), None);
    Traversal::new(ast.top()).any(|node| match node.kind() {
        Kind::Argument(arg) => arg.try_source(src).is_some_and(word_has_unquoted_star),
        _ => false,
    })
}

fn word_has_unquoted_star(word: &wstr) -> bool {
    let mut quote = None;
    let mut escaped = false;
    for c in word.chars() {
        match (quote, c) {
            _ if escaped => escaped = false,
            (Some('\''), '\'') | (Some('"'), '"') => quote = None,
            (Some('\''), _) => {}
            (_, '\\') => escaped = true,
            (None, '\'' | '"') => quote = Some(c),
            (None, '*') => return true,
            _ => {}
        }
    }
    false
}

fn statement_is_posix_only(stmt: &ast::DecoratedStatement, src: &wstr) -> bool {
    if stmt.opt_decoration.is_some() {
        return false;
    }
    let Some(command) = stmt.command.try_source(src) else {
        return false;
    };
    // fish reads `[[ -n $x ]]` as one token.
    if command.starts_with("[[") || POSIX_ONLY_COMMANDS.iter().any(|c| command == *c) {
        return true;
    }
    if command != "set" {
        return false;
    }
    let args: Vec<&wstr> = stmt
        .args_or_redirs
        .iter()
        .filter(|a| a.is_argument())
        .filter_map(|a| a.argument().try_source(src))
        .collect();
    // fish's `set` has no `-o`, takes no `+` options, and needs a name after its flags.
    // `set -e`, `set -euo pipefail` and `set +x` are bash.
    let is_option = |a: &&wstr| (a.starts_with('-') || a.starts_with('+')) && *a != "--";
    let is_bash_short_option = |a: &&wstr| {
        a.starts_with('+') || (!a.starts_with("--") && a.starts_with('-') && a.contains('o'))
    };
    !args.is_empty() && (args.iter().all(is_option) || args.iter().any(is_bash_short_option))
}

#[cfg(test)]
mod tests {
    use super::{Mode, is_posix_only};
    use crate::prelude::*;
    use crate::tests::prelude::*;
    use std::ffi::OsStr;

    #[test]
    fn test_posix_only() {
        test_init();
        for posix in [
            "for f in *; do echo $f; done",
            "x=${y#z}; echo $x",
            "[ -f a ] && echo ${HOME:-/}",
            "cat <<EOF\nhi\nEOF",
            "[[ -n $x ]] && echo yes",
            "false; echo $?",
            "case $1 in a) echo a;; esac",
            "if true; then echo; fi",
            "while read l; do echo $l; done < f",
            "f() { echo hi; }; f",
            "local x=1",
            "set -euo pipefail; make",
            "set -e",
            "set +x",
            "echo $((1 + 2))",
            "echo $#",
        ] {
            assert!(
                is_posix_only(&WString::from_str(posix)),
                "should be POSIX: {posix}"
            );
        }
        for fish in [
            "echo hi",
            "for f in *; echo $f; end",
            "set -l x 1; echo $x",
            "set -e PATH[1]",
            "set -gx FOO bar",
            "[ -f a ] && echo yes || echo no",
            "x=1; echo $x",
            "git upload-pack '/srv/repo.git'",
            "scp -t /tmp",
            "rsync --server -vlogDtpre.iLsfxCIvu . /tmp/x",
            "if test -d /tmp; echo dir; end",
            "echo (date) $(date)",
            "cd /tmp && FOO=1 env",
            "set",
        ] {
            assert!(
                !is_posix_only(&WString::from_str(fish)),
                "should be fish: {fish}"
            );
        }
    }

    #[test]
    fn test_unquoted_wildcard() {
        test_init();
        for (src, star) in [
            ("rm -f *.tmp && echo ok", true),
            ("ls /tmp/x-*.log", true),
            ("echo '*' \"a*b\" \\*", false),
            ("echo hi", false),
            ("for f in *.rs; echo $f; end", true),
        ] {
            assert_eq!(
                super::has_unquoted_wildcard(&WString::from_str(src)),
                star,
                "{src}"
            );
        }
    }

    #[test]
    fn test_mode() {
        assert_eq!(Mode::from_env(None), Mode::NotFish);
        assert_eq!(Mode::from_env(Some(OsStr::new("0"))), Mode::Off);
        assert_eq!(Mode::from_env(Some(OsStr::new("always"))), Mode::Always);
        assert_eq!(Mode::from_env(Some(OsStr::new("1"))), Mode::NotFish);
    }
}
