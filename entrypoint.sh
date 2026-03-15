#!/bin/sh
# entrypoint.sh — jdupes wrapper with logging and progress monitoring

# ── Environment variables ─────────────────────────────────────────────────────
# JDUPES_LOG_FILE  path to write a timestamped log of all output
# JDUPES_VERBOSE   set to "1" to pass -v (verbose) to jdupes

JDUPES_LOG_FILE="${JDUPES_LOG_FILE:-}"
JDUPES_VERBOSE="${JDUPES_VERBOSE:-}"

# ── Helper: write a timestamped line to stderr (and log file if set) ──────────
_log() {
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '[%s] %s\n' "$ts" "$*" >&2
    if [ -n "$JDUPES_LOG_FILE" ]; then
        printf '[%s] %s\n' "$ts" "$*" >> "$JDUPES_LOG_FILE"
    fi
}

# ── Optionally enable verbose output ─────────────────────────────────────────
if [ "${JDUPES_VERBOSE}" = "1" ]; then
    set -- -v "$@"
fi

# ── Log start ─────────────────────────────────────────────────────────────────
_log "jdupes starting — arguments: $*"
START_EPOCH=$(date +%s)

# ── Prepare log file directory ────────────────────────────────────────────────
if [ -n "$JDUPES_LOG_FILE" ]; then
    log_dir=$(dirname "$JDUPES_LOG_FILE")
    if [ "$log_dir" != "." ] && [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi
fi

# ── Run jdupes ────────────────────────────────────────────────────────────────
# When logging to a file, tee output to both stdout and the log file while
# preserving jdupes exit code in a temp file (POSIX-compatible, no pipefail).
if [ -n "$JDUPES_LOG_FILE" ]; then
    TMP_EXIT=$(mktemp)
    (jdupes "$@" 2>&1; echo $? > "$TMP_EXIT") | tee -a "$JDUPES_LOG_FILE"
    EXIT_CODE=$(cat "$TMP_EXIT")
    rm -f "$TMP_EXIT"
else
    jdupes "$@"
    EXIT_CODE=$?
fi

# ── Log completion ────────────────────────────────────────────────────────────
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

if [ "$EXIT_CODE" -eq 0 ]; then
    _log "jdupes finished successfully — duration: ${DURATION}s"
else
    _log "jdupes exited with code ${EXIT_CODE} — duration: ${DURATION}s"
fi

exit "$EXIT_CODE"
