#!/bin/sh

# Include golang binaries in PATH
export PATH=/opt/seed-golang:$PATH

LOGDIR=/var/log/seed-golang
[ -d "$LOGDIR" ] && exec $@ >>"$LOGDIR/seed.log" 2>>"$LOGDIR/errors.log" || exec $@
