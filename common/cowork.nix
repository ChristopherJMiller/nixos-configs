# Prerequisites for Claude Desktop's Cowork tab (packages/claude-desktop).
#
# Cowork runs its tasks in a QEMU/KVM VM that the desktop app hosts itself.
# Besides /dev/kvm it opens /dev/vhost-vsock, which only `kvm` group members
# may open, and it needs the vhost_vsock module loaded. The app checks all of
# this once at launch, and a group change only takes effect after logging out
# and back in. See https://code.claude.com/docs/en/desktop-linux
{ ... }:

{
  users.users.chris.extraGroups = [ "kvm" ];
  boot.kernelModules = [ "vhost_vsock" ];
}
