FROM binhex/arch-openvpn
MAINTAINER binhex

# additional files
##################

# add supervisor conf file for app
ADD setup/*.conf /etc/supervisor/conf.d/

# add bash scripts to install app
ADD setup/root/*.sh /root/

# add bash script to setup iptables
ADD apps/root/*.sh /root/

# add bash script to run sabnzbd
ADD apps/nobody/*.sh /home/nobody/

# add pre-configured config files for nobody
ADD config/nobody/ /home/nobody/

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh /home/nobody/*.sh && \
	/bin/bash /root/install.sh

# docker settings
#################

# map /config to host defined config path (used to store configuration from app)
VOLUME /config

# map /data to host defined data path (used to store data from app)
VOLUME /data

# expose port for scgi
EXPOSE 5000

# expose port for http
EXPOSE 9080

# expose port for https
EXPOSE 9443

# expose port for privoxy
EXPOSE 8118

# expose port for dht udp
EXPOSE 6881

# expose port for incoming connections
EXPOSE 6890

# set permissions
#################

# run script to set uid, gid and permissions
CMD ["/bin/bash", "/root/init.sh"]