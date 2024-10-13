#!/bin/bash

if [ $# -ne 2 ]; then
	echo "Uso: mdrive.sh <mount|unmount> <device_name>"
	exit 1
fi

if ! command -v udisksctl &> /dev/null; then
	echo "udisksctl no está instalado. Instalación: sudo pacman -S udisks2"
	exit 1
fi

if [ "$EUID" -ne 0 ]; then
	echo "AVISO: udisksctl no requiere root, pero es recomendable usar sudo"
fi

device="/dev/$2"

if [ ! -e "$device" ]; then
	echo "No existe el device: $device"
	exit 1
fi

if [ "$1" == "mount" ]; then
	if ! udisksctl mount -b "$device"; then
		echo "Error con mount $device"
		exit 1
	fi
elif [ "$1" == "unmount" ]; then
	if ! udisksctl unmount -b "$device"; then
		echo "Error con unmount $device"
		exit 1
	fi
	if ! udisksctl power-off -b "$device"; then
		echo "Error con power-off $device, en general debería de seguir siendo segura la desconexión, pero no es recomendable, intente el siguiente comando: echo 1 | sudo tee /sys/block/$2/device/delete"
		exit 1
	else
		echo "Power off completed"
	fi
else
	echo "No se ha introducido el comando correcto, mount para introducir el drive, unmount para sacarlo"
	exit 1
fi

echo "Fin del programa"

exit 0
