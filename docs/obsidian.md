# Obsidian

All three hosts import `common/obsidian.nix`, which installs Obsidian and
registers `~/ObsidianVault`. Remotely Save 0.5.25 is pinned with hashed release
assets and enabled for that vault. Rebuild each host to apply the configuration.

On first launch, open ObsidianVault and allow community plugins if prompted.
In Settings → Remotely Save, select WebDAV and enter:

- Server: `https://myfiles.fastmail.com/`
- Username: your full Fastmail username
- Password: a Fastmail app password with **Files (WebDAV)** access

Use the server root above: Remotely Save uses the vault name `ObsidianVault`
as its remote subfolder by default. Test the connection before syncing. Match
any encryption password and other sync settings used by your existing devices.
Configure automatic sync in the plugin if desired.

Connection settings live in the writable
`~/ObsidianVault/.obsidian/plugins/remotely-save/data.json`, outside the Nix
store. Configure them on each host. Keep that file out of version control.

References: [Fastmail WebDAV](https://www.fastmail.help/hc/en-us/articles/1500000277882-Remote-file-access-WebDAV),
[Remotely Save](https://github.com/remotely-save/remotely-save).
