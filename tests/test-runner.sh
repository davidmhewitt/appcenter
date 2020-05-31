#!/bin/bash

mkdir -p /run/dbus
mkdir -p /var
ln -s /var/run /run

dbus-daemon --system --fork
/usr/lib/policykit-1/polkitd --no-debug &
/usr/lib/packagekit/packagekitd --backend aptcc &

$1
