# Per-band TX power on the BT8

Use this after the patched mt76 packages are installed.

Do not set `txpower` on the radios in `/etc/config/wireless`. On the BT8 that
option sets all three bands at once (the 6 GHz mesh included), and every radio
reload resets all interfaces to automatic power. This script limits only the
interfaces you list and puts the limits back after a reload, within a minute.

The MT7996 keeps one power level per band, shared by every interface on that
band, so list every interface on a band with the same value. The default file
limits the 5 GHz client SSIDs only. 2.4 GHz carries the mesh fallback and
6 GHz is the mesh, so they stay at automatic.

## Install (each node)

```sh
scp -O bt8-txpower.sh bt8-txpower.conf root@192.168.2.25:/tmp/
ssh root@192.168.2.25
cp /tmp/bt8-txpower.sh /usr/sbin/ && chmod +x /usr/sbin/bt8-txpower.sh
cp /tmp/bt8-txpower.conf /etc/
echo '* * * * * /usr/sbin/bt8-txpower.sh' >> /etc/crontabs/root
/etc/init.d/cron enable && /etc/init.d/cron restart
printf '/usr/sbin/bt8-txpower.sh\n/etc/bt8-txpower.conf\n' >> /etc/sysupgrade.conf
/usr/sbin/bt8-txpower.sh; logread -e bt8-txpower
```

## Tuning

Edit `/etc/bt8-txpower.conf`, run `wifi reload`, and wait a minute. Start at
14 dBm on 5 GHz on both nodes, walk the corridor with WiFiMan, and move the
value up or down 2 dB at a time until the phone hands over between the kitchen
and the back bedroom. Then relax the usteer kick (`min_snr`).

To undo: delete the cron line and run `wifi reload`.
