#!/bin/sh
# Apply per-interface TX power limits on the BT8 (needs the patched mt76).
#
# OpenWrt's radio "txpower" option runs "iw phy phy0 set txpower", which on the
# BT8 sets all three bands at once (6 GHz mesh included), and every radio
# reload puts every interface back to auto. So leave radio txpower unset and
# let this script re-apply the limits listed in /etc/bt8-txpower.conf.
#
# The MT7996 keeps one power per band, shared by its interfaces, so give every
# interface on a band the same value. Run from cron every minute.

CONF=/etc/bt8-txpower.conf
[ -r "$CONF" ] || exit 0
status=$(ubus call network.wireless status 2>/dev/null) || exit 0

ifname_of() {
	echo "$status" | jsonfilter -e "@.*.interfaces[@.section='$1'].ifname"
}

# Re-apply only when some listed interface is above its limit, which means a
# reload reset it. Then set all of them, so no interface keeps an auto level
# that could raise its band again later.
reset=
while read -r section dbm; do
	case "$section" in ''|\#*) continue ;; esac
	ifname=$(ifname_of "$section")
	[ -n "$ifname" ] || continue
	cur=$(iw dev "$ifname" info 2>/dev/null | awk '/txpower/ { print int($2) }')
	[ -n "$cur" ] && [ "$cur" -gt "$dbm" ] && reset=1
done < "$CONF"
[ -n "$reset" ] || exit 0

while read -r section dbm; do
	case "$section" in ''|\#*) continue ;; esac
	ifname=$(ifname_of "$section")
	[ -n "$ifname" ] || continue
	iw dev "$ifname" set txpower limit "${dbm}00" &&
		logger -t bt8-txpower "$ifname ($section) limited to $dbm dBm"
done < "$CONF"
