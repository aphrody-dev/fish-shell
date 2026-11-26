#RUN: fish=%fish %fish %s

# Scripts and `fish -c` read universal variables but do not write them back.
set -e FISH_SAVE_UVARS
set -l vars $__fish_config_dir/fish_variables

$fish -c 'set -U __uvar_script 1; echo in-session $__uvar_script'
# CHECK: in-session 1
$fish -c 'set -q __uvar_script; or echo not-saved'
# CHECK: not-saved
test -e $vars; and string match -q '*__uvar_script*' <$vars; or echo file-untouched
# CHECK: file-untouched

# FISH_SAVE_UVARS=1 writes them.
FISH_SAVE_UVARS=1 $fish -c 'set -U __uvar_script 2'
$fish -c 'echo saved $__uvar_script'
# CHECK: saved 2
FISH_SAVE_UVARS=1 $fish -c 'set -Ue __uvar_script'
