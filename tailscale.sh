#!/bin/bash

set -euo pipefail

: "${TS_AUTH:=unset}"

start_tailscaled() {
    if [[ ! -f /usr/sbin/tailscaled ]]; then
        echo "Tailscale not installed"
    else
        echo "Ensuring tailscale is up to date"
        sudo /usr/bin/tailscale update
        echo "Starting tailscaled"
        tmux new-session -d -s tailscaled 'sudo /usr/sbin/tailscaled --state=mem:'
    fi
}

connect_tailscale() {
    TS_USERNAME=$(echo "${GITPOD_GIT_USER_NAME}" | tr " " '-')
    TS_HOSTNAME="${TS_USERNAME}-${GITPOD_WORKSPACE_ID}"
    if [[ "$TS_AUTH" != "unset" ]]; then
        echo "TS_AUTH variable present, auto connecting"
        sudo -E tailscale up --accept-dns --accept-routes --hostname="$TS_HOSTNAME" --auth-key="$TS_AUTH"
    else
        echo "TS_AUTH environment variable not set, will prompt for interactive auth"
        sudo -E tailscale up --accept-dns --accept-routes --hostname="$TS_HOSTNAME"
    fi
}

check_tailscale() {
    if /usr/bin/tailscale status >/dev/null 2>&1 ; then
        echo "Tailscale up, nothing to do"
    else
        echo "Tailscale down, connecting"
        connect_tailscale
    fi
}

if [[ "$TS_AUTH" != "unset" ]]; then
    if /usr/bin/tmux has-session -t tailscaled 2>/dev/null; then
        echo "Tailscaled Running"
        check_tailscale
    else
        echo "Tailscaled Stopped, Starting"
        start_tailscaled
        check_tailscale
    fi
    echo "Tailscale connected: $(tailscale status --peers=false)"
else
    echo "You don't have a TS_AUTH key so this example won't run right now"
fi

