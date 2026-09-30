# syntax=docker/dockerfile:1

FROM alpine:3.24

RUN apk add --no-cache dnsmasq iproute2 lxc lxc-download nftables openssh-server

COPY etc/ssh/sshd_config /etc/ssh/sshd_config
COPY var/lib/lxc/dom0/config /var/lib/lxc/dom0/config
COPY --chmod=755 usr/local/libexec/lxc-shell /usr/local/libexec/lxc-shell
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
