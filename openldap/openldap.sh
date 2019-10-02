#!/bin/bash

# REVISIONS:
# 5/4/18 - added creation of 'cas' in /etc/passwd as deployment fails
# 5/4/18 - added creation of home directories
# 9/12/19 - housekeeping, added memberof overlay, revised user/group injections


_PASSWD=Harmonoy!
_DOMAIN=aws.com
_BASEDN="dc=aws,dc=com"
_REPOROOT=/workspace

# Functions

function mkhomedir() {
_ULIST=$(grep uid: $_REPOROOT/viya/admin/openldap/passwd.ldif | awk '{print $2}')

for user in ${_ULIST}; do
 if [ ! -d /home/${user} ]; then
   sudo mkdir /home/${user}
   sudo cp -a /etc/skel/. /home/${user}
   sudo chown -R ${user}:${user} /home/${user}
   sudo chmod -R 700 /home/${user}
 fi
done
}

# ------------------------------------------

_OCONFIG=$_REPOROOT/viya/admin/openldap
_OPATH=/etc/openldap/slapd.d/cn=config
_MTOOLS=/usr/share/migrationtools

# Install packages
sudo yum install -y openldap-* migrationtools sssd nss-pam-ldapd

# Get the name of the host we are running on
if [ -z "${LDAP_HOST}" ]; then
    LDAP_HOST=$(hostname -f)
fi

sudo slappasswd -s ${_PASSWD}

# Update the configuration
sudo sed -i "s/olcSuffix:.*/olcSuffix: ${_BASEDN}/" ${_OPATH}/olcDatabase={2}hdb.ldif
sudo sed -i "s/olcRootDN:.*/olcRootDN: cn=admin,${_BASEDN}/" ${_OPATH}/olcDatabase={2}hdb.ldif

echo 'olcRootPW: {SSHA}s8xq3UhIbmuuNsnBCZkgltfBrBnbOMGA' | sudo tee -a ${_OPATH}/olcDatabase={2}hdb.ldif

sudo sed -i "s/dn.base=\"cn=manager.*/dn.base=\"cn=admin,${_BASEDN}\" read  by * n/" ${_OPATH}/olcDatabase={1}monitor.ldif
sudo cp -urvf /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

# Generate the certs for TLS configuration
sudo openssl req -new -x509 -nodes -out /etc/pki/tls/certs/awsldap.pem -keyout /etc/pki/tls/certs/awsldapkey.pem -subj "/C=US/ST=North Carolina/L=Cary/O=SDE/CN=${LDAP_HOST}"

sudo chown -R ldap:ldap /etc/pki/tls/certs/awsldap*.pem

# Start/Register the service
sudo systemctl start slapd
sudo systemctl enable slapd
sudo systemctl start nslcd
sudo systemctl enable nslcd

# Add the schema
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

# Add memberOf overlay
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f ${_OCONFIG}/module.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f ${_OCONFIG}/memberof.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f ${_OCONFIG}/refint.ldif

# Update Migration Tools
sudo sed -i "s/$DEFAULT_MAIL_DOMAIN = */$DEFAULT_MAIL_DOMAIN = "${_DOMAIN}";/" ${_MTOOLS}/migrate_common.ph
sudo sed -i "s/$DEFAULT_BASE = */$DEFAULT_BASE = "${_BASEDN}";/" ${_MTOOLS}/migrate_common.ph
sudo sed -i 's/$EXTENDED_SCHEMA = */$EXTENDED_SCHEMA = 1;/' ${_MTOOLS}/migrate_common.ph
sudo sed -i 's/$NAMINGCONTEXT{'passwd'}            = "ou=People";/$NAMINGCONTEXT{'passwd'}            = "ou=users";/' ${_MTOOLS}/migrate_common.ph
sudo sed -i 's/$NAMINGCONTEXT{'group'}             = "ou=Group";/$NAMINGCONTEXT{'group'}             = "ou=groups";/' ${_MTOOLS}/migrate_common.ph

# Insert base configuration
sudo ldapadd -H ldap://${LDAP_HOST}:389 -D "cn=admin,${_BASEDN}" -w ${_PASSWD} -f ${_OCONFIG}/base.ldif
sudo ldapadd -H ldap://${LDAP_HOST}:389 -D "cn=admin,${_BASEDN}" -w ${_PASSWD} -f ${_OCONFIG}/sysusers.ldif
sudo ldapadd -H ldap://${LDAP_HOST}:389 -D "cn=admin,${_BASEDN}" -w ${_PASSWD} -f ${_OCONFIG}/testusers.ldif
sudo ldapadd -H ldap://${LDAP_HOST}:389 -D "cn=admin,${_BASEDN}" -w ${_PASSWD} -f ${_OCONFIG}/sasusers.ldif
sudo ldapadd -H ldap://${LDAP_HOST}:389 -D "cn=admin,${_BASEDN}" -w ${_PASSWD} -f ${_OCONFIG}/

# Setup system authentication
sudo authconfig --enableldap --enableldapauth --enablemkhomedir --ldapserver="${LDAP_HOST}" --ldapbasedn="${_BASEDN}" --update

# Add cas to /etc/passwd
_uid=`id cas | awk '{print $1}' | sed 's/[^0-9]*//g'`
_gid=`id cas | awk '{print $2}' | sed 's/[^0-9]*//g'`
echo "cas:x:${_uid}:${_gid}:cas:/home/cas:/bin/bash" | sudo tee -a /etc/passwd 1>&2

# Create user home directories
mkhomedir
