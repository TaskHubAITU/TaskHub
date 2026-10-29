#!/bin/sh
set -eu
# Run on an independent monitoring host every minute.
: "${TASKHUB_URL:?Set the public HTTPS URL}"
if ! curl --fail --silent --show-error --max-time 10 "$TASKHUB_URL/health" >/dev/null; then
    printf '%s\n' 'TaskHub health check failed' >&2
    if [ -n "${TASKHUB_ALERT_WEBHOOK:-}" ]; then
        curl --fail --silent --show-error --max-time 10 -H 'Content-Type: application/json' \
          --data '{"text":"TaskHub health check failed"}' "$TASKHUB_ALERT_WEBHOOK"
    fi
    exit 1
fi
