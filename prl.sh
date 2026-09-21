#!/usr/bin/env bash
# ============================================================
#  PRL — 1-paste Pearl (pearlhash) GPU miner  [SRBMiner-MULTI]
#  Pool: AlphaPool · plain TCP (port 5566) · 0% fee · PPLNS
#  AMD (ROCm/OpenCL) & NVIDIA (CUDA) · devfee ~0.65%
#
#  Kenapa script ini? krig-miner (Kryptex) wajib TLS di port 8048.
#  Kalau jaringan lo blok port itu, pakai ini: AlphaPool port 5566, plain TCP.
#
#  USAGE:
#     bash <(curl -fsSL <url>/prl.sh) WALLET_PRL [RIG_NAME] [POOL] [PORT]
#  or:
#     bash prl.sh WALLET_PRL [RIG_NAME] [POOL] [PORT]
#
#  ARGUMEN:
#     WALLET  (wajib)   wallet PRL (format prl1...)
#     RIG     (opsional) nama worker (default: hostname)
#     POOL    (opsional) default us2.alphapool.tech
#     PORT    (opsional) default 5566 (plain TCP)
#
#  Region AlphaPool (port sama, 5566):
#     us1/us2 (US), eu1 (Eropa), ru1 (Russia), sg1 (Singapore)
#     solo: port 5573 (1% fee, keep whole block)
# ============================================================
set -euo pipefail

# ---------- wallet (wajib) ----------
WALLET="${1:-}"
[ -z "$WALLET" ] && { echo "ERR: butuh wallet address PRL."; echo "   bash prl.sh prl1p... [rig] [pool] [port]"; exit 1; }

RIG="${2:-$(hostname 2>/dev/null || echo rig)}"
POOL="${3:-us2.alphapool.tech}"
PORT="${4:-5566}"

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

echo "==> Pearl (pearlhash) GPU mining | wallet: ${WALLET:0:12}..."
echo "==> Pool: $POOL:$PORT | rig: $RIG | pool fee 0% | plain TCP (gak butuh TLS)"

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

# ---------- cek GPU ----------
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "==> GPU NVIDIA:"
  nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null | head -10
elif command -v rocm-smi >/dev/null 2>&1; then
  echo "==> GPU AMD:"
  rocm-smi --showproductname 2>/dev/null | head -10
else
  echo "WARN: gak ketemu nvidia-smi/rocm-smi. Lanjut, tapi mungkin gak ada GPU."
fi

# ---------- cek koneksi pool dulu ----------
if ! timeout 8 bash -c "echo > /dev/tcp/$POOL/$PORT" 2>/dev/null; then
  echo "ERR: gak bisa connect ke $POOL:$PORT."
  echo "     Cek apakah jaringan lo blok port $PORT."
  echo "     Region lain: us1/eu1/ru1/sg1.alphapool.tech:5566"
  exit 1
fi
echo "==> Pool reachable"

# ---------- run ----------
echo "==> Running... Ctrl+C untuk berhenti."
exec "$BIN" \
  --algorithm pearlhash \
  --pool "$POOL:$PORT" \
  --wallet "$WALLET.$RIG" \
  --tls false \
  --disable-cpu
