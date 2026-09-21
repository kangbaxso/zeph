#!/usr/bin/env bash
# ============================================================
#  PRL — 1-paste Pearl (pearlhash) GPU miner  [krig-miner]
#  Kryptex pool · devfee 0% · AMD (ROCm) & NVIDIA (CUDA)
#
#  USAGE:
#     bash <(curl -fsSL <url>/krig.sh) WALLET_ADDRESS [RIG_NAME] [COIN] [POOL]
#  or:
#     bash krig.sh WALLET_ADDRESS [RIG_NAME] [COIN] [POOL]
#
#  ARGUMEN:
#     WALLET  (wajib)  wallet PRL / QTC
#     RIG     (opsional) nama worker di dashboard pool (default: hostname)
#     COIN    (opsional) pearl | quantus   (default: pearl)
#     POOL    (opsional) host:port          (default lihat tabel di bawah)
#
#  POOL default per coin (stratum+ssl, Kryptex PPS+):
#     pearl   prl.kryptex.network:8048    region lain: prl-eu / prl-us / prl-sg / prl-ru / prl-hk
#     quantus qtc.kryptex.network:7048    region: qtc-eu / qtc-us / qtc-sg / qtc-ru
#
#  GPU L4 (NVIDIA, sm_89): coin PRL ~90-140 MH/s (estimasi, L4 = L40S kecil)
# ============================================================
set -euo pipefail

# ---------- wallet (wajib) ----------
WALLET="${1:-}"
[ -z "$WALLET" ] && { echo "ERR: butuh wallet address."; echo "   bash krig.sh WALLET_ADDRESS [rig] [coin] [pool]"; exit 1; }

RIG="${2:-$(hostname 2>/dev/null || echo rig)}"
COIN="${3:-pearl}"
POOL="${4:-}"

# ---------- coin + pool ----------
case "$COIN" in
  pearl|prl|pearlhash)
     COIN="pearl"; [ -z "$POOL" ] && POOL="prl.kryptex.network:8048" ;;
  quantus|qtc)
     COIN="quantus"; [ -z "$POOL" ] && POOL="qtc.kryptex.network:7048" ;;
  *) echo "ERR: coin gak dikenal: $COIN (pilih: pearl | quantus)"; exit 1 ;;
esac

# ---------- OS / arch ----------
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS:$ARCH" in
  Linux:x86_64)  PKG="krig-miner-1.5.2-linux-x64.tar.gz" ;;
  Darwin:x86_64) echo "ERR: macOS gak didukung krig (Linux/Windows aja)."; exit 1 ;;
  Darwin:arm64)  echo "ERR: macOS gak didukung krig (Linux/Windows aja)."; exit 1 ;;
  Linux:aarch64) echo "ERR: arm64 gak didukung krig (x86_64 aja)."; exit 1 ;;
  *) echo "ERR: OS/arch gak didukung: $OS $ARCH"; exit 1 ;;
esac

VER="1.5.2"
URL="https://github.com/kryptex/krig-miner/releases/download/v${VER}/${PKG}"
DIR="$HOME/krig-worker"
BIN="$DIR/krig-miner"

echo "==> Pearl/Quantus GPU mining | coin: $COIN | wallet: ${WALLET:0:12}..."
echo "==> Pool: stratum+ssl://$POOL | rig: $RIG | devfee 0%"

# ---------- download krig ----------
mkdir -p "$DIR"
if [ ! -x "$BIN" ]; then
  echo "==> Unduh $URL"
  curl -fsSL -o "$DIR/$PKG" "$URL" || { echo "ERR: gagal unduh krig-miner."; exit 1; }
  tar -xzf "$DIR/$PKG" -C "$DIR" 2>/dev/null
  chmod +x "$BIN"
  rm -f "$DIR/$PKG"
  echo "==> krig-miner siap"
fi

# ---------- cek GPU dulu, biar gagal cepat ----------
"$BIN" --version >/dev/null 2>&1 || { echo "ERR: binary gak jalan."; exit 1; }
DEVS="$("$BIN" --list-devices 2>&1)"
if printf '%s' "$DEVS" | grep -qi 'no mineable GPU devices\|runtime not found\|no CUDA\|no ROCm'; then
  echo "ERR: gak ada GPU NVIDIA/AMD kedetect."
  echo "     Untuk NVIDIA: pastikan driver + CUDA toolkit terinstall (nvidia-smi)."
  echo "     Untuk AMD:    pastikan ROCm terinstall."
  exit 1
fi
echo "==> GPU terdeteksi:"
printf '%s\n' "$DEVS" | head -20

# ---------- run ----------
echo "==> Running... Ctrl+C untuk berhenti."
exec "$BIN" --coin "$COIN" \
  --url "stratum+ssl://$POOL" \
  --user "$WALLET/$RIG" \
  --no-tui
