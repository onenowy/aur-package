#!/bin/bash

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# Allow users to override command-line options
if [[ -f $XDG_CONFIG_HOME/code-flags.conf ]]; then
   CODE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/code-flags.conf | tr '\n' ' ')"
fi

# Launch
exec /usr/bin/electron39 /opt/visual-studio-code/resources/app "$@" $CODE_USER_FLAGS
