# flypervisor

Run a Linux VM as a Fly Machine.

## Setup

Copy `fly.toml` to `vm-<your-vm-name>.toml`. Customize the app name, region, disk size, machine size, and exposed ports. Deploy with:

```sh
VM_NAME="<your-vm-name>"
fly deploy -c "vm-$VM_NAME.toml" --ha=false
```

Get a root shell with `fly ssh console --pty -C guest`. I highly recommend installing and configuring an SSH server for easier access.

Exposed ports must be defined in `vm-*.toml`. Re-deploy to apply changes. To SSH or use any other non-HTTP ports over IPv4, set up a dedicated IP with `fly ips allocate-v4`. See [the docs](https://docs.fly.io/networking/services#dedicated-ipv4) for more information.

#### License

<sup>
Copyright (C) jae beller, 2026.
</sup>
<br />
<sup>
Released under the <a href="LICENSE">MIT License</a>.
</sup>
