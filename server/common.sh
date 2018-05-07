
function common_settings()
{
	cat "$(dirname "$(realpath "${0}")")/common_settings.conf"
}

function embedCA()
{
cat <<-EOF
#embedded files:
<ca>
EOF

cat easy-rsa/easyrsa3/pki/ca.crt

cat <<-EOF
</ca>
EOF
}

function embedCert()
{
cat <<-EOF
<cert>
EOF

cat easy-rsa/easyrsa3/pki/issued/${id}.crt

cat <<-EOF
</cert>
EOF
}

function embedKey()
{
cat <<-EOF
<key>
EOF

cat easy-rsa/easyrsa3/pki/private/${id}.key

cat <<-EOF
</key>
EOF
}




#define client specific functions:
function ensure_client_exists()
{
#work out the path for the certificate:
cert_file="easy-rsa/easyrsa3/pki/issued/${id}.crt"

if ! [[ -f  "${cert_file}" ]] ; then
	pushd easy-rsa/easyrsa3 >& /dev/null
	./easyrsa build-client-full "${id}" nopass 1>&2
	popd >& /dev/null
fi 
}


function client_header()
{
cat <<-EOF
client
remote ${SERVER} 1194
remote-cert-tls server
resolv-retry infinite
nobind
dev tun

EOF
}


function enable_tls_auth_client()
{
cat <<-EOF
	key-direction 1
	<tls-auth>
EOF
cat ta.key
cat <<-EOF
	</tls-auth>
EOF
}


##define server specific functions:
function ensure_server_exists()
{
cert_file="easy-rsa/easyrsa3/pki/issued/${id}.crt"

if ! [[ -f  "${cert_file}" ]] ; then
	pushd easy-rsa/easyrsa3 >& /dev/null
	./easyrsa build-server-full "${id}" nopass 1>&2
	popd >&/dev/null
fi 
}




function enable_tls_auth_server()
{
cat <<-EOF
	key-direction 0
	<tls-auth>
EOF
cat ta.key
cat <<-EOF
	</tls-auth>
EOF
}



function server_header()
{
cat <<-EOF

#NB: most commonly used options are left below, but many many more settings available!

###server specific options:
#optionally restrict openVPN to a specific network interface:
;local a.b.c.d

port 1194
dev tun0


topology subnet
server 10.10.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
keepalive 10 120
max-clients 254
client-config-dir ccd


#Server setting of note:
#The more interesting configuration options (there are lots, see /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz)

#specify log locations (default syslog)
;log         openvpn.log
;log-append  openvpn.log

#example on how to add routing for a private sub net:
;route 192.168.40.128 255.255.255.248
#NB: must also add iroute to ccd/\${CN}.conf

# add the following to ccd/\${CN}.conf to configure a client.
#   ifconfig-push 10.9.0.1 10.9.0.2
#bypass the fw and enable client to client comms - not good for customers, but useful for other situations:
;client-to-client


EOF
}

function embedDH()
{
cat <<-EOF
<dh>
EOF

cat easy-rsa/easyrsa3/pki/dh.pem

cat <<-EOF
</dh>
EOF
}
