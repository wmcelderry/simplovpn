#!/bin/bash

SCRIPT_ROOT="$(dirname "$(realpath "${0}")")"

CN="$1"
SERVER_DNS="$2"
CLIENT_IP="$3"
CLIENT_NETWORK="$4"
CLIENT_NETMASK="$5"
VPN_IP_RANGE="$6"

source "${SCRIPT_ROOT}/configFunctions.sh"

#call external script
"${SCRIPT_ROOT}/mk_client_config.sh" "${CN}" "${SERVER_DNS}"

#call function from configFunctions.sh
configNetwork "${CN}" "${CLIENT_IP}" "${CLIENT_NETWORK}" "${CLIENT_NETMASK}" "${VPN_IP_RANGE}"
