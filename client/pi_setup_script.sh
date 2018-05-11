#!/bin/bash

CN="${1}"
EN_LOCAL_SSH="${2:-disabled}" #defaule to disabled. /local_enabled


#summary:
#0. check/request necessary option values
#1. install openvpn software
#2. copy and install ovpn file generated on server
#3. autostart the new vpn
#4. configure firewall
	#disable all local access (option to allow SSH from local network - default off!)
#5. enable packet forwarding from tunnel to LAN (modify firewall setting and kernel setting)
#6. prioritise communication over eth1 (NB: name of interface could change!)
#7. highlight consider if only SSH key access is a agood idea (WM: suggests yes!) see illustrative sshKeyOnly function below.





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


function permissiveIPTables()
{
	sudo iptables -P INPUT ACCEPT
	sudo iptables -F INPUT

	sudo iptables -P FORWARD ACCEPT
	sudo iptables -F FORWARD
}



function installOpenVPN()
{
	sudo apt install -y openvpn
}

function downloadOVPNConfig()
{
	USER="${1}"
	SERVER="${2}"
	CN="${3}"

#assume the config file is in the user's home directory on the server...
	scp "${USER}@${SERVER}:${CN}.ovpn" .
}

function placeConfig()
{
	CN="${1}"
	VPN_NAME="${2}"

#install in the correct place, set permissions but as it's on a PI the key could easily be stolen, so the firewall on the server is configured to allow access from the admin network only.
	sudo mv "${CN}.ovpn" /etc/openvpn/karma_vpn.conf
	sudo chmod 600 /etc/openvpn/karma_vpn.conf
	sudo chown root:root /etc/openvpn/karma_vpn.conf
}


function autostartVPN()
{
	CONF_BASE_NAME="${1}"
#modify file
	sudo sed -i 's/^#\?AUTOSTART="none"/AUTOSTART="'"${CONF_BASE_NAME}"'"/g' /etc/default/openvpn
}



function configFW()
{

	EN_LOCAL_SSH="${1}"

#alternative setting:
	#EN_LOCAL_SSH="local_enabled"


	#NB: no need to allow udp packets for the VPN as the clients connect outbound only.
#generic rules required when default policy will be DROP:
	sudo iptables -A INPUT -i lo -j ACCEPT
	sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#accept anything from the VPN
	sudo iptables -A INPUT -i tun0 -j ACCEPT

#optionally enable ssh access from the local network (otherwise new connections will only be available over the tunnel, not directly over the LAN):
	if [[ "${EN_LOCAL_SSH}" == "local_enabled" ]] ; then
		sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        # Ensure that Pi is set-up to enable ssh upon reboot
        sudo touch /boot/ssh
	fi

	sudo iptables -P INPUT DROP

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


function enableForwarding()
{
#immediately
	sudo sysctl net.ipv4.ip_forward=1 > /dev/null
#in future after reboots
	sudo sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

#allow connections from tun0 to eth0 only.
	sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT

#if forwarding to network from tunnel, masquerade.
	#MASQUERADE anything from tun0 address range going to LAN.
	sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

#update firewall settings:
	saveFW
}


function prioritiseInterface()
{
	IFACE_NAME="${1}"

	#append the following to dhcpcd.conf:
	sudo tee -a /etc/dhcpcd.conf > /dev/null <<-EOF
		interface ${IFACE_NAME}
		metric 100

	EOF

}


function configClient()
{

	CN="${1}"
	EN_LOCAL_SSH="${2:-disabled}" #default to disabled. /local_enabled

#0.
	if [[ -z "${CN}" ]]; then
		read -p "Please enter the common name of this device to download the correct OVPN config file from:" CN
	fi


	if [[ -z "${EN_LOCAL_SSH}" ]]; then
		read -p "Allow SSH access from the local network, i.e. can people on the client network ssh to this device? ('local_enabled' to enable, otherwise disabled)" EN_LOCAL_SSH
	fi



#1.
	installOpenVPN


	#must have pushed .ovpn file with the script
#2
	#downloadOVPNConfig "${USER}" "${SERVER}" "${CN}"
	placeConfig "${CN}"

#3.
	autostartVPN

#4.
	configFW "${EN_LOCAL_SSH}"

#5.
	enableForwarding

#6.
	echo "NB: This script assumes the dongle will be assigned the name 'eth1', but that may not be the case!"
	prioritiseInterface "eth1"
#7.
	echo "Consider making this device ONLY allow access to SSH with authorized key. Reminder how in this script, function 'sshKeyOnly'"
#8. start immediately:
	sudo systemctl start openvpn@karma_vpn.service
}


configClient "${CN}" "${EN_LOCAL_SSH}"

