#!/bin/bash

CN="$1"
SERVER_DNS="$2"
CLIENT_IP="$3"

source configFunctions.sh

./mk_client_config.sh "${CN}" "${SERVER_DNS}"

#call function from configFunctions.sh
configClient "${CN} "${CLIENT_IP}"
