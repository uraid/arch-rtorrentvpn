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

# configure php-fpm for user nobody, group users
echo "" >> /etc/php/php-fpm.conf
echo "; Specify user to create php-fpm socket" >> /etc/php/php-fpm.conf
echo "listen.owner = nobody" >> /etc/php/php-fpm.conf
echo "" >> /etc/php/php-fpm.conf
echo "; Specify group to create php-fpm socket" >> /etc/php/php-fpm.conf
echo "listen.group = users" >> /etc/php/php-fpm.conf

# hard set path to curl as rutorrent doesnt seem to find it from PATH
sed -i -e "s/\"curl\"\t\=>.*/\"curl\"  \=> \'\/usr\/bin\/curl\'\,     \/\/ Something like \/usr\/bin\/curl\. If empty will be found in PATH\./g" "/etc/webapps/rutorrent/conf/config.php"

# set autotools/autowatch to 30 secs scan time, default is 300 secs
sed -i -e "s/\$autowatch_interval \= 300\;/\$autowatch_interval \= 30\;/g" "/usr/share/webapps/rutorrent/plugins/autotools/conf.php"

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /tmp/*