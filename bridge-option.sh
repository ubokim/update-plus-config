#!/bin/bash
##########################################
# Part 3        : Bridge Configuration
# Description   : Setup your Bridge Relay
##########################################

# define colors
clear='\033[0m'
blue='\033[1;34m'
purple='\033[1;35m'
green='\033[0;32m'
red='\033[0;31m'

############################################################
# Bridge Installation and Setup                            #
############################################################


# Install obfs4proxy
printf "${purple}\n[+] Installing obfs4proxy ... ${clear}\n"
sudo sudo apt-get install obfs4proxy

# Edit the config for the Bridge file
printf "${purple}\n[+] Configuration for Bridge file${clear}\n"
read -p "Nickname : " Nickname
read -p "Email : " ContactInfo
read -p "ETH Wallet Address : " Wallet
read -p "ORPort : " ORPort
read -p "Listen Port : " ServerTransportListenAddr

# Configure inputs into config file 
printf "\n${blue}[~] Configuring Bridge file ...${clear}\n"
cat > /etc/tor/torrc << EOL

BridgeRelay 1

# Replace "TODO1" with a Tor port of your choice.
# This port must be externally reachable.
# Avoid port 9001 because it's commonly associated with Tor and censors may be scanning the Internet for this port.
ORPort ${ORPort}

ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy

# Replace "TODO2" with an obfs4 port of your choice.
# This port must be externally reachable and must be different from the one specified for ORPort.
# Avoid port 9001 because it's commonly associated with Tor and censors may be scanning the Internet for this port.
ServerTransportListenAddr obfs4 0.0.0.0:${ServerTransportListenAddr}

# Local communication port between Tor and obfs4.  Always set this to "auto".
# "Ext" means "extended", not "external".  Don't try to set a specific port number, nor listen on 0.0.0.0.
ExtORPort auto

# Replace "<address@email.com>" with your email address so we can contact you if there are problems with your bridge.
# This is optional but encouraged.
ContactInfo <${ContactInfo}> @ator: ${Wallet}

# Pick a nickname that you like for your bridge.  This is optional.
Nickname ${Nickname}
EOL   # Add RunAsDaemon 1 ???

# enable and restart the service
printf "\n${purple}[~] Enabling & Starting the Service ...${clear}\n"
systemctl enable --now tor.service
systemctl restart tor.service

printf "\n${green}[*] Finished! ${clear}\n\n"
printf "\n${red}[!] Do not forget to open your chosen ORPort in your router settings!${clear}\n"
