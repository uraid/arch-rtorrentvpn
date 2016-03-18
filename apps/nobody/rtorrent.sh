#!/bin/bash

# if rtorrent config file doesnt exist then copy default to host config volume
if [ ! -f "/config/rtorrent/config/rtorrent.rc" ]; then

	echo "[info] rTorrent config file doesnt exist, copying default to /config/rtorrent/config/..."

	# copy default rtorrent config file to /config/rtorrent/config/
	mkdir -p /config/rtorrent/config && cp /home/nobody/rtorrent/config/* /config/rtorrent/config/

else

	echo "[info] rTorrent config file already exists, skipping copy"

fi

# create soft link to rtorrent config file
ln -fs /config/rtorrent/config/rtorrent.rc ~/.rtorrent.rc


# if vpn set to "no" then don't run openvpn
if [[ $VPN_ENABLED == "no" ]]; then

	echo "[info] VPN not enabled, skipping VPN tunnel local ip checks"

else

	echo "[info] VPN is enabled, checking VPN tunnel local ip is valid"

	# run script to check ip is valid for tun0
	source /home/nobody/checkip.sh

	# remove previous run flag files (used to indicate port and ip set)
	rm -f /home/nobody/ip_set
	rm -f /home/nobody/port_set

	# run scripts to configure rtorrent ip and port
	source /home/nobody/setip.sh & source /home/nobody/setport.sh &

fi

echo "[info] Removing any rtorrent session lock files left over from the previous run..."
rm -f /config/session/*.lock

# wait until port and ip have been set (via setip.sh and setport.sh) then proceed to run rtorrent
while [[ ! -f "/home/nobody/ip_set" && ! -f "/home/nobody/port_set" ]]; do
	sleep 0.1
done

echo "[info] All checks complete, starting rTorrent..."

# run rTorrent
/usr/bin/rtorrent