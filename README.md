# flypervisor

Run a Linux VM as a Fly Machine.

## Setup

<details>
<summary>Manual setup with flyctl</summary>
Copy `fly.toml` to `vm-<your-vm-name>.toml`. Customize the app name, region, disk size, machine size, and exposed ports. Deploy with:

```sh
VM_NAME="<your-vm-name>"
fly deploy -c "vm-$VM_NAME.toml" --ha=false
```

Get a root shell with `fly ssh console --pty -C guest`. I highly recommend installing and configuring an SSH server for easier access.

Exposed ports must be defined in `vm-*.toml`. Re-deploy to apply changes.
</details>

Install the `flyperctl` CLI:

```sh
# make sure ~/.local/bin exists and is in $PATH
curl -fL https://raw.githubusercontent.com/jbellerb/flypervisor/refs/heads/trunk/bin/flyperctl \
    > ~/.local/bin/flyperctl
chmod +x ~/.local/bin/flyperctl
```

Create a new VM with `flyperctl create <name> [--key ~/.ssh/id_ed25519.pub]`. By default, this creates an Ubuntu 26.04 VM in iad with 4 cores, 8 GiB of memory, and 100 GiB of storage. Press `e` to edit the generated `fly.toml`, or provide different values with command line flags.

After creating a new VM, list it with `flyperctl list`. You can view its status with `flyperctl show <name>` and start/stop it with `flyperctl start|stop|restart <name>`.

## Networking

By default, VMs aren't exposed to the internet. To access it over your private [6PN](https://docs.fly.io/networking/private-networking), create a WireGuard tunnel with `fly wireguard create <org> <gateway region> [<network name>]` (the gateway region can differ from the region your VM lives in). Once connected, SSH into the 6PN address on port 2222. To access your VM without a VPN connection, create it with `flyperctl create <name> --public`. This sets up a public service at `<name>.fly.dev`. All Fly Apps include a dedicated IPv6 address. Dedicated IPv4 addresses are available separately.

As flypervisor VMs are Fly Machines, they can host public services on Fly.io's global Anycast network. Add a service to your VM's `fly.toml` with `flyperctl edit <name>`. Refer to [the docs](https://docs.fly.io/networking/services) for more information on services.

<details>
<summary>Configs for common services</summary>
HTTPS:

```toml
[[services]]
  protocol = 'tcp'
  internal_port = 8080
  auto_stop_machines = 'off'
  auto_start_machines = false

  [[services.ports]]
    port = 80
    handlers = ['http']
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ['tls', 'http']
```

SSH:

```toml
[[services]]
  protocol = 'tcp'
  internal_port = 2222
  auto_stop_machines = 'off'
  auto_start_machines = false

  [[services.ports]]
    port = 22
```

PostgreSQL:

```toml
[[services]]
  protocol = 'tcp'
  internal_port = 5432
  auto_stop_machines = 'off'
  auto_start_machines = false

  [[services.ports]]
    port = 5433
    handlers = ['pg_tls']
```

DNS:

```toml
[[services]]
  protocol = 'udp'
  internal_port = 53
  auto_stop_machines = 'off'
  auto_start_machines = false

  [[services.ports]]
    port = 53
```

MQTT:

```toml
[[services]]
  protocol = 'tcp'
  internal_port = 1883
  auto_stop_machines = 'off'
  auto_start_machines = false

  [[services.ports]]
    port = 8883
    handlers = ['tls']
    tls_options = { "alpn" = ["mqtt"] }
```
</details>

If the VM was created without `--public`, you'll need to set up a public IP address. Add a dedicated IPv6 address with `fly ips allocate-v6 --app <name>`. If you only need to host an HTTP service, add a shared IPv4 address with `fly ips allocate-v4 --shared --app <name>`. TLS certificates and custom domain names work like any other Fly App. All other services require a dedicated IPv4. See [the docs](https://docs.fly.io/networking/services#dedicated-ipv4) for more information.

#### License

<sup>
Copyright (C) jae beller, 2026.
</sup>
<br />
<sup>
Released under the <a href="LICENSE">MIT License</a>.
</sup>
