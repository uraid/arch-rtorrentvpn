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

echo "[info] Removing any rtorrent session lock files left over from the previous run..."
rm -f /config/rtorrent/session/*.lock

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
	sleep_period="5"

	# while loop to check ip and port
	while true; do

		# run scripts to identity vpn ip
		source /home/nobody/getvpnip.sh

		if [[ $first_run == "false" ]]; then

			# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
			if [[ $rtorrent_ip != "$vpn_ip" ]]; then

				echo "[info] rTorrent listening interface IP $rtorrent_ip and VPN provider IP different, reconfiguring for VPN provider IP $vpn_ip"

				# mark as reload required due to mismatch
				rtorrent_ip="${vpn_ip}"
				reload="true"

			else

				echo "[info] rTorrent listening interface IP $rtorrent_ip and VPN provider IP $vpn_ip match"

			fi

		else

			echo "[info] First run detected, setting rTorrent listening interface $vpn_ip"

			# mark as reload required due to first run
			rtorrent_ip="${vpn_ip}"
			reload="true"

		fi

		if [[ $VPN_PROV == "pia" ]]; then

			if [[ $first_run == "false" ]]; then

				# run netcat to identify if port still open, use exit code
				if ! /usr/bin/nc -z -w 3 "${rtorrent_ip}" "${rtorrent_port}"; then

					echo "[info] rTorrent incoming port $rtorrent_port closed"

					# run scripts to identify vpn port
					source /home/nobody/getvpnport.sh

					echo "[info] Reconfiguring for VPN provider port $vpn_port"
					
					# mark as reload required due to mismatch
					rtorrent_port="${vpn_port}"
					reload="true"

				else

					echo "[info] rTorrent incoming port $rtorrent_port open"

				fi

			else

				# run scripts to identify vpn port
				source /home/nobody/getvpnport.sh

				echo "[info] First run detected, setting rTorrent incoming port $vpn_port"

				if [[ ! $vpn_port =~ ^-?[0-9]+$ ]]; then
					echo "[warn] PIA incoming port is not an integer, downloads will be slow, does PIA remote gateway supports port forwarding?"
				fi
				
				# mark as reload required due to first run
				rtorrent_port="${vpn_port}"
				reload="true"

			fi

		fi

		if [[ $first_run == "true" || $reload == "true" ]]; then

			if [[ $first_run == "false" ]]; then
			
				echo "[info] Reload required, stopping rtorrent..."
				
				# kill tmux session running rtorrent
				/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux kill-session -t rt"

				echo "[info] rTorrent stopped, removing any rTorrent session lock files left over from the previous process..."
				rm -f /config/rtorrent/session/*.lock

			fi
			
			echo "[info] All checks complete, starting rTorrent..."
			
			if [[ $VPN_PROV == "pia" ]]; then

				# run tmux attached to rTorrent, specifying listening interface and port (port is pia only)
				/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip} -p ${rtorrent_port}-${rtorrent_port}"

			else
			
				# run rTorrent, specifying listening interface
				/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip}"

			fi

		fi
		
		# reset triggers to negative values
		first_run="false"
		reload="false"
		
		echo "[info] Sleeping for ${sleep_period} mins before rechecking listen interface and port (port checking is for PIA only)"
		sleep "${sleep_period}"m

	done

fi
