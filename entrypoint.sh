#!/bin/sh

ROOTFS=/data/rootfs
SSHDIR=/data/ssh
HOSTKEYDIR=/data/sshd
DOM0_HOSTNAME="${FLY_APP_NAME:+$FLY_APP_NAME.fly.dev}"
DOM0_HOSTNAME="${DOM0_HOSTNAME:-dom0}"

mkdir -p -m 700 "$SSHDIR" "$HOSTKEYDIR"

if ! test -f "$SSHDIR/authorized_keys"
then
    if test -z "$BOOTSTRAP_SSH_PUBKEY"
    then
        echo "error: pass your public key as a secret named BOOTSTRAP_SSH_PUBKEY" >&2
        exit 1
    fi
    echo "$BOOTSTRAP_SSH_PUBKEY" > "$SSHDIR/authorized_keys"
    chmod 600 "$SSHDIR/authorized_keys"
fi

if ! test -f "$HOSTKEYDIR/ssh_host_ed25519_key"
then
    ssh-keygen -q -t ed25519 -N '' -f "$HOSTKEYDIR/ssh_host_ed25519_key" || exit 1
fi

# bootstrap the lxc container
if ! test -f "$ROOTFS/etc/os-release"
then
    mkdir -p "$ROOTFS"
    lxc-create -n bootstrap -t download --dir "$ROOTFS" -- \
        --dist "${DIST:-ubuntu}" --release "${RELEASE:-resolute}" --arch amd64 \
        --variant default || exit 1
    rm -rf /var/lib/lxc/bootstrap
    echo "$DOM0_HOSTNAME" > "$ROOTFS/etc/hostname"
fi

# set up the bridge network
if ! ip link show br0 > /dev/null 2>&1
then
    ip link add br0 type bridge || exit 1
    ip addr add 10.0.3.1/24 dev br0
    ip addr add fd00:0:3::1/64 dev br0
    ip link set br0 up
fi

echo 1 > /proc/sys/net/ipv4/ip_forward
echo 2 > /proc/sys/net/ipv6/conf/eth0/accept_ra
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

nft -f - << EOF || exit 1
table inet dom0
delete table inet dom0
table inet dom0 {
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 10.0.3.0/24 oifname "eth0" masquerade
        ip6 saddr fd00:0:3::/64 oifname "eth0" masquerade
    }
    chain forward {
        type filter hook forward priority filter;
        tcp flags syn tcp option maxseg size set rt mtu
    }
}
EOF


# move out of the root cgroup and delegate controllers
if test -f /sys/fs/cgroup/cgroup.controllers
then
    mkdir -p /sys/fs/cgroup/init
    for p in $(cat /sys/fs/cgroup/cgroup.procs)
    do
        echo "$p" > /sys/fs/cgroup/init/cgroup.procs 2> /dev/null || true
    done
    sed -e 's/ / +/g' -e 's/^/+/' /sys/fs/cgroup/cgroup.controllers \
        > /sys/fs/cgroup/cgroup.subtree_control
    mkdir -p /sys/fs/cgroup/lxc
fi

dnsmasq --interface=br0 --bind-interfaces --no-resolv --no-hosts \
    --server="$(sed -n '/^nameserver/ { s/^nameserver[[:space:]]*//p; q; }' /etc/resolv.conf)" \
    --dhcp-range=10.0.3.10,10.0.3.254,12h \
    --dhcp-host=00:16:3e:00:00:02,10.0.3.2 \
    --dhcp-range=::,constructor:br0,ra-stateless \
    --enable-ra --dhcp-leasefile=/run/dnsmasq.leases || exit 1

sh -c 'echo $$ > /sys/fs/cgroup/lxc/cgroup.procs 2> /dev/null
    exec lxc-start -n dom0 -d -l INFO -o /dev/stderr "$@"' - \
    -s lxc.uts.name="$DOM0_HOSTNAME" || exit 1
lxc-wait -n dom0 -s RUNNING -t 30 || exit 1

/usr/sbin/sshd -D -e &
SSHD=$!

trap 'lxc-stop -n dom0 -t 8; kill $SSHD 2> /dev/null' TERM INT

lxc-wait -n dom0 -s STOPPED &
wait $! || true
kill $SSHD 2> /dev/null || true
wait $SSHD 2> /dev/null || true
