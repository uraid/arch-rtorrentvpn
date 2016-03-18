#!/bin/bash

echo "[info] configuring rTorrent listen port..."

# create pia client id (randomly generated)
CLIENT_ID=`head -n 100 /dev/urandom | md5sum | tr -d " -"`

# while loop to check/set incoming port every 50 mins (required for pia)
while true
do

	if [[ $VPN_PROV == "pia" ]]; then
		# get username and password from credentials file
		USERNAME=$(sed -n '1p' /config/openvpn/credentials.conf)
		PASSWORD=$(sed -n '2p' /config/openvpn/credentials.conf)

		# lookup the currently set rtorrent incoming port
		RTORRENT_INCOMING_PORT=$(< /config/rtorrent/config/rtorrent.rc grep -P -o -m 1 'port_range\s?\=\s?[^\-]+' | grep -P -o -m 1 '[\d]+')

		echo "[info] rTorrent incoming port $RTORRENT_INCOMING_PORT"

		# lookup the dynamic pia incoming port (response in json format)
		PIA_INCOMING_PORT=`curl --connect-timeout 5 --max-time 20 --retry 5 --retry-delay 0 --retry-max-time 120 -s -d "user=$USERNAME&pass=$PASSWORD&client_id=$CLIENT_ID&local_ip=$LOCAL_IP" https://www.privateinternetaccess.com/vpninfo/port_forward_assignment | head -1 | grep -Po "[0-9]*"`

		echo "[info] PIA incoming port $PIA_INCOMING_PORT"

		if [[ $PIA_INCOMING_PORT =~ ^-?[0-9]+$ ]]; then

			if [[ $RTORRENT_INCOMING_PORT != "$PIA_INCOMING_PORT" ]]; then
				echo "[info] rTorrent incoming port $RTORRENT_INCOMING_PORT and PIA incoming port $PIA_INCOMING_PORT different, configuring rTorrent..."

				# set incoming port for rtorrent
				sed -i -e "s/.*port_range.*\=.*/port_range = ${PIA_INCOMING_PORT}-${PIA_INCOMING_PORT}/g" /config/rtorrent/config/rtorrent.rc

				echo "[info] Restarting rTorrent to force the changed incoming port to take effect..."

				# kill rtorrent named process, will be restarted by supervisor
				/usr/bin/killall rtorrent

				# create file to indicate edit has been done so rtorrent can start (on startup only)
				touch /home/nobody/port_set

			fi

		else
			echo "[warn] PIA incoming port is not an integer, downloads will be slow, check if remote gateway supports port forwarding"
		fi
	fi

	sleep 50m

done
