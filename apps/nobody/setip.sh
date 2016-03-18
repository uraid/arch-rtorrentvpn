#!/bin/bash

echo "[info] Configuring rTorrent bind interface..."

if [[ -f ~/.rtorrent.rc ]]; then
	# get currently allocated ip address for adapter tun0
	LOCAL_IP=`ifconfig tun0 2>/dev/null | grep 'inet' | grep -P -o -m 1 '(?<=inet\s)[^\s]+'`
	
	echo "[info] Manually setting rTorrent listen interface to $LOCAL_IP"
	
	# set bind interface ip address for rtorrent
	sed -i -e "s/.*bind.*\=.*/bind = ${LOCAL_IP}/g" /config/rtorrent/config/rtorrent.rc
fi

# while loop to check bind ip every 5 mins
while true
do
	# get currently allocated ip address for adapter tun0
	LOCAL_IP=`ifconfig tun0 2>/dev/null | grep 'inet' | grep -P -o -m 1 '(?<=inet\s)[^\s]+'`
	
	# get current rtorrent bind ip address in config file
	RTORRENT_LISTEN_INTERFACE=$(< /config/rtorrent/config/rtorrent.rc grep -P -o -m 1 'bind\s?\=\s?.*' | grep -P -o -m 1 '[\d\.]+')

	# if current bind interface ip is different to tunnel local ip then re-configure rtorrent
	if [[ $RTORRENT_LISTEN_INTERFACE != "$LOCAL_IP" ]]; then
		echo "[info] rTorrent listening interface IP $RTORRENT_LISTEN_INTERFACE and OpenVPN local IP $LOCAL_IP different, configuring rTorrent..."

		# set bind interface to tunnel local ip
		sed -i -e "s/.*bind.*\=.*/bind = ${LOCAL_IP}/g" /config/rtorrent/config/rtorrent.rc

		echo "[info] Restarting rTorrent to force the changed bind interface to take effect..."

		# kill rtorrent named process, will be restarted by supervisor
		/usr/bin/killall rtorrent
		
		# create file to indicate edit has been done so rtorrent can start (on startup only)
		touch /home/nobody/ip_set

	fi

	sleep 5m

done
