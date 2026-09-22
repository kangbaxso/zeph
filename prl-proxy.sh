#!/usr/bin/env bash
# ============================================================
#  PRL — 1-paste Pearl (pearlhash) GPU miner lewat HTTP proxy
#
#  Untuk jaringan yg blok port stratum (5566/8048/semua port non-standar).
#  Jembatin HTTP proxy (Bright Data, brd.superproxy.io) jadi SOCKS5 lokal,
#  karena SRBMiner-MULTI --proxy cuma mau SOCKS5.
#
#  SEKALI SETELP (di mesin lo, jangan paste password ke chat):
#     printf 'brd-customer-hl_f11aca3a-zone-isp_proxy1:PASSWORD_LO' > ~/.brd_auth
#     chmod 600 ~/.brd_auth
#
#  USAGE:
#     bash <(curl -fsSL <url>/prl-proxy.sh) WALLET_PRL [RIG_NAME] [POOL] [PORT]
#
#  ARGUMEN:
#     WALLET  (wajib)   wallet PRL (prl1...)
#     RIG     (opsional) nama worker (default: hostname)
#     POOL    (opsional) default us2.alphapool.tech
#     PORT    (opsional) default 5566 (plain TCP)
#
#  Region AlphaPool (semua port 5566):
#     us1/us2 (US) · eu1 (Eropa) · ru1 (Russia) · sg1 (Singapore)
# ============================================================
set -euo pipefail

# ---------- wallet (wajib) ----------
WALLET="${1:-}"
[ -z "$WALLET" ] && { echo "ERR: butuh wallet address PRL."; echo "   bash prl-proxy.sh prl1p... [rig] [pool] [port]"; exit 1; }

RIG="${2:-$(hostname 2>/dev/null || echo rig)}"
POOL="${3:-us2.alphapool.tech}"
PORT="${4:-5566}"

AUTH_FILE="$HOME/.brd_auth"
PROXY_HOST="brd.superproxy.io"
PROXY_PORT="44445"
SOCKS_PORT="11080"

# ---------- cek auth file ----------
if [ ! -s "$AUTH_FILE" ]; then
  echo "ERR: file auth proxy belum ada: $AUTH_FILE"
  echo
  echo "Bikin dulu (ganti PASSWORD_LO, jangan paste ke chat):"
  echo "  printf 'brd-customer-hl_f11aca3a-zone-isp_proxy1:PASSWORD_LO' > $AUTH_FILE"
  echo "  chmod 600 $AUTH_FILE"
  exit 1
fi
CRED="$(cat "$AUTH_FILE")"

# ---------- OS / arch ----------
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS:$ARCH" in
  Linux:x86_64)  PKG="SRBMiner-Multi-3-6-9-Linux.tar.gz" ;;
  Linux:aarch64) echo "ERR: arm64 gak didukung SRBMiner (x86_64 aja)."; exit 1 ;;
  Darwin:*)      echo "ERR: macOS gak didukung SRBMiner."; exit 1 ;;
  *) echo "ERR: OS/arch gak didukung: $OS $ARCH"; exit 1 ;;
esac

VER="3.6.9"
URL="https://github.com/doktor83/SRBMiner-Multi/releases/download/${VER}/${PKG}"
DIR="$HOME/prl-worker"
BIN="$DIR/SRBMiner-Multi-3-6-9/SRBMiner-MULTI"

echo "==> Pearl (pearlhash) via HTTP-proxy | wallet: ${WALLET:0:12}..."
echo "==> Pool: $POOL:$PORT | rig: $RIG | proxy: $PROXY_HOST:$PROXY_PORT -> socks5 127.0.0.1:$SOCKS_PORT"

# ---------- download SRBMiner ----------
mkdir -p "$DIR"
if [ ! -x "$BIN" ]; then
  echo "==> Unduh $URL"
  curl -fsSL -o "$DIR/$PKG" "$URL" || { echo "ERR: gagal unduh SRBMiner-Multi."; exit 1; }
  tar -xzf "$DIR/$PKG" -C "$DIR" 2>/dev/null
  chmod +x "$BIN"
  rm -f "$DIR/$PKG"
  echo "==> SRBMiner-Multi siap"
fi

# ---------- tulis bridge ----------
BRIDGE="$HOME/prl-worker/socks5_bridge.py"
cat > "$BRIDGE" <<'BRIDGE_EOF'
#!/usr/bin/env python3
"""HTTP-CONNECT to SOCKS5 bridge, biar miner (--proxy socks5) bisa lewat HTTP proxy."""
import socket, struct, threading, base64, sys

