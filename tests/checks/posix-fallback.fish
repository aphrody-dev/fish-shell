#RUN: fish=%fish %fish %s
#REQUIRES: test -x /bin/bash

# `fish -c` runs POSIX shell code with $FISH_POSIX_SHELL (default /bin/bash).
set -gx FISH_POSIX_FALLBACK 1

$fish -c 'for f in a b; do echo "loop $f"; done'
# CHECK: loop a
# CHECK: loop b

$fish -c 'y=zfoo; x=${y#z}; echo "$x ${BASH_VERSION:+bash}"'
# CHECK: foo bash

$fish -c 'cat <<EOF
heredoc $((1 + 2))
EOF'
# CHECK: heredoc 3

$fish -c '[[ -n "a" && 1 -lt 2 ]] && echo dbl'
# CHECK: dbl

$fish -c 'false; echo "status $?"'
# CHECK: status 1

$fish -c 'case x in x) echo case;; *) echo no;; esac'
# CHECK: case

$fish -c 'set -euo pipefail; echo strict'
# CHECK: strict

# Positional arguments and the exit status carry over.
$fish -c '[[ -n $1 ]] && echo "$0 $1 $2"; exit 3' one two
# CHECK: bash one two
echo $status
# CHECK: 3

# Same working directory and environment.
cd /
FOO=bar $fish -c 'f() { echo "$PWD $FOO"; }; f'
# CHECK: / bar
cd -

# fish code still runs in fish.
$fish -c 'for f in a b; echo fish $f; end; set -l x (echo 1); echo $x'
# CHECK: fish a
# CHECK: fish b
# CHECK: 1
$fish -c 'x=1 b=$x; echo $x$b; set -q BASH_VERSION; or echo not-bash'
# CHECK: 11
# CHECK: not-bash

# always: every -c string goes to the POSIX shell.
FISH_POSIX_FALLBACK=always $fish -c 'echo ${BASH_VERSION:+always}'
# CHECK: always

# 0 turns it off: fish reports the error.
FISH_POSIX_FALLBACK=0 $fish -c 'echo ${x}'
# CHECKERR: fish: Variables cannot be bracketed. In fish, please use {$x}.
# CHECKERR: {{^}}echo ${x}
# CHECKERR: {{^}}      ^

# Interactive sessions never fall back.
$fish -i -c 'echo ${x}' 2>&1 | string match -q '*Variables cannot be bracketed*'
and echo interactive-fish
# CHECK: interactive-fish

# Another POSIX shell can be chosen; fish itself is never chosen.
FISH_POSIX_SHELL=/bin/sh $fish -c 'echo "${0}"'
# CHECK: sh
FISH_POSIX_SHELL=$fish $fish -c 'echo ${x}' 2>/dev/null
or echo refused
# CHECK: refused
