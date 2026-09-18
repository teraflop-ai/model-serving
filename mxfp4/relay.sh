#!/bin/bash
set -euo pipefail

D=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/k3}
CFG=$D/relay
BIN=$D/opentela
IP=$(ip -o -4 addr show ib0 | awk '{split($4,a,"/"); print a[1]}')
mkdir -p "$CFG"
exec 9>"$CFG/start.lock"
flock 9

if ! tmux has-session -t otela-relay 2>/dev/null; then
  read -r HTTP_PORT TCP_PORT UDP_PORT < <(python3 - <<'PY'
import socket
sockets = [socket.socket(socket.AF_INET, kind) for kind in
           (socket.SOCK_STREAM, socket.SOCK_STREAM, socket.SOCK_DGRAM)]
for sock in sockets:
    sock.bind(("0.0.0.0", 0))
print(*(sock.getsockname()[1] for sock in sockets))
PY
)
  cat > "$CFG/cfg.yaml" <<YAML
mode: node
role: relay
reachability: public
cleanslate: false
port: "$HTTP_PORT"
tcpport: "$TCP_PORT"
udpport: "$UDP_PORT"
security:
  require_signed_binary: false
YAML

  tmux new-session -d -s otela-relay bash -o pipefail -c '
    "$1" start --config-dir "$2" \
      --bootstrap.static /dns4/p2p.opentela.ai/tcp/443/wss/p2p/QmTtnXKHvovCwkBZRR4NcxeHfnt5EJQgN4wo9KV8U8nYP7 \
      --solana.skip_verification 2>&1 | tee "$3"
  ' _ "$BIN" "$CFG" "$D/relay.log" 9>&-
fi

read -r HTTP_PORT TCP_PORT < <(
  awk -F'"' '/^(port|tcpport):/{printf "%s ",$2} END{print ""}' "$CFG/cfg.yaml"
)

for i in {1..30}; do
  tmux has-session -t otela-relay 2>/dev/null || break
  if body=$(curl -fs --max-time 2 "http://127.0.0.1:$HTTP_PORT/v1/self"); then
    ID=$("$BIN" peer-id --config-dir "$CFG")
    if python3 -c 'import json,sys; sys.exit(json.load(sys.stdin).get("id") != sys.argv[1])' "$ID" <<< "$body"; then
      printf '/ip4/%s/tcp/%s/p2p/%s\n' "$IP" "$TCP_PORT" "$ID" > "$D/relay.multiaddr.tmp"
      mv "$D/relay.multiaddr.tmp" "$D/relay.multiaddr"
      cat "$D/relay.multiaddr"
      exit 0
    fi
  fi
  sleep 1
done

tail -n 30 "$D/relay.log"
exit 1