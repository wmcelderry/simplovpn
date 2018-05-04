#!/bin/bash

VPN_SCRIPT_ROOT="$(dirname "$(realpath "${0}")")"

#Summary:
#0. generate PKI
#1. install OpenVPN software
#2. generate and install openVPN server configuration
#3. autostart vpn
#4. configure the firewall (NB: must not allow access from any key installed on a client device to anything else as would be a disaster!)
#5. enable routing
#6. reminder to (re)create the client connections configurations.

#functions defined immediately, then functions are called in appropriate order at the bottom of this script

function generatePKI()
{
#needed exactly once to get the PKI set up.  Do not lose CA or re-run as existing keys will not work...
	git clone https://github.com/OpenVPN/easy-rsa.git

	pushd easy-rsa/easyrsa3 >& /dev/null

	./easyrsa init-pki
	./easyrsa build-ca

#actually needed only for the server, but useful anyway...
	./easyrsa gen-dh

	popd
}




function installOVPN()
{
	sudo apt install -y openvpn
}

function configureOVPNServer()
{
	VPN_HOST_CN="${1}"
	CONF_FILENAME="${2}"

#generate a tls-auth key.
	openvpn --genkey --secret ta.key

	"${VPN_SCRIPT_ROOT}/mk_server_config.sh" "${VPN_HOST_CN}"

	sudo mv "${VPN_HOST_CN}.ovpn" /etc/openvpn/${CONF_FILENAME}.conf
	sudo chmod 600 /etc/openvpn/${CONF_FILENAME}.conf
	sudo chown root:root /etc/openvpn/${CONF_FILENAME}.conf

	sudo mkdir -p /etc/openvpn/ccd
}

function autostartVPNServer()
{
	CONF_FILENAME="${1}"
#modify file
	sudo sed -i 's/^AUTOSTART=.*/AUTOSTART="'"${CONF_FILENAME}"'"/g' /etc/default/openvpn
}

function configFW()
{
	ADMIN_IP_RANGE="${1}"
#when data comes in on tun0, it flows through the iptables system, and routing.
	sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A INPUT -i tun0 -j DROP


	sudo iptables -P FORWARD DROP
	sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i tun0 -o tun0 --src ${ADMIN_IP_RANGE}.0/24 -j ACCEPT

	sudo iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
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
#create a script to automatically reload after reboot:
	SCRIPT_FILE=/etc/network/if-pre-up.d/iptables_restore

	sudo tee "${SCRIPT_FILE}" > /dev/null <<-EOF
#!/bin/bash

iptables-restore < /etc/iptables.rules
EOF

	sudo chown root:root "${SCRIPT_FILE}"
	sudo chmod 744 "${SCRIPT_FILE}"
}

function enableRouting()
{
#immetiately
	sudo sysctl net.ipv4.ip_forward=1 >/dev/null
#make persistant.
	sudo sed -i 's/.*net.ipv4.ip_forward=.*/net.ipv4.forward=1/g' /etc/sysctl.conf
}


#only untested function - until on server.
function setupKarmaVPN()
{
#server:

	read -p "Do you want to generate the PKI system from scratch (this will invalidate the existing keys if completed)" REPLY
	if [[ "${REPLY}" == "YES" ]] ; then
#0.
		generatePKI
	fi
	read -p "Be sure to keep the password securely, but also it may be a while until you need it again <press enter to continue>"


#Misses last octet, currenlty hardcoded as /24.
	ADMIN_IP_RANGE=10.10.254

#1.
	installOVPN
#2.
	configureOVPNServer "server.vpn.karmacomputing.co.uk" "karma_server"
#3.
	autostartVPNServer "karma_server"
#4.
	configFW "${ADMIN_IP_RANGE}"
#5.
	enableRouting

#6.
	cat <<-EOF
#now (re)create clients - any existing clients will not work with this server as it is a new PKI CA:


#PLEASE NOTE: Admin IP range is ${ADMIN_IP_RANGE} - ONLY put keys that are going to be kept secure in it (i.e. not keys handed over to clients)!

read -p "Please enter the Server DNS:" SERVER_DNS


#NB: 82 and 83 are arbitrary.
./configClient.sh chris.karmacomputing.co.uk "\${SERVER_DNS}" ${ADMIN_IP_RANGE}.82
./configClient.sh connor.karmacomputing.co.uk "\${SERVER_DNS}" ${ADMIN_IP_RANGE}.83

if [[ "\${WE_WANT_ACCESS_TO_THEIR_NETWORK}" == "yes" ]] ; then
#if want access to other devices on the 192.168.1.x/24 network as if it were 10.10.8.x/24 through the rac:
	./configNetwork.sh rac1.karmacomputing.co.uk "\${SERVER_DNS}" 10.10.1.1 192.168.1.0 255.255.255.0 10.10.8.0
else
#else if only need ssh access to remote access client:
	./configClient.sh rac1.karmacomputing.co.uk "\${SERVER_DNS}" 10.10.1.1
fi

EOF
}
