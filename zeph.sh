#!/usr/bin/env bash
# ============================================================
#  ZEPH — 1-paste Zephyr Protocol (RandomX) CPU hash worker
#  Zephyr = Monero fork. PoW: RandomX. CPU only.
#
#  USAGE:
#     curl -sL <url-of-this-script> | bash -s -- YOUR_ZEPH_ADDRESS
#  or:
#     bash zeph.sh YOUR_ZEPH_ADDRESS [POOL_HOST:PORT] [RIG_NAME] [THREADS]
#
#  THREADS: jumlah core yang dipake buat mining.
#     - kosong  -> 75% dari total core (default, hemat buat kerja lain)
#     - angka   -> pake sekian thread  (contoh: 4  -> 4 thread)
#     - "max"   -> pake SEMUA core
#     - "half"  -> pake setengah dari total core
#
#  POOL default: zeph.kryptex.network:7030  (Kryptex, PPS+)
#  Choose any live ZEPH pool:
#     - kryptex EU     : zeph-eu.kryptex.network:7030
#     - kryptex US     : zeph-us.kryptex.network:7030
#     - kryptex SG     : zeph-sg.kryptex.network:7030
#     - k1pool EU      : eu.zeph.k1pool.com:1123
#     - k1pool US  : us.zeph.k1pool.com:1123
#     - kryptex    : zeph.kryptex.network:7030
#     - nanopool   : zeph-asia1.nanopool.org:10900
#     - dxpool     : zeph.ss.dxpool.com:4333
# ============================================================
set -euo pipefail

# ---------- wallet (required) ----------
WALLET="${1:-}"
[ -z "$WALLET" ] && { echo "ERR: butuh wallet address ZEPH."; echo "   bash zeph.sh ZEPHxxxxx... [pool:port] [rig]"; exit 1; }

# ---------- pool & rig ----------
POOL="${2:-zeph.kryptex.network:7030}"
RIG="${3:-$(hostname 2>/dev/null || echo rig)}"
ALGO="rx/0"

# ---------- threads ----------
TOTAL_CORES="$(nproc 2>/dev/null || echo 4)"
THREADS_SPEC="${4:-}"
case "$THREADS_SPEC" in
  ""    ) CPU_ARG="--cpu-max-threads-hint=75" ;;
  max   ) CPU_ARG="-t $TOTAL_CORES" ;;
  half  ) CPU_ARG="-t $(( TOTAL_CORES / 2 ))" ;;
  *     )
    case "$THREADS_SPEC" in
      ''|*[!0-9]*) echo "ERR: THREADS harus angka, 'max', atau 'half'." >&2; exit 1 ;;
    esac
    if [ "$THREADS_SPEC" -lt 1 ] || [ "$THREADS_SPEC" -gt "$TOTAL_CORES" ]; then
      echo "ERR: THREADS=$THREADS_SPEC di luar jumlah core (1..$TOTAL_CORES)." >&2; exit 1
    fi
    CPU_ARG="-t $THREADS_SPEC" ;;
esac

# ---------- detect OS / arch ----------
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS:$ARCH" in
  Linux:x86_64)    PKG="xmrig-6.22.3-focal-x64.tar.gz"; ;;
  Linux:aarch64)   PKG="xmrig-6.22.3-focal-aarch64.tar.gz"; ;;
  Darwin:x86_64)   PKG="xmrig-6.22.3-macos-x64.tar.gz"; ;;
  Darwin:arm64)    PKG="xmrig-6.22.3-macos-arm64.tar.gz"; ;;
  *) echo "ERR: OS/arch gak didukung: $OS $ARCH (pakai 64-bit Linux/macOS)"; exit 1; ;;
esac

URL="https://github.com/xmrig/xmrig/releases/download/v6.22.3/$PKG"
DIR="$HOME/zeph-worker"
BIN="$DIR/xmrig"

echo "==> Zephyr (RandomX) hashing | wallet: ${WALLET:0:14}..."
echo "==> Pool: $POOL | rig: $RIG | arch: $ARCH | cores: $TOTAL_CORES | threads: ${THREADS_SPEC:-75%}"

# ---------- download xmrig ----------
mkdir -p "$DIR"
if [ ! -x "$BIN" ]; then
  echo "==> Unduh $URL"
  curl -fsSL -o "$DIR/$PKG" "$URL" || { echo "ERR: gagal unduh."; exit 1; }
  tar -xzf "$DIR/$PKG" -C "$DIR" --strip-components=1 2>/dev/null || tar -xzf "$DIR/$PKG" -C "$DIR" 2>/dev/null
  chmod +x "$BIN"
  rm -f "$DIR/$PKG"
  echo "==> xmrig siap"
fi

# ---------- hugepages (Linux, best-effort) ----------
if [ "$OS" = "Linux" ] && [ "$(id -u)" = "0" ]; then
  THREADS="$(nproc)"
  SYS_PAGES="$(cat /proc/sys/vm/nr_hugepages)"
  NEED=$((THREADS * 256 / 2048))
  if [ "$SYS_PAGES" -lt "$NEED" ]; then
    echo "==> Set hugepages -> $NEED (256MB per thread, 2MB pages)"
    echo "$NEED" > /proc/sys/vm/nr_hugepages 2>/dev/null || true
  fi
fi

# ---------- run ----------
echo "==> Running... Ctrl+C to stop. Ctrl+C untuk berhenti. (donate-level 1 = 99% buat lo)"
# shellcheck disable=SC2086
exec "$BIN" -a "$ALGO" -o "$POOL" -u "$WALLET.$RIG" -p x --donate-level 1 $CPU_ARG