#!/bin/bash

SCRIPT_ROOT="$(dirname "$(realpath "${0}")")"

CN="$1"
SERVER_DNS="$2"
CLIENT_IP="$3"

source "${SCRIPT_ROOT}/configFunctions.sh"

"${SCRIPT_ROOT}/mk_client_config.sh" "${CN}" "${SERVER_DNS}"

#call function from configFunctions.sh
configClient "${CN}" "${CLIENT_IP}"
