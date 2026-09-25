#!/bin/sh
# Brings an RK1 node back when its network card gets stuck. When that happens
# the node keeps running and the cable still looks connected, but nothing gets
# in or out until someone power cycles it.
#
# We only treat the node as cut off when we can't reach the router or any of
# the other nodes. That way a router reboot, or one other node going down,
# won't set this off. Once we're sure, we switch the network card off and on
# again, which usually unsticks it. If that doesn't work, we save anything
# waiting to be written to disk and reboot the node.
set -u

: "${IFACE:=end0}"
: "${TARGETS:?space-separated IPs to probe}"
: "${HOST_IP:?node IP, excluded from TARGETS}"
: "${CHECK_INTERVAL:=10}"
: "${FAIL_THRESHOLD:=6}"
: "${BOUNCE_WAIT:=60}"
: "${MIN_UPTIME:=1800}"
: "${DRY_RUN:=false}"

log() {
  echo "nic-watchdog: $*"
  echo "nic-watchdog: $*" > /dev/kmsg 2>/dev/null || true
}

reachable() {
  for target in $TARGETS; do
    [ "$target" = "$HOST_IP" ] && continue
    ping -c 1 -W 2 -I "$IFACE" "$target" > /dev/null 2>&1 && return 0
  done
  return 1
}

act() {
  if [ "$DRY_RUN" = "true" ]; then
    log "DRY_RUN: would run: $*"
  else
    "$@"
  fi
}

reboot_node() {
  uptime=$(cut -d. -f1 /proc/uptime)
  if [ "$uptime" -lt "$MIN_UPTIME" ]; then
    log "still isolated but uptime ${uptime}s < ${MIN_UPTIME}s; not rebooting"
    return
  fi
  log "link bounce did not recover $IFACE; syncing and rebooting"
  act sh -c 'echo s > /proc/sysrq-trigger'
  sleep 5
  act sh -c 'echo b > /proc/sysrq-trigger'
}

log "watching $IFACE on $HOST_IP (targets: $TARGETS, dry run: $DRY_RUN)"
failures=0
while true; do
  if reachable; then
    [ "$failures" -gt 0 ] && log "$IFACE reachable again after $failures failed checks"
    failures=0
  else
    failures=$((failures + 1))
    if [ "$failures" -ge "$FAIL_THRESHOLD" ]; then
      log "no target reachable over $IFACE for $failures checks; recent kernel log follows"
      dmesg | tail -n 100
      log "bouncing $IFACE"
      act ip link set "$IFACE" down
      sleep 3
      act ip link set "$IFACE" up
      sleep "$BOUNCE_WAIT"
      if reachable; then
        log "$IFACE recovered after link bounce"
      else
        reboot_node
      fi
      failures=0
    fi
  fi
  sleep "$CHECK_INTERVAL"
done
