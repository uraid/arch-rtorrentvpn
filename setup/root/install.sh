#!/bin/bash

# exit script if return code != 0
set -e

# define pacman packages
pacman_packages="base-devel git nginx php-fpm unzip unrar rsync openssl tmux mediainfo"

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

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /tmp/*