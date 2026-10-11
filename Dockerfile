# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

ARG SOURCE_DATE_EPOCH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/cache/ldconfig \
    << 'EOF'
snapshot=${SOURCE_DATE_EPOCH:+$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%dT%H%M%SZ)}

rm -f /etc/apt/apt.conf.d/docker-clean
# trixie-slim doesn't have ca-certificates, so fetching over HTTPS fails.
# Fetching over HTTP is safe since Apt verifies OpenPGP signatures.
printf '%s\n' \
    'Acquire::Snapshots::URI::Host::deb.debian.org "http://snapshot.debian.org/archive/@PATH@/@SNAPSHOTID@/";' \
    'Acquire::Snapshots::URI::Origin::Debian "http://snapshot.debian.org/archive/debian/@SNAPSHOTID@/";' \
    'Acquire::Snapshots::URI::Override::Label::Debian-Security "http://snapshot.debian.org/archive/debian-security/@SNAPSHOTID@/";' \
    > /etc/apt/apt.conf.d/50snapshot-http

apt-get ${snapshot:+--snapshot "$snapshot"} update || exit
apt-get ${snapshot:+--snapshot "$snapshot"} install -y --no-install-recommends \
    ca-certificates dnsmasq-base gnupg iproute2 lxc nftables wget xz-utils \
    || exit
EOF

COPY var/lib/lxc/guest/config /var/lib/lxc/guest/config
COPY --chmod=755 usr/local/bin/guest /usr/local/bin/guest
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
