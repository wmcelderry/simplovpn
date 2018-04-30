#!/bin/bash

#optional command line params.

#id is the name of the client in the PKI system
id=$1
#identifier for server on inet: either a static IP or a DNS entry (including dynamic DNS).
SERVER=$2


#get access to functions in 'common.sh'
source common.sh


#confirm parameters, or ask for values:

if [[ -z "${id}" ]] ; then
	read -p "client id not given on cmd line, please enter the name of the client now:" id
fi

if [[ -z "${SERVER}" ]] ; then
	read -p "server identifier not given on cmd line - please enter the identifier for the server now (ip address or DNS name):" SERVER
fi


echo "creating client configuration for ${id}, connecting to server ${SERVER}"
read -p "Continue? [y/N]" REPLY

if [[ "${REPLY}" == "Y" ]] ; then

	outfile=${id}.ovpn

#do all the work:
	ensure_client_exists


	client_header > "${outfile}"
	common_settings >> "${outfile}"
	embedCA >> "${outfile}"
	embedCert >> "${outfile}"
	embedKey >> "${outfile}"

#optional further hardening: must be enabled on server and all clients if on any!
	enable_tls_auth_client >> "${outfile}"
fi
