#!/usr/bin/env bash

#https://askubuntu.com/questions/903514/command-to-set-socks-proxy
#don't run the script with sudo
#ssh  -D 8080 -f -C -q -N raza@138.197.166.221 -p 222
# ssh  -D 8081 -f -C -q -N root@139.59.93.100 -p 22
#lsof -i :8081

#ip link show wlp4s0
#ip address show wlp4s0
#ip route list

#REMOTE_USER="raza"
#REMOTE_HOST="138.197.166.221"
#REMOTE_PORT=222
LOCAL_PORT="8081"
REMOTE_USER="root"
REMOTE_HOST="167.71.236.55"
REMOTE_PORT="22"
ssh -D ${LOCAL_PORT} -f -C -q -g -N ${REMOTE_USER}@${REMOTE_HOST} -p ${REMOTE_PORT}
# -D bind address
# -f run ssh in the background
# -p port number
# -C enable compression
# -g allows remote host to connect to local forwarded ports
# -N don't execute remote commands, since we are only using it for fowarding ports
# -q quiet mode

#set socks setting in System settings > Network > network proxy
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.socks port ${LOCAL_PORT}
gsettings set org.gnome.system.proxy.socks host 'localhost'
gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '::1']"

#sudo su <<-EOF
##environment settings
#echo "socks_proxy='socks://localhost:${LOCAL_PORT}/'" >> /etc/environment
##apt settings
#echo "Acquire::socks::proxy 'socks://localhost:$LOCAL_PORT/';" >> /etc/apt/apt.conf
#EOF
