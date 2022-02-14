#!/usr/bin/bash

# Some constants
VCPUS=2
MEMORY=1536

[[ $# -ne 2 ]] && echo "Usage: $0 VM_NAME MAC" && exit 1
DOMAIN="$1"
MAC="$2"

sudo virsh destroy vm-${DOMAIN}
sudo virsh undefine vm-${DOMAIN}
#rm /home/alfes/.ssh/known_hosts

echo "$0: Building cloud-init image"
CI_DIR=$(mktemp -d)

cat > "${CI_DIR}/meta-data" <<EOF 
instance-id: vm-${DOMAIN}
local-hostname: ${DOMAIN}
EOF

cat > "${CI_DIR}/user-data" <<EOF
#cloud-config
fqdn: ${DOMAIN}.etl.guru
hostname: ${DOMAIN}
users:
  - name: alfes
    sudo: ['ALL=(ALL) ALL']
    groups: sudo
    shell: /bin/bash
chpasswd:
  list: |
    alfes:\$6\$rounds=4096\$qqeR65r6pvkTI.es\$fIVlXaFmY8HtxFqr2CF7UvmJHTYe6sa2fIcJsVaZtt9n.tcIgUqk8Oa20ucSKe0OphNqNSnoC1nlOMke/Tw2Q0
    root:\$6\$rounds=4096\$NuS.EFq3u260upr6\$xcbTjxcuRSbrt48dCmdZf.kP/1DlNuuVPtheWX4pxNU1IpL63A783Ej.R6ZMopcmkANlLR8jW/2spOrxfBqBH1
  expire: False
ssh_pwauth: True
packages:
  - mc
EOF

(
  cd "${CI_DIR}"
  sudo genisoimage -output /var/lib/libvirt/images/vm-${DOMAIN}.iso -volid cidata -joliet -rock user-data meta-data
)
rm -rf "${CI_DIR}"

echo "$0: copying disk image"
sudo qemu-img create -f qcow2 -F qcow2 -b "/var/lib/libvirt/images/OL8U5_x86_64-olvm-b113.qcow2" "/var/lib/libvirt/images/vm-${DOMAIN}.qcow2"

echo "$0: creating VM"
sudo virt-install --name vm-${DOMAIN} \
    --memory ${MEMORY} \
    --vcpus ${VCPUS} \
    --mac=${MAC} \
    --disk /var/lib/libvirt/images/vm-${DOMAIN}.qcow2,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/vm-${DOMAIN}.iso,device=cdrom \
    --os-type linux --os-variant ol8.5 \
    --virt-type kvm --graphics none \
    --network network=default,model=virtio \
    --noautoconsole \
    --import

echo "$0: waiting for IP"
while ! sudo virsh net-dhcp-leases --network default | grep ${DOMAIN}; do
  sleep 2
done

echo "$0: Your vm is ready to use!"

