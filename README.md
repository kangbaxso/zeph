# ZEPH Worker — 1-paste

Zephyr Protocol (RandomX / Monero fork) CPU hash worker. Auto-download xmrig 6.22.3, hugepages, jalan.

## Run (1x paste)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kangbaxso/zeph/main/zeph.sh) ZEPHYR_ADDRESS_LO
```

Ganti `ZEPHYR_ADDRESS_LO` dengan address ZEPH lo. Atau clone + jalankan:

```bash
git clone https://github.com/kangbaxso/zeph.git && cd zeph
bash zeph.sh ZEPHYR_ADDRESS_LO
```

## Opsi

```bash
bash zeph.sh <WALLET> [POOL] [RIG_NAME]
```

- Default pool: `zeph.kryptex.network:7030` (Kryptex, PPS+)
- Pool lain yang bisa dipilih:
  - kryptex global : `zeph.kryptex.network:7030`
- kryptex EU     : `zeph-eu.kryptex.network:7030`
- kryptex US     : `zeph-us.kryptex.network:7030`
- kryptex SG     : `zeph-sg.kryptex.network:7030`
- k1pool EU      : `eu.zeph.k1pool.com:1123`
  - k1pool US  : `us.zeph.k1pool.com:1123`
  - kryptex    : `zeph.kryptex.network:7030`
  - nanopool   : `zeph-asia1.nanopool.org:10900`
  - dxpool     : `zeph.ss.dxpool.com:4333`

## Yang dilakukan script

1. Detect OS/arch (Linux/macOS, x64/arm64)
2. Download xmrig 6.22.3 official build dari github.com/xmrig/xmrig releases
3. Set hugepages (Linux + root, best-effort)
4. Jalankan `rx/0`, `--donate-level 1` (99% buat lo), 75% CPU

## Catatan

- RandomX butuh ~256MB RAM per thread. CPU lo 4 thread -> 1GB RAM minimum.
- `FAILED TO APPLY MSR MOD` di VM (Azure dll) itu normal, hashrate dikit turun, bukan error.
- Saya tidak punya mining pool / tidak ada fee tambahan selain donasi xmrig 1%.
