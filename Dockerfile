# syntax=docker/dockerfile:1

FROM alpine:3.24

RUN apk add --no-cache dnsmasq iproute2 lxc lxc-download nftables

COPY var/lib/lxc/guest/config /var/lib/lxc/guest/config
COPY --chmod=755 usr/local/bin/guest /usr/local/bin/guest
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
