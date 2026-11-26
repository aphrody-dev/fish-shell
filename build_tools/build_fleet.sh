#!/bin/sh

# Build the lean fish used on the build fleet (see FLEET.md).
# Usage: build_tools/build_fleet.sh [OUT]   (default OUT: target/fleet-fish)
#
# - profile "fleet": fat LTO, one codegen unit, panic=abort
# - no default features: no embedded man pages (needs sphinx), no message catalogs
# - x86-64-v3 and a non-PIE executable: the loader applies ~200 relocations instead of
#   ~13000 (~44000 with message catalogs).
#   --target keeps these RUSTFLAGS away from proc-macros and build scripts.

set -e

target=x86_64-unknown-linux-gnu
out=${1:-target/fleet-fish}

# build.rs computes the version from git but has no rerun-if-changed for it.
touch build.rs
RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C target-cpu=x86-64-v3 -C relocation-model=static" \
    cargo build --locked --target "$target" --profile fleet --no-default-features --bin fish

cp "${CARGO_TARGET_DIR:-target}/$target/fleet/fish" "$out"
echo "$out"
