# fish for the build fleet

Branch `aphrody/fleet` of fish-shell/fish-shell, for hosts that run `ssh host '<one-liner>'`
with fish as the login shell. Binary: `n1:/srv/xbuild/scratch/fish/fish`, built by
`build_tools/build_fleet.sh`.

## Changes

- **Bare POSIX assignments.** A job that is only `VAR=value` words runs like `set VAR value`
  without scope options: an existing variable is updated in its own scope and keeps its export
  flag, and a new one is local to the function, or global at top level. Words run left to right: `G="x"; $G`, `a=1 b=$a`, `x=$(cmd) && ...` and `a=` work. `$status` is that of the last
  command substitution, or 0. It is still an error in a pipeline (`: | a=b`), after
  `not`, or with a redirection, as before. Not upstream: fish has always refused it
  (#8359, #9760). Code: `src/ast.rs` (the parser accepts it only at the head of a job),
  `src/parse_execution.rs` (`run_bare_assignments`), `src/parse_util.rs` (a `(cmd)` in the
  value is not a command substitution in command position). Tests: `tests/checks/variable-assignment.fish`,
  `tests/checks/invocation.fish`, `src/parser.rs`.
- **Lean build.** `[profile.fleet]` (release + one codegen unit + `panic=abort`; the panic
  hook still runs) and `build_tools/build_fleet.sh`: no default features (no man pages,
  which need sphinx, and no message catalogs), `-C target-cpu=x86-64-v3` (n1, n2 and n3 support it),
  and `-C relocation-model=static`, which builds a non-PIE executable. The loader then applies
  223 relocations instead of 12674 (44008 with message catalogs), and that is where the
  startup time goes.
- **Upstream PRs taken:**
  - #13100 `history: mark map_file unsafe`: makes a safety requirement explicit, and the code is unchanged.
  - #13033 `Prefer HOME when initializing PWD`: ssh starts fish without `PWD`. When HOME is a
    symlink, `$PWD` is now `~` instead of the physical path.
  - #13105 `fish_default_mode_prompt: printf instead of echo`: trivial.

## Rejected

- #12970 function path cache: the reviewer says it skips IO it needs, and the PR is unfinished.
- #12741 `--no-config` without private mode: changes behavior, has no review, and the fleet does not need it.
- #12008 retry writes on EINTR: the author abandoned it. #12069 ENAMETOOLONG: open review issues.
- #13061 tinyexpr rewrite, #10840 removal of IFS, #12095 and #12939 (large interactive features):
  too big or risky, and they do nothing for non-interactive `-c`.
- Active forks: none is ahead of upstream with anything relevant. faho has 1 commit (zigbuild static
  build), Berrysoft has Cygwin work, and the others are 0 ahead.
- Not reading config when not interactive (#5394): this would break the PATH setup that ssh
  one-liners rely on.

## Startup (hyperfine -N, 50 warmup, 1000 runs, empty HOME)

n1 (12c, load 50-100 from other jobs during the run, so expect noise). Means in ms:

| fish -c          | upstream release | fleet profile, PIE | fleet (non-PIE) | fleet, no l10n, non-PIE (deployed) |
|------------------|-----------------:|-------------------:|----------------:|-----------------------------------:|
| `--no-config true` | 2.5 | 2.8 | 1.7 | **1.6** |
| `true` (fish config only) | 4.7 | 3.9 | 3.2 | **3.2** |
| one-liner loop   | 10.9 | 11.8 | 10.1 | 11.7 |
| `true` with host vendor_conf.d | 27.4 | 26.2 | 25.3 | **22.7** |

n2 (8c, CachyOS, load ~3), `--no-config -c true`: system fish 4.9.3 is 4.6 ms, upstream 4.5 ms, deployed 3.3 ms.

The profile alone (LTO is already in upstream's release profile, plus one codegen unit, abort and v3)
is within noise. The non-PIE link is a consistent 1.3-1.5x on bare startup.
On a real host most of the time is in the distro's `vendor_conf.d`. On n1,
`flatpak.fish` runs `flatpak --installations` at every start, which takes ~48 of ~50 ms in
`fish --profile-startup`. To fix that, guard it with `status is-interactive`, or remove it on fleet hosts.

## Tests (n1, debug build)

At this branch's head:
- `cargo test --workspace`: 180 passed, 1 failed.
- `tests/test_driver.py`: 244 of 249 passed, 8 skipped, at load 100. In an earlier full run at load 20, 247 of 249 passed.

Failures that unmodified upstream master also has on n1:
`test_history_external_rewrite_increases_last_added_timestamp`, `tmux-abbr.fish`, and
`check-completions.fish` (the cpupower wrapper writes to stderr).

`tmux-invocation.fish`, `tmux-set.fish` and `pexpects/wait.py` failed only under load and pass when rerun.
`wait.py` also fails now and then on upstream.
