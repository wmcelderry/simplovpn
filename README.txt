
1. regenerate  server:
	1.1 create new VM image:
	1.2. copy and extract server_setup_scripts.tar.gz in to home folder
	1.3. run server_setup_script.sh as:
		./server_setup_script.sh
		and type 'YES' (uppercase) to generate a new PKI CA and get started...

2. for each client:
		generate an ovpn and CCD config file using either the 'configNetwork.sh' or 'configClient.sh' script. see examples from bottom of server_setup_script.sh

3. prepare Ras Pi (or other device):
	3.1 fresh Pi image
	3.1 add the client_scripts.tar.gz
	3.2. run the setup script as something like:
			./pi_setup_script.sh rac1.vpn.karmacomputing.co.uk user server disabled
#NB:
	Must change 'rac1' for each device,
	'user' must match username on server
	'server' must identify the server to copy config files from
	'disabled' can be changed to 'local_enabled' to allow ssh access to the pi from the network it is on.
