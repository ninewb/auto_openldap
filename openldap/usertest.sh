
_ULIST=$(grep uid: passwd.ldif | awk '{print $2}')

for user in ${_ULIST}; do
 if [ ! -d /home/${user} ]; then
   sudo mkdir /home/${user}
   sudo cp -a /etc/skel/. /home/${user}
   sudo chown -R ${user}:${user} /home/${user}
   sudo chmod -R 700 /home/${user}
 fi
done
