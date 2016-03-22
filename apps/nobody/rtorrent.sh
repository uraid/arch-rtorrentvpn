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
	echo "[info] All checks complete, starting rTorrent..."
	
	# run rTorrent
	/usr/bin/tmux new-session -d -s rtorrent -c $(/usr/bin/rtorrent)

else

	echo "[info] VPN is enabled, checking VPN tunnel local ip is valid"

	# run script to check ip is valid for tun0
	source /home/nobody/checkip.sh
	
	first_run="true"
	reload="true"
	rtorrent_port=""
	rtorrent_ip=""
	
	# while loop to check bind ip every 5 mins
	while true; do

		echo "[info] Removing any rtorrent session lock files left over from the previous run..."
		rm -f /config/session/*.lock

		if [[ $VPN_PROV == "pia" ]]; then
		
			# run scripts to identify vpn port
			source /home/nobody/setport.sh

			if [[ $vpn_port =~ ^-?[0-9]+$ ]]; then

				if [[ $rtorrent_port != "$vpn_port" ]]; then
				
					echo "[info] rTorrent incoming port $rtorrent_port and PIA incoming port $vpn_port different, configuring rTorrent..."
					reload="true"
					rtorrent_port="${vpn_port}"
				fi

			else

				echo "[warn] PIA incoming port is not an integer, downloads will be slow, check if remote gateway supports port forwarding"

			fi

		fi

		# run scripts to identity vpn ip
		source /home/nobody/setip.sh

		# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
		if [[ $rtorrent_ip != "$vpn_ip" ]]; then
		
			echo "[info] rTorrent listening interface IP $rtorrent_ip and OpenVPN local IP $vpn_ip different, configuring rTorrent..."
			reload="true"
			rtorrent_ip="${vpn_ip}"

		fi

		if [[ $first_run == "true" || $reload == "true" ]]; then
			
			if [[ $first_run == "false" ]]; then

				echo "[info] Restarting rTorrent to force the changed bind interface to take effect..."
				
				# kill rtorrent named process, will be restarted by supervisor
				/usr/bin/pkill -x "rtorrent main"

				echo "[info] Removing any rtorrent session lock files left over from the previous run..."
				rm -f /config/session/*.lock

			fi
			
			echo "[info] All checks complete, starting rTorrent..."
			
			if [[ $VPN_PROV == "pia" ]]; then

				# run tmux attached to rTorrent, specifying listening interface and port (port is pia only)
				/usr/bin/tmux new-session -d -s rtorrent -c $(/usr/bin/rtorrent -b "${rtorrent_ip}" -p "${rtorrent_port}"-"${rtorrent_port}") &

			else

				# run rTorrent, specifying listening interface
				/usr/bin/tmux new-session -d -s rtorrent -c $(/usr/bin/rtorrent -b "${rtorrent_ip}") &

			fi

		fi
		
		first_run="false"
		reload="false"
		
		echo "[info] Sleep for 10 mins and then recheck ip and port..."
		sleep 10m

	done

fi
