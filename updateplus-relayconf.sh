#!/bin/bash
##########################################
# FULL RUN RELAY INST
# Updates + Inst + Config
##########################################

# define colors
clear='\033[0m'
blue='\033[1;34m'
purple='\033[1;35m'
green='\033[0;32m'
red='\033[0;31m'


#####################################
# Required System Updates + Upgrades
#####################################

# Public Key not signed on Rock 4c out of the box
printf "${blue}\n[~] Update Public Key ...${clear}\n"
wget -O - apt.radxa.com/focal-stable/public.key | sudo apt-key add -

# System Update + Upgrade (Takes a few mins)
printf "${blue}\n[~] Updating packages ...${clear}\n"
apt update -y

printf "${blue}\n[~] Upgrading packages ...${clear}\n"
apt upgrade -y

###########################################################################
# ToR Technical: Unattended Upgrades 
# https://community.torproject.org/relay/setup/guard/debian-ubuntu/updates/
###########################################################################

printf "\n${purple}[~] Enabling automatic software updates ...${clear}\n"

# Removes existing files in the repo and replaces them
echo "" > /etc/apt/apt.conf.d/50unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "TorProject:${distro_codename}";
};
Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::Automatic-Reboot "true";
EOL

echo "" > /etc/apt/apt.conf.d/20auto-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL

####################################################
# ToR Technical: Enable Tor Package Repo 
# https://support.torproject.org/apt/tor-deb-repo/
####################################################

printf "\n${blue}[~] Configuring Tor Project's repository ...${clear}\n"

# To enable all package managers
apt install apt-transport-https -y

# create tor.list file
printf "\n${blue}[~] Creating the tor.list file ...${clear}\n"
touch /etc/apt/sources.list.d/tor.list

