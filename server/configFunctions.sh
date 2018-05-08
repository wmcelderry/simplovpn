#!/bin/bash

function configClient()
{
	CN="$1"
	CLIENT_IP="$2"

	sudo tee "/etc/openvpn/ccd/${CN}"  > /dev/null <<-EOF
		ifconfig-push "${CLIENT_IP}" 255.255.0.0
	EOF

	sudo chown root:root "/etc/openvpn/ccd/${CN}"
	sudo chmod 644 "/etc/openvpn/ccd/${CN}"
}

function configNetwork()
{
#must match CN from the key.
	CN="$1"
	CLIENT_IP="$2"
	CLIENT_NETWORK="$3"
	CLIENT_NETMASK="$4"
	VPN_IP_RANGE="$5"

	configClient "${CN}" "${CLIENT_IP}"

	sudo tee -a "/etc/openvpn/ccd/${CN}" > /dev/null  <<-EOF
		push "client-nat snat ${CLIENT_NETWORK} ${CLIENT_NETMASK} ${VPN_IP_RANGE}"
		iroute ${VPN_IP_RANGE} ${CLIENT_NETMASK}
	EOF
}