LISTEN_PORT = int(sys.argv[1]); HTTP_PROXY = sys.argv[2]
HTTP_PORT   = int(sys.argv[3]); CRED       = sys.argv[4]

def pipe(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d: break
            b.sendall(d)
    except Exception: pass
    finally:
        try: a.shutdown(socket.SHUT_RD)
        except Exception: pass

def handle(client):
    try:
        ver, nmet = client.recv(2)
        if ver != 5: client.close(); return
        client.recv(nmet); client.sendall(b"\x05\x00")
        ver, cmd, _, atyp = client.recv(4)
        if cmd != 1:
            client.sendall(b"\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00"); client.close(); return
        if atyp == 1:
            host = socket.inet_ntoa(client.recv(4))
        elif atyp == 3:
            ln = client.recv(1)[0]; host = client.recv(ln).decode()
        else:
            client.recv(16); host = None
        port = struct.unpack(">H", client.recv(2))[0]
        if not host:
            client.sendall(b"\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00"); client.close(); return
        up = socket.create_connection((HTTP_PROXY, HTTP_PORT), timeout=20)
        req = f"CONNECT {host}:{port} HTTP/1.1\r\nHost: {host}:{port}\r\nProxy-Authorization: Basic {base64.b64encode(CRED.encode()).decode()}\r\n\r\n"
        up.sendall(req.encode())
        resp = b""; up.settimeout(20)
        while b"\r\n\r\n" not in resp:
            ch = up.recv(4096)
            if not ch: break
            resp += ch
        if b" 200 " not in resp.split(b"\r\n")[0]:
            sys.stderr.write("proxy tolak CONNECT: " + resp.split(b"\r\n")[0].decode(errors="replace") + "\n")
            client.sendall(b"\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00"); up.close(); client.close(); return
        client.sendall(b"\x05\x00\x00\x01" + socket.inet_aton("0.0.0.0") + struct.pack(">H", 0))
        rest = resp.split(b"\r\n\r\n", 1)[1]
        if rest: client.sendall(rest)
        t1 = threading.Thread(target=pipe, args=(client, up), daemon=True)
        t2 = threading.Thread(target=pipe, args=(up, client), daemon=True)
        t1.start(); t2.start(); t1.join()
    except Exception: pass
    finally:
        try: client.close()
        except Exception: pass

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", LISTEN_PORT)); s.listen(128)
print("bridge ready", flush=True)
while True:
    c, _ = s.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
BRIDGE_EOF

# ---------- start bridge ----------
if ! timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$SOCKS_PORT" 2>/dev/null; then
  echo "==> Start SOCKS5 bridge"
  nohup python3 "$BRIDGE" "$SOCKS_PORT" "$PROXY_HOST" "$PROXY_PORT" "$CRED" \
    > "$HOME/prl-worker/bridge.log" 2>&1 &
  for i in $(seq 1 20); do
    timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$SOCKS_PORT" 2>/dev/null && break
    sleep 0.3
  done
fi
if ! timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$SOCKS_PORT" 2>/dev/null; then
  echo "ERR: bridge gak jalan. Lihat $HOME/prl-worker/bridge.log"; exit 1
fi
echo "==> Bridge jalan di 127.0.0.1:$SOCKS_PORT"

# ---------- test proxy lewat bridge ----------
if command -v curl >/dev/null 2>&1; then
  echo "==> Test proxy..."
  if timeout 15 curl -sf --socks5 "127.0.0.1:$SOCKS_PORT" "https://geo.brdtest.com/welcome.txt" >/dev/null 2>&1; then
    echo "==> Proxy OK"
  else
    echo "WARN: test proxy gagal (boleh jadi cuma http yg diblokir). Lanjut."
  fi
fi

# ---------- cek GPU ----------
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "==> GPU NVIDIA:"
  nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null | head -10
else
  echo "WARN: nvidia-smi gak ada. Mungkin gak ada GPU NVIDIA."
fi

# ---------- run ----------
echo "==> Running... Ctrl+C untuk berhenti."
exec "$BIN" \
  --algorithm pearlhash \
  --pool "$POOL:$PORT" \
  --wallet "$WALLET.$RIG" \
  --tls false \
  --disable-cpu \
  --proxy "127.0.0.1:$SOCKS_PORT"
