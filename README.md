# ASUS ZenWiFi BT8: working transmit power control (mt76 / MT7996)

This repo builds a patched MediaTek Wi-Fi driver (mt76) for OpenWrt 25.12.5 on
the ASUS ZenWiFi BT8 so that `txpower` settings actually change the radiated
power. You install three driver packages on each node; nothing else changes.

## What was wrong

On MT7996 the driver computes the requested power, reports it back
(`iw dev` shows the new value), and uploads a per-rate power table to the
Wi-Fi firmware. But the firmware ignores that table unless the driver first
switches on its "SKU power limit" control, and upstream mt76 never sends that
command. So the setting is accepted, displayed, and silently not applied.
This is the bug reported in [openwrt/mt76#1140](https://github.com/openwrt/mt76/issues/1140).
It is still present in the newest mt76 (2026-09-01, `be5ce791`).

## The fix

Two patches by Yanghan Ye, posted to linux-wireless / linux-mediatek on
2026-06-24 ("wifi: mt76: mt7996: fix runtime txpower limits", not yet merged):

* `patches/0900-...refresh-power-limits-on-txpower-cha.patch`: after a txpower
  change, also re-sends the channel info so firmware recomputes power, and
  logs MCU errors instead of ignoring them.
* `patches/0901-...enable-firmware-txpower-limit-contr.patch`: turns on the
  firmware SKU (and, if the device tree has path tables, backoff) power-limit
  controls when each radio starts, and uploads the tables in the layout the
  MediaTek SDK uses.

Source: <https://lists.infradead.org/pipermail/linux-mediatek/2026-June/108610.html>.
They apply cleanly to both the mt76 in 25.12.5 (`39c960c3`) and current mt76 master.

## Building

The GitHub Actions workflow (`.github/workflows/build.yml`) downloads the
official OpenWrt 25.12.5 SDK for `mediatek/filogic`, drops the patches into the
mt76 package, and builds:

* `kmod-mt76-core`
* `kmod-mt76-connac`
* `kmod-mt7996e`

They are built against the exact release kernel, so they install on a stock
25.12.5 image. The release number is bumped to `-r100` so they replace the
stock `-r2` packages. Download them from the run's **Artifacts** section.

## Installing (per node)

Do one node first, check it, then do the other.

```sh
# on your PC: copy the three .apk files to the router
scp -O kmod-mt76-core-*.apk kmod-mt76-connac-*.apk kmod-mt7996e-*.apk root@192.168.1.1:/tmp/

# on the router
apk info -v | grep -E '^kmod-mt7(6|996)'   # note the current versions for rollback
apk add --allow-untrusted /tmp/kmod-mt76-core-*.apk /tmp/kmod-mt76-connac-*.apk /tmp/kmod-mt7996e-*.apk
reboot
```

After the reboot, `apk info -v | grep kmod-mt7996e` should show `-r100`.

## Testing

From a phone or laptop near the node, watch the node's signal (for example
with a Wi-Fi analyser app), then on the router:

```sh
iw dev                                   # find the AP interface names, e.g. phy0-ap0
iw dev phy0-ap0 set txpower fixed 2000   # 20 dBm
iw dev phy0-ap0 set txpower fixed 1000   # 10 dBm: the client should now see ~10 dB less
iw dev phy0-ap0 set txpower auto
dmesg | grep -i txpower                  # should be empty (no firmware errors)
```

For a permanent setting use LuCI (Network > Wireless > radio > Transmit Power)
or `uci set wireless.radioN.txpower=<dBm>; uci commit wireless; wifi`.

## Rolling back

Reinstall the stock packages from the official feed, using the versions you
noted above (25.12.5 shipped `6.12.94.2026.03.19~39c960c3-r2`):

```sh
apk update
apk add 'kmod-mt76-core=6.12.94.2026.03.19~39c960c3-r2' \
        'kmod-mt76-connac=6.12.94.2026.03.19~39c960c3-r2' \
        'kmod-mt7996e=6.12.94.2026.03.19~39c960c3-r2'
reboot
```

A sysupgrade to a new image also replaces these packages with the stock ones,
so reinstall after upgrading until the fix is merged upstream.