printf "${blue}[~] Writing to the tor.list file ...${clear}\n"
cat > /etc/apt/sources.list.d/tor.list << EOL
deb     [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org focal main
deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org focal main
EOL

# add the gpg key
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null


# keyring install
printf "\n${purple}[~] Installing keyring ...${clear}\n"
apt update
apt install tor deb.torproject.org-keyring -y

# Package installation

######################################################################################
# This is the first prompt asking the user if theyd like to set up a Bridge or a Relay
# ####################################################################################

printf "\n${blue}[?] Would you like to set up a Middle/Guard Relay? Press n to create a Bridge instead. [Y/n] : ${clear}"
read Option1
if [[ ${Option1} == "Y" || ${Option1} == "y" ]] ; then
    printf "\n${blue}[~] Lets setup your Middle/Guard Relay ...${clear}\n"
else
    printf "\n${blue}[~] Lets setup your Bridge Relay ...${clear}\n"
    wget -q https://raw.githubusercontent.com/ubokim/update-plus-config/main/bridge-option.sh ; chmod +x bridge-option.sh ; sudo ./bridge-option.sh
    exit #exits post bridge inst and doesnt execute the script for middle/guard relay
fi

######################################################################################
# Tor config file setup
# ####################################################################################

printf "${purple}\n[+] Configuration for torrc file${clear}\n"
read -p "Nickname : " Nickname
read -p "Email : " ContactInfo
read -p "ORPort : " ORPort
read -p "ETH Wallet Address : " Wallet

printf "\n${blue}[?] Would you like to configure bandwidth limits for your relay traffic? [Y/n] : ${clear}"
read Option2
if [[ ${Option2} == "Y" || ${Option2} == "y" ]] ; then
    read -p "Relay Bandwidth Rate (KB/s) : " RelayBandwidthRateSet
    read -p "Relay Bandwidth Burst (KB/s) : " RelayBandwidthBurstSet
    RelayBandwidthRate="RelayBandwidthRate ${RelayBandwidthRateSet}"
    RelayBandwidthBurst="RelayBandwidthBurst ${RelayBandwidthBurstSet}"
else
    RelayBandwidthRate="#RelayBandwidthRate 100KB"
    RelayBandwidthBurst="#RelayBandwidthBurst 200KB"
fi

printf "\n${purple}[?] Would you like to add limits for your relay traffic? [Y/n] : ${clear}"
read Option3
if [[ ${Option3} == "Y" || ${Option3} == "y" ]] ; then
    read -p "Accounting Max : " AccountingMaxSet
    read -p "Accounting Start : " AccountingStartSet
    AccountingMax="AccountingMax ${AccountingMaxSet}"
    AccountingStart="AccountingStart ${AccountingStartSet}"
else
    AccountingMax="#AccountingMax 4 GB"
    AccountingStart="#AccountingStart day 00:00"
fi

# Torrc file config 
# ** maybe put full config file just in case? 
printf "\n${blue}[~] Configuring torrc file ...${clear}\n"
cat > /etc/tor/torrc << EOL
## Configuration file for a middle/guard Tor relay 
## See 'man tor', or https://www.torproject.org/docs/tor-manual.html,
## for more options you can use in this file.
## Tor opens a socks proxy on port 9050 by default -- even if you don't
## configure one below. Set "SocksPort 0" if you plan to run Tor only
## as a relay, and not make any local application connections yourself.
SocksPort 0
## Logs go to stdout at level "notice" unless redirected by something
## else, like one of the below lines. You can have as many Log lines as
## you want.
##
## We advise using "notice" in most cases, since anything more verbose
## may provide sensitive information to an attacker who obtains the logs.
##
## Send all messages of level 'notice' or higher to /var/log/tor/notices.log
Log notice file /var/log/tor/notices.log
## Send every possible message to /var/log/tor/debug.log
#Log debug file /var/log/tor/debug.log
## Use the system log instead of Tor's logfiles
#Log notice syslog
## To send all messages to stderr:
#Log debug stderr
## Uncomment this to start the process in the background... or use
## --runasdaemon 1 on the command line.
RunAsDaemon 1
################ This section is just for relays #####################
#
## See https://www.torproject.org/docs/tor-doc-relay for details.
## Required: what port to advertise for incoming Tor connections.
ORPort ${ORPort}
## A handle for your relay, so people don't have to refer to it by key.
Nickname ${Nickname}
## Define these to limit how much relayed traffic you will allow. Your
## own traffic is still unthrottled. Note that RelayBandwidthRate must
## be at least 20 KB.
## Note that units for these config options are bytes per second, not bits
## per second, and that prefixes are binary prefixes, i.e. 2^10, 2^20, etc.
#RelayBandwidthRate 100 KB  # Throttle traffic to 100KB/s (800Kbps)
#RelayBandwidthBurst 200 KB # But allow bursts up to 200KB/s (1600Kbps)
${RelayBandwidthRate}
${RelayBandwidthBurst}
## Use these to restrict the maximum traffic per day, week, or month.
## Note that this threshold applies separately to sent and received bytes,
## not to their sum: setting "4 GB" may allow up to 8 GB total before
## hibernating.
##
## Set a maximum of 4 gigabytes each way per period.
${AccountingMax}
## Each period starts daily at midnight (AccountingMax is per day)
#AccountingStart day 00:00
## Each period starts on the 3rd of the month at 15:00 (AccountingMax
## is per month)
#AccountingStart month 3 15:00
${AccountingStart}
## Administrative contact information for this relay or bridge. This line
## can be used to contact you if your relay or bridge is misconfigured or
## something else goes wrong.
ContactInfo <${ContactInfo}> @ator: ${Wallet}
## The port on which Tor will listen for local connections from Tor
## controller applications, as documented in control-spec.txt.
#ControlPort9051
## If you enable the controlport, be sure to enable one of these
## authentication methods, to prevent attackers from accessing it.
#HashedControlPassword
#CookieAuthentication 1
ExitRelay   0
EOL

# restart the service
printf "\n${purple}[~] Restarting onion router service ...${clear}\n"
systemctl restart tor@default

printf "\n${green}[*] Finished! ${clear}\n\n"
printf "\n${red}[!] Do not forget to open your chosen ORPort in your router settings!${clear}\n"


# reboot system for previos changes to take effect
printf "\n${red}[!] Rebooting System, Don't Exit! ...${clear}\n"
sudo reboot

# NOT SURE IF REBOOT IS NECCESARY YET, NEED TO TEST AND SEE IF IT CAN BE AVOIDED 
