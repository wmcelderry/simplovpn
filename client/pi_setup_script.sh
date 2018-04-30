#!/bin/bash

CN="${1}"
USER="${2}"
SERVER="${3}"
EN_LOCAL_SSH="${4:-disabled}" #defaule to disabled.


#summary:
#0. check/request necessary option values
#1. install openvpn software
#2. copy and install ovpn file generated on server
#3. autostart the new vpn
#4. configure firewall
	#disable all local access (option to allow SSH from local network - default off!)
#5. enable packet forwarding from tunnel to LAN (modify firewall setting and kernel setting)
#6. highlight consider if only SSH key access is a agood idea (WM: suggests yes!) see illustrative sshKeyOnly function below.





#define functions:

function sshKeyOnly()
{
#reminder of process only, currently unused/untested.

#1. copy ssh key from src_computer
#2. modify sshd_config to reject passwords.

	user="${1}"
	src_computer="${2}"

#1.
	scp "${user}@${src_computer}:.ssh/id_rsa.pub" ~/.ssh/authorized_keys

#2.
	sudo sed -i 's/^#\?\(PasswordAuthentication\).*/\1 no/p' /etc/ssh/sshd_config
}





function installOpenVPN()
{
	sudo apt install -u openvpn
}

function downloadOVPNConfig()
{
	USER="$1"
	SERVER="$2"
	CN="$3"

#assume the config file is in the user's home directory on the server...
	scp "${USER}@${SERVER}:${CN}.ovpn" .

#install in the correct place, set permissions but as it's on a PI the key could easily be stolen, so the firewall on the server is configured to allow access from the admin network only.
	sudo mv "${CN}.ovpn" /etc/openvpn/karma_vpn.conf
	sudo chmod 600 /etc/openvpn/karma_vpn.conf
	sudo chown root:root /etc/openvpn/karma_vpn.conf
}


function autostartVPN()
{
#modify file
	sudo sed -i 's/^AUTOSTART=.*/AUTOSTART="karma_vpn"/g' /etc/default/openvpn
}



function configFW()
{

#alternative to asking question every time:
	#EN_LOCAL_SSH="local_enabled"


	#NB: no need to allow udp packets for the VPN as the clients connect outbound only.
	sudo iptables -A INPUT -i lo -j ACCEPT
	sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A INPUT -i tun0 -j ACCEPT

	#optionally enable ssh access (otherwise new connections will only be available over the tunnel, not directly over the LAN):
	if [[ "${EN_LOCAL_SSH}" == "local_enabled" ]] ; then
		sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	fi

	sudo iptables -P INPUT DROP

	sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
	sudo iptables -P FORWARD DROP

#enable automatically loading the settings on next reboot:
	saveFW
	installFWRestore
}

function saveFW()
{
#save the config:
	sudo iptables-save | sudo tee /etc/iptables.rules >/dev/null
	sudo chown root:root /etc/iptables.rules
	sudo chmod 600 /etc/iptables.rules
}


function installFWRestore()
{
#automatically reload after reboot:
	sudo tee /etc/network/if-pre-up.d/iptables_restore > /dev/null <<-EOF
		#!/bin/bash

		iptables-restore < /etc/iptables.rules
	EOF 
	sudo chown root:root /etc/network/if-pre-up.d/iptables_restore
	sudo chmod 744 /etc/network/if-pre-up.d/iptables_restore
}


function enableFowarding()
{
#immediately
	sudo sysctl net.ipv4.ip_forward 1
#in future after reboots
	sudo sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

#if forwarding to network from tunnel, masquerade.
	#MASQUERADE anything from tun0 address range going to LAN.
	sudo iptables -t nat -A POSTROUTRING -o eth0 -j MASQUERADE

#update firewall settings:
	saveFW
}




#0.
if [[ -z "${CN}" ]]; then
	read -p "Please enter the common name of this device to download the correct OVPN config file from:" CN
fi

if [[ -z "${USER}" ]]; then
	read -p "Please enter the user name of the account on the configuration server to download OVPN config file from:" USER
fi

if [[ -z "${SERVER}" ]]; then
	read -p "Please enter the IP/DNS name of the configuration server to download OVPN config file from:" SERVER
fi

if [[ -z "${EN_LOCAL_SSH}" ]]; then
	read -p "Allow SSH access from the local network, i.e. can people on the client network ssh to this device? ('local_enabled' to enable, otherwise disabled)" EN_LOCAL_SSH
fi



#1.
installOpenVPN

#2
downloadOVPNConfig "${USER}" "${SERVER}" "${CN}"

#3.
autostartVPN

#4.
configFW "${EN_LOCAL_SSH}"

#5.
enableForwarding

#6.
echo "Consider making this device ONLY allow access to SSH with authorized key. Reminder how in this script, function 'sshKeyOnly'"
