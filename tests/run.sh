#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/ghostnotes-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
export GHOSTNOTES_ROOT="$ROOT"
export GHOSTNOTES_TEST_WORK="$TEST_ROOT/work"
export XDG_DATA_HOME="$TEST_ROOT/data"
export XDG_STATE_HOME="$TEST_ROOT/state"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
mkdir -p "$GHOSTNOTES_TEST_WORK"

run_test() {
  nvim --headless -u NONE -i NONE \
    -c 'lua vim.opt.runtimepath:prepend(vim.env.GHOSTNOTES_ROOT)' \
    -c "lua local ok, err = xpcall(function() dofile(vim.env.GHOSTNOTES_ROOT .. '/tests/$1.lua') end, debug.traceback); if not ok then io.stderr:write(err .. '\\n'); vim.cmd('cquit 1') end" \
    -c 'qa!'
}

run_test core

# Set these variables to test with other checkouts, for example in CI.
SNACKS_DIR=${SNACKS_DIR:-"$HOME/.local/share/nvim/lazy/snacks.nvim"}
TELESCOPE_DIR=${TELESCOPE_DIR:-"$HOME/.local/share/nvim/lazy/telescope.nvim"}
PLENARY_DIR=${PLENARY_DIR:-"$HOME/.local/share/nvim/lazy/plenary.nvim"}
export SNACKS_DIR TELESCOPE_DIR PLENARY_DIR

if [ -f "$SNACKS_DIR/lua/snacks/init.lua" ]; then
  GHOSTNOTES_TEST_PICKER=snacks run_test picker
else
  printf '%s\n' 'SKIP Snacks integration (set SNACKS_DIR)'
fi

if [ -f "$TELESCOPE_DIR/lua/telescope/init.lua" ] && [ -d "$PLENARY_DIR/lua/plenary" ]; then
  GHOSTNOTES_TEST_PICKER=telescope run_test picker
else
  printf '%s\n' 'SKIP Telescope integration (set TELESCOPE_DIR and PLENARY_DIR)'
fi

if [ -f "$SNACKS_DIR/lua/snacks/init.lua" ] && [ -f "$TELESCOPE_DIR/lua/telescope/init.lua" ] && [ -d "$PLENARY_DIR/lua/plenary" ]; then
  run_test auto
fi
