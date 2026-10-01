# flypervisor

Run a Linux VM as a Fly Machine.

## Setup

First, customize the app name, machine size, and exposed ports in `fly.toml`. Deploy with:

```sh
# Adjust region and size below. The machine will run in whatever region the
# volume is pinned to.
fly volumes create data --region iad --size 100
fly deploy --ha=false
```

Get a root shell with `fly ssh console -C guest`. I highly recommend installing and configuring an SSH server for easier access.

Exposed ports must be defined in `fly.toml`. Re-deploy to apply changes. To SSH or use any other non-HTTP ports over IPv4, set up a dedicated IP with `fly ips allocate-v4`. See [the docs](https://docs.fly.io/networking/services#dedicated-ipv4) for more information.

#### License

<sup>
Copyright (C) jae beller, 2026.
</sup>
<br />
<sup>
Released under the <a href="LICENSE">MIT License</a>.
</sup>
