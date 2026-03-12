#!/bin/sh
# Fake logread for procd-based systems
# Outputs /tmp/logread.log (services can append here)
if [ "$1" = "-e" ] || [ "$1" = "-f" ]; then
    tail -f /tmp/logread.log 2>/dev/null
else
    cat /tmp/logread.log 2>/dev/null
fi
