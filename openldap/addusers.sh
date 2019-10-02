# Password hash is "inside"

ldapadd -x -D "cn=admin,dc=aws,dc=com" -w Harmony! -H ldap:// -f sysusers.ldif
ldapadd -x -D "cn=admin,dc=aws,dc=com" -w Harmony! -H ldap:// -f testusers.ldif
ldapadd -x -D "cn=admin,dc=aws,dc=com" -w Harmony! -H ldap:// -f sasusers.ldif
