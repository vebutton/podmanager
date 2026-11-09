#!/bin/sh
# Ansible Vault password client: asks for the vault password in a macOS dialog
# and prints it to stdout for ansible-vault. Lets ansible-vault run without a
# terminal (e.g. from Claude Code). Wired in via vault_password_file in
# ansible.cfg. Cancelling the dialog exits non-zero, so the vault command fails.
exec osascript \
  -e 'text returned of (display dialog "Ansible Vault password (podmanager)" default answer "" with hidden answer with title "podmanager")'
