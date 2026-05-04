#!/bin/bash

# Visual Studio Code Wrapper (Arch Linux Style)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# 1. Load user flags
if [[ -f $XDG_CONFIG_HOME/code-flags.conf ]]; then
   CODE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/code-flags.conf | tr '\n' ' ')"
fi

# 2. Arch Style: Set environment to run the CLI bridge as Node
export ELECTRON_RUN_AS_NODE=1

# 3. Arch Style: Launch sequence
# System Electron -> Official CLI Bridge -> Path Loader -> App Logic
exec /usr/bin/electron39 \
    /opt/visual-studio-code/resources/app/out/cli.js \
    /opt/visual-studio-code/code-loader.mjs \
    "$@" $CODE_USER_FLAGS
