#!/bin/sh

# Include golang binaries in PATH
export PATH=/opt/niji-orchestrator:$PATH

LOGDIR=/var/log/niji-orchestrator
[ -d "$LOGDIR" ] && exec $@ >>"$LOGDIR/orchestrator.log" 2>>"$LOGDIR/errors.log" || exec $@
