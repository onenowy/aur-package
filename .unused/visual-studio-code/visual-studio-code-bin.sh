#!/bin/bash

# Visual Studio Code Wrapper (Stable Unified Loader)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# 1. Load user flags
if [[ -f $XDG_CONFIG_HOME/code-flags.conf ]]; then
   CODE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/code-flags.conf | tr '\n' ' ')"
fi

# 2. Launch sequence
# We launch the loader script directly. This ensures Electron starts in GUI mode
# and correctly initializes the environment before handing control to VS Code.
exec /usr/bin/electron39 \
    /opt/visual-studio-code/code-loader.mjs \
    "$@" $CODE_USER_FLAGS
