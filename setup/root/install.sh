#!/bin/bash

# exit script if return code != 0
set -e

# define pacman packages
pacman_packages="base-devel git nginx php-fpm unzip unrar rsync openssl tmux gnu-netcat mediainfo"

# install required pre-reqs for makepkg
pacman -S --needed $pacman_packages --noconfirm

# call aor script (arch official repo)
source /root/aor.sh

# call aur script (arch user repo)
source /root/aur.sh

# configure php memory limit to improve performance
sed -i -e "s~.*memory_limit\s\=\s.*~memory_limit = 512M~g" "/etc/php/php.ini"

# configure php max execution time to try and prevent timeout issues
sed -i -e "s~.*max_execution_time\s\=\s.*~max_execution_time = 300~g" "/etc/php/php.ini"

# configure php max file uploads to prevent issues with reaching limit of upload count
sed -i -e "s~.*max_file_uploads\s\=\s.*~max_file_uploads = 200~g" "/etc/php/php.ini"

# configure php max input variables (get/post/cookies) to prevent warnings issued
sed -i -e "s~.*max_input_vars\s\=\s.*~max_input_vars = 10000~g" "/etc/php/php.ini"

# configure php upload max filesize to prevent large torrent files failing to upload
sed -i -e "s~.*upload_max_filesize\s\=\s.*~upload_max_filesize = 20M~g" "/etc/php/php.ini"

# configure php post max size (linked to upload max filesize)
sed -i -e "s~.*post_max_size\s\=\s.*~post_max_size = 25M~g" "/etc/php/php.ini"

# configure php-fpm to use tcp/ip connection for listener
echo "" >> /etc/php/php-fpm.conf
echo "; Set php-fpm to use tcp/ip connection" >> /etc/php/php-fpm.conf
echo "listen = 127.0.0.1:7777" >> /etc/php/php-fpm.conf

# configure php-fpm listener for user nobody, group users
echo "" >> /etc/php/php-fpm.conf
echo "; Specify user listener owner" >> /etc/php/php-fpm.conf
echo "listen.owner = nobody" >> /etc/php/php-fpm.conf
echo "" >> /etc/php/php-fpm.conf
echo "; Specify user listener group" >> /etc/php/php-fpm.conf
echo "listen.group = users" >> /etc/php/php-fpm.conf

# set path to curl as rutorrent doesnt seem to find it on the path statement
sed -i -e "s~\"curl\"[[:space:]]\+\=>[[:space:]]\+'',~\"curl\"   \=> \'/usr/bin/curl\'\,~g" "/etc/webapps/rutorrent/conf/config.php"

# set the rutorrent autotools/autowatch plugin to 30 secs scan time, default is 300 secs
sed -i -e "s~\$autowatch_interval \= 300\;~\$autowatch_interval \= 30\;~g" "/usr/share/webapps/rutorrent/plugins/autotools/conf.php"

# set the rutorrent schedulder plugin to 10 mins, default is 60 mins
sed -i -e "s~\$updateInterval \= 60\;~\$updateInterval \= 10\;~g" "/usr/share/webapps/rutorrent/plugins/scheduler/conf.php"

# set the rutorrent diskspace plugin to point at the /data volume mapping, default is /
sed -i -e "s~\$partitionDirectory \= \&\$topDirectory\;~\$partitionDirectory \= \"/data\";~g" "/usr/share/webapps/rutorrent/plugins/diskspace/conf.php"

# delete rutorrent tracklabels plugin (causes error messages and crashes rtorrent) and screenshots plugin (not required on headless system)
rm -rf "/usr/share/webapps/rutorrent/plugins/tracklabels" "/usr/share/webapps/rutorrent/plugins/screenshots"


cat <<EOF >> /root/init.sh
# set permissions inside container
chown -R "${PUID}":"${PGID}" /etc/webapps/ /usr/share/webapps/ /usr/share/nginx/html/ /etc/nginx/ /etc/php/ /run/php-fpm/ /var/lib/nginx/ /var/log/nginx/ /etc/privoxy/ /home/nobody/
chmod -R 775 /etc/webapps/ /usr/share/webapps/ /usr/share/nginx/html/ /etc/nginx/ /etc/php/ /run/php-fpm/ /var/lib/nginx/ /var/log/nginx/ /etc/privoxy/ /home/nobody/

# set shell for user nobody
chsh -s /bin/bash nobody

echo "[info] Starting Supervisor..."

# run supervisor
exec /usr/bin/supervisord -c /etc/supervisor.conf -n
EOF

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /tmp/*