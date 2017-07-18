#!/bin/bash

echo "Check if you use the sudo-mode or root account. Script can not install anything without rights on your /usr/local/bin and /usr/lib directories."
echo "Do you use sudo or root?[y/n]"
read choice
if [$choice -ne "y" ]
then
    exit 1
fi

sudo mkdir /usr/lib/onetools
sudo cp ../rake/* /usr/lib/onetools
sudo cp ./ontool /usr/local/bin/

echo "Restart bash"
