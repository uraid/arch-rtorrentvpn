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

	rtorrent_port="6890"
	rtorrent_ip="0.0.0.0"
	
	# run rTorrent
	echo "[info] All checks complete, starting rTorrent..."
	/usr/bin/script --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip} -p ${rtorrent_port}-${rtorrent_port}"

else

	echo "[info] VPN is enabled, checking VPN tunnel local ip is valid"

	# create pia client id (randomly generated)
	client_id=`head -n 100 /dev/urandom | md5sum | tr -d " -"`

	# run script to check ip is valid for tun0
	source /home/nobody/checkip.sh
	
	# set triggers to first run
	first_run="true"
	reload="false"
	
	# set empty values for port and ip
	rtorrent_port=""
	rtorrent_ip=""
	
	# set sleep period for recheck (in mins)
	sleep_period="10"
	
	echo "[info] Removing any rtorrent session lock files left over from the previous run..."
	rm -f /config/rtorrent/session/*.lock
	
	# while loop to check bind ip every 5 mins
	while true; do

		if [[ $VPN_PROV == "pia" ]]; then
		
			# run scripts to identify vpn port
			source /home/nobody/setport.sh

			if [[ $vpn_port =~ ^-?[0-9]+$ ]]; then

				if [[ $rtorrent_port != "$vpn_port" ]]; then
				
					echo "[info] rTorrent incoming port $rtorrent_port and PIA incoming port $vpn_port different, configuring rTorrent..."

					# mark as reload required due to mismatch
					rtorrent_port="${vpn_port}"
					reload="true"

				else

					echo "[info] rTorrent incoming port $rtorrent_port and PIA incoming port $vpn_port the same"

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

			# mark as reload required due to mismatch
			rtorrent_ip="${vpn_ip}"
			reload="true"

		else

			echo "[info] rTorrent listening interface IP $rtorrent_ip and OpenVPN local IP $vpn_ip the same"

		fi

		if [[ $first_run == "true" || $reload == "true" ]]; then

			if [[ $first_run == "false" ]]; then
			
				echo "[info] Reload required, stopping rtorrent..."
				
				# kill tmux session running rtorrent
				/usr/bin/script --command "/usr/bin/tmux kill-session -t rt"

				echo "[info] rTorrent stopped, removing any rtorrent session lock files left over from the previous process..."
				rm -f /config/rtorrent/session/*.lock

			fi
			
			echo "[info] All checks complete, starting/restarting rTorrent..."
			
			if [[ $VPN_PROV == "pia" ]]; then

				# run tmux attached to rTorrent, specifying listening interface and port (port is pia only)
				/usr/bin/script --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip} -p ${rtorrent_port}-${rtorrent_port}"

			else
			
				# run rTorrent, specifying listening interface
				/usr/bin/script --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip}"

			fi

		fi
		
		# reset triggers to negative values
		first_run="false"
		reload="false"
		
		echo "[info] Sleep for ${sleep_period} mins and then recheck vpn port and ip"
		sleep "${sleep_period}"m

	done

fi
