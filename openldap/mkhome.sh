#!/bin/bash

function mkhomedir() {
_ULIST=$(cat /tmp/garbagein)

for user in ${_ULIST}; do
 if [ ! -d /home/${user} ]; then
   sudo mkdir /home/${user}
   sudo cp -a /etc/skel/. /home/${user}
   sudo chown -R ${user}:${user} /home/${user}
   sudo chmod -R 700 /home/${user}
 fi
done
}

mkhomedir
