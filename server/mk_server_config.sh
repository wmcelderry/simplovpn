#!/bin/bash

id=$1

MY_ROOT="$(dirname "$(realpath "${0}")")"


#get access to functions in 'common.sh'
source "${MY_ROOT}/common.sh"


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

#optional further hardening: must be enabled on all clients and server if on any!
	enable_tls_auth_server >> "${outfile}"
fi
