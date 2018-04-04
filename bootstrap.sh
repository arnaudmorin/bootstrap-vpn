#!/bin/bash

# TODO: add dirname
# TODO: get out of infinite loop if error

PASSWORD=$(pwgen 64 1)
cp userdata/vpn.yaml /tmp/userdata__$$
sed -i -r "s/__PASSWORD__/$PASSWORD/" /tmp/userdata__$$

echo "Creating server vpn-$$"
openstack server create \
    --nic net-id=Ext-Net \
    --image 'Debian 9' \
    --flavor s1-2 \
    --user-data /tmp/userdata__$$ \
    vpn-$$

# Wait for VM to be ACTIVE
echo -n "Waiting for IP "
while [ 1 ] ; do
    IP=$(openstack server show vpn-$$ -f shell -c addresses | sed -nr 's/.+Ext-Net=(.+),.+/\1/p')
    echo -n '.'
    [ ! -z "$IP" ] && break
done

echo ""
echo "VPN is up at $IP. Waiting 30 secs to let it prepare..."
sleep 30

echo "Creating config file /etc/ppp/peers/vpn-$$..."

# Create config file
sudo bash -c "cat << EOF >/etc/ppp/peers/vpn-$$
pty 'pptp $IP --nolaunchpppd'
name arnaud
remotename PPTP
require-mppe-128
file /etc/ppp/options.pptp
ipparam vpn
EOF"

sudo bash -c "echo 'arnaud PPTP $PASSWORD $IP' >> /etc/ppp/chap-secrets"

# Connect
echo "Connecting..."
sudo pon vpn-$$ updetach

# Test
echo -n "Ident.me test: "
curl http://ident.me
echo ""
echo ""

# Wait
echo "Done, press any key when you want to disconnect"
read

# Disconnect
sudo poff vpn-$$

# Delete config file
sudo rm /etc/ppp/peers/vpn-$$
sudo sed -i -r "/$IP/d" /etc/ppp/chap-secrets

# Delete VM
openstack server delete vpn-$$
