# Fleet: installed in /etc/fish/conf.d (see FLEET.md).
# Non-interactive fish (ssh one-liners, CI steps, agents) prints no colour unless stdout is a
# terminal. Interactive sessions are unchanged.
status is-interactive; and return
isatty stdout; or function set_color --description 'no colour: not interactive, not a terminal'
end
