# Extra fixes review (2026-10-02)

Scope: everything in openwrt/mt76 between the driver in OpenWrt 25.12.5
(`39c960c3`, 2026-03-19) and current master (`be5ce791`, 2026-09-01), open
mt76 pull requests, the linux-wireless / linux-mediatek lists, OpenWrt issues,
and batman-adv upstream versus the batman-adv package in OpenWrt 25.12.
The focus was roaming, throughput, batman-adv mesh, and long unattended uptime.

Why not just use the newest mt76? It needs a newer mac80211 than 25.12 ships
(it does not compile against it), which is why the snapshot was the only way to
try it. Backporting the individual fixes keeps the 25.12.5 kernel and wireless
stack you already run.

## Included in the `txpower-stability` build (48 patches in `extras/`)

All are upstream mt76 commits (merged by the mt76 maintainer) unless marked PR.
Each patch file carries a `cherry picked from commit ...` line.

### Roaming and client connect/reconnect
- `use ALTX queue for packets to disassociated stations`: frames to a client
  that is leaving (deauth/disassoc) could hang in the normal queues.
- `fix stranded frames in mt76_txq_schedule_pending`: EAPOL and management
  frames could be stranded, causing association and 4-way handshake timeouts.
- `fix EAPOL source BSS for non-MLD stations`: with several SSIDs on one radio,
  EAPOL could leave from the wrong BSS so the handshake timed out.
- PR #1125 `clean up station WCID and TX queues before sta_remove`: stops TX to
  a station slot the firmware has already released (clients leaving/roaming).

### Throughput
- `allow TX aggregation on the VO queue`: voice-priority traffic was never
  aggregated, limiting throughput for anything mapped to VO.
- `disable UNI_BSS_INFO_PROTECT_INFO for mt7996`: current MT7996 firmware causes
  TX failures with it enabled.
- `fix TX DMA mapping leak for AddBA req frames`, `fix non-AQL packet
  accounting`, RXDMAD_C race / uninitialised descriptor fixes, WED txfree fix.
- Capability / rate-reporting corrections (HE DCM max-RU, EHT-MCS 15 in MRU,
  VHT Rx STBC, STBC NSS, ER-SU RU, 4th-chain ACK RSSI).

### batman-adv
- `don't report a zero TX bitrate`: batman-adv B.A.T.M.A.N. V estimates link
  throughput from the driver's TX bitrate. mt7996 reported a valid-but-zero
  rate for new peers, which batman-adv turns into a link metric of 0.

### Uptime / robustness
- Firmware-recovery (SER) fixes: stuck TX queues after recovery, wake MCU
  waiters correctly, free/clear stale state on full reset, hold the mutex while
  stopping TX during recovery.
- Crash fixes: NULL dereferences (init_tx_queues, txwi_80211, bfer_eht,
  bss_he_tlv), out-of-bounds (link array in tx, mmio copy helpers, RX band_idx,
  chip-config TLV walk, EEPROM bounds), token leak, tx_retries underflow,
  failed-WED-attach cleanup, cancel reset work on unregister, CSA-abort TLV size.
- PR #1073 (mt7996 part) WCID bounds check in TX-free/TX-status: fixes reported
  kernel panics.
- PR #1074 (mt7996 part) DMA length cap for short TX frames.

## Looked at and left out
- PR #1071 FT-SAE fix (802.11r with WPA3): unreviewed, and it also captures
  beacon-protection keys, so it could break beacon protection. If you use WPA3
  with 802.11r, fast roaming falls back to a full SAE login on mt7996 (still
  roams, just slower). WPA2 FT (FT-PSK) is not affected.
- PR #1132 mesh BSSID (802.11s addr3): only needed when meshing with non-MediaTek
  radios; it changes how the hardware treats mesh frames, so not worth the risk
  for a BT8-to-BT8 mesh.
- OpenWrt issue #25417 mesh RX decap offload (about 2x mesh backhaul throughput
  on MT7996): a mac80211 change, not yet sent upstream. Worth revisiting.
- Power-save buffering rework and its follow-ups, MLO-only fixes, the MT7928
  rate-table change, per-band MAC address exposure (could change MACs).
- Newer MT7996 firmware (20260311 in mt76 master): possible later, separately.

## batman-adv package
OpenWrt 25.12 ships batman-adv 2025.4 with 94 backported fixes (to mid-August).
Upstream fixes not yet backported are translation-table counter/race fixes, a
B.A.T.M.A.N. IV OGM aggregation race and a bonding-only metric fix. They are
edge cases, they depend on a large upstream refactor, and none is a common
cause of failure, so no batman-adv rebuild for now.
