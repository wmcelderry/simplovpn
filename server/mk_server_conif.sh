#!/bin/bash

id=$1


#get access to functions in 'common.sh'
source common.sh


#confirm parameters, or ask for values:

if [[ -z "${id}" ]] ; then
	read -p "server id not given on cmd line, please enter the name of the server now:" id
fi

echo "creating server configuration for ${id}"
read -p "Continue? [y/N]" REPLY

if [[ "${REPLY}" == "Y" ]] ; then

	outfile=${id}.ovpn

	ensure_server_exists

	server_header > "${outfile}"
	common_settings >> "${outfile}"
	embedCA >> "${outfile}"
	embedCert >> "${outfile}"
	embedKey >> "${outfile}"
	embedDH >> "${outfile}"

#optional further hardening: must be enabled on all clients and server if on any! >> "${outfile}"
	enable_tls_auth_server >> "${outfile}"
fi
