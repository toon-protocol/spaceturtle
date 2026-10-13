# Zones run under microsandbox, with no account

The connector's zone and the agent's zone were Docker Sandboxes (`sbx`) virtual machines. `sbx` refuses every command until the person signs in to a Docker account, and Docker has said it will not change that. An Install that cannot be made without an account at a company that has no part in it is not one command. So both zones are virtual machines under [microsandbox](https://github.com/superradcompany/microsandbox) (`msb`): one program and one library in the person's home, Apache-2.0, on KVM through libkrun, with no account, no root and no service of its own. `install.sh` installs a copy that is spaceturtle's alone, pinned by version and checksum, and the launcher drives it.

The zone images are the same. Docker's sandbox images still serve as their bases, and they boot unchanged.

## Considered Options

- **Stay on Docker Sandboxes.** Rejected: every Install needs a Docker account, the program is proprietary and cannot be patched, and signing out stops every zone on the machine.
- **Keep both, and let the person choose.** Rejected: two sets of commands, two kinds of wall and two ways for the zone to come back after a restart, each to be tested with a real run, to serve only people who already have the account.
- **The launcher drives a hypervisor itself** (Cloud Hypervisor with virtiofsd and passt). Kept as the way out if microsandbox fails us: everything microsandbox gives, from running a command in a guest to the wall, becomes the launcher's to build and keep.
- **A container runtime in place of a virtual machine** (rootless Podman with crun-krun, Kata, systemd-nspawn). Rejected: each needs root to set up, or gives no kernel boundary between the wallet and an app.

## Consequences

- An Install needs KVM that the person may use, glibc and systemd, and nothing else. The first run asks for no account.
- The agent's zone has a wall of its own: it reaches name resolution, two ports of the machine, the model provider's host, the host of the network's connector and the two hosts its skills come from, and is refused everything else. Under `sbx` the machine's policy also let it reach a list of common hosts. A host is held to the addresses its name resolves to, not to the name: holding it to the name needs microsandbox to open the zone's TLS, which is not done.
- A zone's wall and its published ports are fixed when it is made. A change to either makes the zone again. For the agent's zone the launcher carries the agent key across in memory, and what the agent keeps is in mounted directories that outlast the zone.
- A zone stays running until it is stopped, so the unit no longer has to hold a session open. It is still what starts the zone after the machine restarts and what starts the supervisor again.
- microsandbox is beta software that changes fast. It is pinned, and moving the pin needs a real run of the launcher, since the tests only stub it. Its licence is what makes this bearable: it can be forked.
- ADR 0003 rejected a virtual machine for each app because Docker Sandboxes could not run an image as its workload. microsandbox can. That decision is open again; this one does not make it.
