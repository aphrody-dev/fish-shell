# Fleet: installed in /etc/fish/conf.d (see FLEET.md), where it replaces the vendor flatpak.fish of
# the same name. The vendor file runs `flatpak --installations` (~48 ms) at every start; only
# interactive sessions need the XDG_DATA_DIRS it sets.
set -l vendor /usr/share/fish/vendor_conf.d/flatpak.fish
status is-interactive; and test -r $vendor; and source $vendor
