#!/usr/bin/env bash
# monitor.sh — статус systemd-сервиса + число ошибок в syslog за последний час.
# Использование: ./monitor.sh <service> [lines]
# Коды выхода: 0 active, 1 не active, 2 ошибка аргументов, 3 нет сервиса, 4 нет утилит
set -uo pipefail

SERVICE="${1:-}"
LINES="${2:-10}"
SYSLOG="/var/log/syslog"

# --- проверка аргументов ---
if [[ -z "$SERVICE" ]]; then
    echo "Usage: $0 <service> [lines]" >&2
    exit 2
fi
if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
    echo "ERROR: lines must be a number, got '$LINES'" >&2
    exit 2
fi
for cmd in systemctl journalctl grep awk date; do
    command -v "$cmd" >/dev/null || { echo "ERROR: '$cmd' not found" >&2; exit 4; }
done

# --- 1. сервис существует? ---
if [[ "$(systemctl show -p LoadState --value "$SERVICE" 2>/dev/null)" == "not-found" ]]; then
    echo "ERROR: service '$SERVICE' not found" >&2
    exit 3
fi

# --- 2. статус и журнал ---
STATE=$(systemctl is-active "$SERVICE")
echo "Service $SERVICE: $STATE"
RC=0
if [[ "$STATE" != "active" ]]; then
    RC=1
    echo "--- last $LINES journal lines ---"
    journalctl -u "$SERVICE" -n "$LINES" --no-pager \
        || echo "WARN: cannot read journal (try sudo)" >&2
fi

# --- 3. ошибки в syslog за последний час ---
if [[ ! -r "$SYSLOG" ]]; then
    echo "WARN: cannot read $SYSLOG (try sudo)" >&2
    exit "$RC"
fi

# Граница окна в двух форматах syslog:
#   Ubuntu 24.04: 2026-10-14T15:08:20.123+00:00 host ...
#   Ubuntu 20/22: Oct 14 15:08:20 host ...
CUT_ISO=$(date -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')
CUT_OLD=$(date -d '1 hour ago' '+%m%d%H%M%S')

ERRORS=$(grep -iwE 'error|err|fail|failed|critical|fatal' "$SYSLOG" | awk -v ci="$CUT_ISO" -v co="$CUT_OLD" '
    BEGIN {
        split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
        for (i = 1; i <= 12; i++) mon[m[i]] = sprintf("%02d", i)
    }
    $1 ~ /^[0-9][0-9][0-9][0-9]-/ {           # формат ISO
        if (substr($1, 1, 19) >= ci) n++
        next
    }
    ($1 in mon) {                              # классический формат
        t = $3; gsub(":", "", t)
        if (mon[$1] sprintf("%02d", $2) t >= co) n++
    }
    END { print n + 0 }')

echo "Errors in $SYSLOG for the last hour: $ERRORS"
exit "$RC"
