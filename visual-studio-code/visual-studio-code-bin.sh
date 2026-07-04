#!/bin/bash

# Visual Studio Code Wrapper (Stable Unified Loader)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# 1. Load user flags
if [[ -f $XDG_CONFIG_HOME/code-flags.conf ]]; then
   CODE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/code-flags.conf | tr '\n' ' ')"
fi

# 2. Launch sequence
exec /opt/visual-studio-code/bin/code "$@" $CODE_USER_FLAGS
