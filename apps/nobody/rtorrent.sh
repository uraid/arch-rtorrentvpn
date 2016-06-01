#!/bin/bash

# if rtorrent config file doesnt exist then copy default to host config volume
if [[ ! -f "/config/rtorrent/config/rtorrent.rc" ]]; then

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

	rtorrent_ip="0.0.0.0"

	# run rTorrent (non daemonized, blocking)
	echo "[info] All checks complete, starting rTorrent..."
	/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -s rt -n rtorrent /usr/bin/rtorrent -b ${rtorrent_ip} -o ip=${rtorrent_ip}" &>/dev/null

else

	echo "[info] VPN is enabled, checking VPN tunnel local ip is valid"

	# create pia client id (randomly generated)
	client_id=`head -n 100 /dev/urandom | md5sum | tr -d " -"`

	# run script to check ip is valid for tun0
	source /home/nobody/checkip.sh

	# set triggers to first run
	first_run="true"
	reload="false"

	# set default values for port and ip
	rtorrent_port="49160"
	rtorrent_ip="0.0.0.0"

	# set sleep period for recheck (in mins)
	sleep_period="10"

	# while loop to check ip and port
	while true; do

		# run scripts to identity vpn ip
		source /home/nobody/getvpnip.sh

		# if vpn_ip is not blank then run, otherwise log warning
		if [[ ! -z "${vpn_ip}" ]]; then

			# check rtorrent is running, if not then set to first_run and reload
			if ! pgrep -f /usr/bin/rtorrent > /dev/null; then

				echo "[info] rTorrent not running, marking as first run"

				# mark as first run and reload required due to rtorrent not running
				first_run="true"
				reload="true"

			else

				# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
				if [[ $rtorrent_ip != "$vpn_ip" ]]; then

					echo "[info] rTorrent listening interface IP $rtorrent_ip and VPN provider IP different, marking for reload"

					# mark as reload required due to mismatch
					first_run="false"
					reload="true"

				fi

			fi

			if [[ $VPN_PROV == "pia" ]]; then

				# run scripts to identify vpn port
				source /home/nobody/getvpnport.sh

				if [[ $first_run == "false" ]]; then

					# if vpn port is not an integer then log warning
					if [[ ! $vpn_port =~ ^-?[0-9]+$ ]]; then

						echo "[warn] PIA incoming port is not an integer, downloads will be slow, does PIA remote gateway supports port forwarding?"

						# set vpn port to current rtorrent port, as we currently cannot detect incoming port (line saturated, or issues with pia)
						vpn_port="${rtorrent_port}"

					elif [[ $rtorrent_port != "$vpn_port" ]]; then

						echo "[info] rTorrent incoming port $rtorrent_port and VPN incoming port $vpn_port different, marking for reload"

						# mark as reload required due to mismatch
						first_run="false"
						reload="true"

					# run netcat to identify if port still open, use exit code
					nc_exitcode=$(/usr/bin/nc -z -w 3 "${rtorrent_ip}" "${rtorrent_port}")

					elif [[ "${nc_exitcode}" -ne 0 ]]; then

						echo "[info] rTorrent incoming port closed, marking for reload"

						# mark as reload required due to mismatch
						first_run="false"
						reload="true"

					fi

				else

					# if vpn port is not an integer then set to standard incoming port and log warning
					if [[ ! $vpn_port =~ ^-?[0-9]+$ ]]; then

						echo "[warn] PIA incoming port is not an integer, downloads will be slow, does PIA remote gateway supports port forwarding?"

					fi

					# mark as reload required due to first run
					first_run="true"
					reload="true"

				fi

			fi

			if [[ $reload == "true" ]]; then

				if [[ $first_run == "false" ]]; then

					echo "[info] Reload required, stopping rtorrent..."

					# kill tmux session running rtorrent
					/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux kill-session -t rt"

					echo "[info] rTorrent stopped, removing any rTorrent session lock files left over from the previous process..."
					rm -f /config/rtorrent/session/*.lock

				fi

				echo "[info] All checks complete, starting rTorrent..."

				if [[ $VPN_PROV == "pia" ]]; then

					# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface and port (port is pia only)
					/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -p ${vpn_port}-${vpn_port} -o ip=${vpn_ip} -o dht_port=${vpn_port}"

					# set rtorrent ip and port to current vpn ip and port (used when checking for changes on next run)
					rtorrent_ip="${vpn_ip}"
					rtorrent_port="${vpn_port}"

				else

					# run tmux attached to rTorrent (daemonized, non-blocking), specifying listening interface
					/usr/bin/script /home/nobody/typescript --command "/usr/bin/tmux new-session -d -s rt -n rtorrent /usr/bin/rtorrent -b ${vpn_ip} -o ip=${vpn_ip}"

					# set rtorrent ip to current vpn ip (used when checking for changes on next run)
					rtorrent_ip="${vpn_ip}"

				fi

			fi

			if [[ "${DEBUG}" == "true" ]]; then

				echo "[debug] VPN incoming port is $vpn_port"
				echo "[debug] rTorrent incoming port is $rtorrent_port"
				echo "[debug] VPN IP is $vpn_ip"
				echo "[debug] rTorrent IP is $rtorrent_ip"

			fi

			# wait for rtorrent process to start (listen for port)
			while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
				sleep 0.1
			done

			# run php plugins for rutorent (required for scheduler and rss feed plugins)
			/usr/bin/php /usr/share/webapps/rutorrent/php/initplugins.php admin

			# reset triggers to negative values
			first_run="false"
			reload="false"
		
		else

			echo "[warn] VPN IP not detected"

		fi

		echo "[info] Sleeping for ${sleep_period} mins before rechecking listen interface and port (port checking is for PIA only)"
		sleep "${sleep_period}"m

	done

fi
