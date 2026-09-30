# flypervisor

Run a Linux VM as a Fly Machine.

## Setup

```sh
# First, set the app name and machine size in `fly.toml`.

fly volumes create data -r iad -s 100
fly secrets set BOOTSTRAP_SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)" --stage

fly deploy --ha=false
```

To SSH over IPv4, set up a dedicated IP with `fly ips allocate-v4`. This is a separate charge. See [the docs](https://docs.fly.io/networking/services#dedicated-ipv4) for more information.

#### License

<sup>
Copyright (C) jae beller, 2026.
</sup>
<br />
<sup>
Released under the <a href="LICENSE">MIT License</a>.
</sup>
