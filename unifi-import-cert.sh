#!/bin/bash
# Author: Pascal Kienast,
# Script location: /etc/letsencrypt/renewal-hooks/post/unifi-import-cert.sh (important for auto renewal)

# Renew the certificate
certbot renew 

#************************************************
#********************Script**********************
#************************************************

# Set the Domain name and paths, valid DNS entry must exist
DOMAIN=unifi.dabb.digital
UNIFI_DIR=/var/lib/unifi
JAVA_DIR=/usr/lib/unifi
KEYSTORE=${JAVA_DIR}/data/keystore
LE_LIVE_DIR=/etc/letsencrypt/live
PRIV_KEY=${LE_LIVE_DIR}/${DOMAIN}/privkey.pem
CHAIN_FILE=${LE_LIVE_DIR}/${DOMAIN}/fullchain.pem


#md5 checksum um zu gucken ob cert renewed wurde
md5sum "${PRIV_KEY}" > "${LE_LIVE_DIR}/${DOMAIN}/privkey.pem.md5"


if md5sum -c "${LE_LIVE_DIR}/${DOMAIN}/privkey.pem.md5" &>/dev/null; then
	# MD5 remains unchanged, exit the script
	printf "\nCertificate is unchanged, no update is necessary.\n"
	exit 0
else
	# MD5 is different, so it's time to get busy!
	printf "\nUpdated SSL certificate available. Proceeding with import...\n"
	fi

#stop unifi, since were about to mess with its certificates
service unifi stop

# Backup previous keystore
cp /usr/lib/unifi/data/keystore /usr/lib/unifi/data/keystore.backup.$(date +%F_%R)

# Convert cert to PKCS12 format
# Ignore warnings
openssl pkcs12 -export -inkey /etc/letsencrypt/live/${DOMAIN}/privkey.pem -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem -out /etc/letsencrypt/live/${DOMAIN}/fullchain.p12 -name unifi -password pass:unifi

# Install certificate
keytool -importkeystore -deststorepass aircontrolenterprise -destkeypass aircontrolenterprise -destkeystore /usr/lib/unifi/data/keystore -srckeystore /etc/letsencrypt/live/${DOMAIN}/fullchain.p12 -srcstoretype PKCS12 -srcstorepass unifi -alias unifi -noprompt

#At this point, the Unifi Controller will work with your Let's Encrypt certificate, 
#Cloud Key has a separate internal nginx-based webserver to handle OS configuration options
#replace the default certificates in the location nginx is expecting and make permissions correct
cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/ssl/private/cloudkey.crt 
cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/ssl/private/cloudkey.key 
chown root:ssl-cert /etc/ssl/private/* 
chmod 640 /etc/ssl/private/* 
tar -cvf /etc/letsencrypt/live/${DOMAIN}/cert.tar * 
chown root:ssl-cert /etc/letsencrypt/live/${DOMAIN}/cert.tar 
chmod 640 /etc/letsencrypt/live/${DOMAIN}/cert.tar

#Restart UniFi controller
service unifi restart


