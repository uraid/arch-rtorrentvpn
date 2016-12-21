#!/bin/bash

# set sleep period for recheck (in secs)
sleep_period="10"

# wait for rtorrent process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".5000"') == "" ]]; do
	sleep 0.1
done

while true; do

	# check if rtorrent is running, if not then kill sleep process for rtorrent.sh shell
	if ! pgrep -f /usr/bin/rtorrent > /dev/null; then

		echo "[info] rTorrent not running, killing sleep process for rtorrent.sh..."
		pkill -P $(</home/nobody/rtorrent.sh.pid) sleep
		echo "[info] Sleep process killed"

		# sleep for 1 min to give rtorrent chance to start before re-checking
		sleep 1m

	fi

	sleep "${sleep_period}"s

done
