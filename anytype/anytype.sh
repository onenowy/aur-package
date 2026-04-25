#!/bin/bash

ANYTYPE_USER_FLAGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/anytype/user-flags.conf"

# Allow users to override command-line options
if [[ -f "${ANYTYPE_USER_FLAGS_FILE}" ]]; then
   ANYTYPE_USER_FLAGS=$(grep -v '^#' "$ANYTYPE_USER_FLAGS_FILE")
fi

# Launch
exec /opt/anytype/anytype $ANYTYPE_USER_FLAGS "$@"
