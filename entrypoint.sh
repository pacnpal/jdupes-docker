#!/bin/sh
# entrypoint.sh — jdupes wrapper with timestamped logging and duration tracking

# ── Environment variables ─────────────────────────────────────────────────────
# JDUPES_LOG_FILE  path to write a timestamped log of all output
# JDUPES_VERBOSE   set to "1" to pass -v (verbose) to jdupes

JDUPES_LOG_FILE="${JDUPES_LOG_FILE:-}"
JDUPES_VERBOSE="${JDUPES_VERBOSE:-}"
_LOG_FILE_OK=1   # set to 0 on first write failure; prevents repeated warnings

# ── Temp resource tracking and cleanup ───────────────────────────────────────
_TMPDIR=""
_cleanup() {
    # shellcheck disable=SC2317  # called via trap EXIT
    if [ -n "$_TMPDIR" ]; then
        rm -rf "$_TMPDIR" 2>/dev/null || true
    fi
}
trap _cleanup EXIT

# ── Helper: write a timestamped line to stderr (and log file if set) ──────────
_log() {
    ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '[%s] %s\n' "$ts" "$*" >&2
    if [ -n "$JDUPES_LOG_FILE" ] && [ "$_LOG_FILE_OK" = "1" ]; then
        if ! printf '[%s] %s\n' "$ts" "$*" >> "$JDUPES_LOG_FILE" 2>/dev/null; then
            _LOG_FILE_OK=0
            printf '[%s] warning: could not write to log file: %s\n' "$ts" "$JDUPES_LOG_FILE" >&2
        fi
    fi
}

# ── Optionally enable verbose output ─────────────────────────────────────────
if [ "${JDUPES_VERBOSE}" = "1" ]; then
    set -- -v "$@"
fi

# ── Prepare log file directory BEFORE first _log call ────────────────────────
if [ -n "$JDUPES_LOG_FILE" ]; then
    log_dir=$(dirname "$JDUPES_LOG_FILE")
    if [ "$log_dir" != "." ] && [ ! -d "$log_dir" ]; then
        if ! mkdir -p "$log_dir" 2>/dev/null; then
            printf 'error: cannot create log directory: %s\n' "$log_dir" >&2
            exit 1
        fi
    fi
fi

# ── Log start ─────────────────────────────────────────────────────────────────
_log "jdupes starting — arguments: $(printf "'%s' " "$@")"
START_EPOCH=$(date +%s)

# ── Run jdupes ────────────────────────────────────────────────────────────────
# jdupes is always run in the background so signals can be forwarded to it
# explicitly, restoring correct PID 1 signal handling for the container.
# Traps are installed BEFORE spawning; _fwd guards the window where _JDUPES_PID
# is still empty by re-raising the signal to self (exit 128+signal semantics).
#
# When JDUPES_LOG_FILE is set, named FIFOs keep stdout and stderr on their
# respective streams while also teeing both into the log file.
_JDUPES_PID=""
_fwd() {
    # shellcheck disable=SC2317  # called via trap
    if [ -n "$_JDUPES_PID" ]; then
        kill "-$1" "$_JDUPES_PID" 2>/dev/null
    else
        trap - "$1"
        kill "-$1" "$$"
    fi
}
trap '_fwd TERM' TERM
trap '_fwd INT'  INT
trap '_fwd HUP'  HUP

# Before setting up FIFOs and tee, ensure the log file is actually writable.
# If this fails, disable log-file-based teeing and fall back to direct output.
if [ -n "$JDUPES_LOG_FILE" ] && ! : >> "$JDUPES_LOG_FILE" 2>/dev/null; then
    _LOG_FILE_OK=0
fi

if [ -n "$JDUPES_LOG_FILE" ] && [ "$_LOG_FILE_OK" -eq 1 ] ; then
    _TMPDIR=$(mktemp -d) || { _log "error: mktemp -d failed"; exit 1; }
    _FIFO_OUT="$_TMPDIR/jdupes.stdout"
    _FIFO_ERR="$_TMPDIR/jdupes.stderr"
    mkfifo "$_FIFO_OUT" "$_FIFO_ERR" || { _log "error: mkfifo failed"; exit 1; }

    tee -a "$JDUPES_LOG_FILE" < "$_FIFO_OUT" &
    _TEE_OUT_PID=$!
    tee -a "$JDUPES_LOG_FILE" < "$_FIFO_ERR" >&2 &
    _TEE_ERR_PID=$!

    jdupes "$@" > "$_FIFO_OUT" 2> "$_FIFO_ERR" &
    _JDUPES_PID=$!
    wait "$_JDUPES_PID"
    EXIT_CODE=$?
    wait "$_TEE_OUT_PID" || _log "warning: stdout tee exited with an error"
    wait "$_TEE_ERR_PID" || _log "warning: stderr tee exited with an error"
else
    jdupes "$@" &
    _JDUPES_PID=$!
    wait "$_JDUPES_PID"
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
