#!/bin/sh

ROOTFS=/data/rootfs
GUEST_HOSTNAME="${FLY_APP_NAME:+$FLY_APP_NAME.fly.dev}"
GUEST_HOSTNAME="${GUEST_HOSTNAME:-guest}"

# bootstrap the lxc container
if ! test -f "$ROOTFS/etc/os-release"
then
    mkdir -p "$ROOTFS"
    lxc-create -n bootstrap -t download --dir "$ROOTFS" -- \
        --dist "${DIST:-ubuntu}" --release "${RELEASE:-resolute}" --arch amd64 \
        --variant default || exit 1
    rm -rf /var/lib/lxc/bootstrap
    echo "$GUEST_HOSTNAME" > "$ROOTFS/etc/hostname"
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

if test -n "$FLY_PRIVATE_IP"
then
    GUEST_6PN="
        ip6 daddr $FLY_PRIVATE_IP tcp dport != 22 dnat ip6 to fd00:0:3::2
        ip6 daddr $FLY_PRIVATE_IP meta l4proto udp dnat ip6 to fd00:0:3::2"
fi

nft -f - << EOF || exit 1
table inet guest
delete table inet guest
table inet guest {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "eth0" meta nfproto ipv4 dnat ip to 10.0.3.2$GUEST_6PN
    }
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
    --dhcp-host=00:16:3e:00:00:02,10.0.3.2,[::2] \
    --dhcp-range=::100,::1ff,constructor:br0,slaac,12h \
    --enable-ra --dhcp-leasefile=/run/dnsmasq.leases || exit 1

sh -c 'echo $$ > /sys/fs/cgroup/lxc/cgroup.procs 2> /dev/null
    exec lxc-start -n guest -d -l INFO -o /dev/stderr "$@"' - \
    -s lxc.uts.name="$GUEST_HOSTNAME" || exit 1
lxc-wait -n guest -s RUNNING -t 30 || exit 1

trap 'lxc-stop -n guest -t 8' TERM INT

lxc-wait -n guest -s STOPPED &
wait $! || true
