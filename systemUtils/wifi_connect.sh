#!/bin/bash

option=""
wifi=""
psswd=""

read -p "List current wifis?[y/n] " option

while [ ! "$option" == "y" ] && [ ! "$option" == "n" ]; do
	read -p "Incorrect option [y/n] " option
done

if [ "$option" == "y" ]; then
	nmcli device wifi rescan
	nmcli device wifi list
elif [ "$option" == "n" ]; then
	echo "Ok, moving on."
fi

read -p "Select your wifi: " wifi
stty -echo
read -p "The password: " psswd
stty echo

echo "Attempting to connect"

nmcli device wifi connect "$wifi" password "$psswd"
