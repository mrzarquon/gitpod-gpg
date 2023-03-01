#!/bin/bash

set -euo pipefail

if [[ -v GPG_ID && ! -z "$GPG_ID" ]]; then
    # pedantically ensure $HOME/.gnupg is setup correctly
    mkdir -p $HOME/.gnupg
    chown -R $(whoami) $HOME/.gnupg
    chmod 700 $HOME/.gnupg
    find $HOME/.gnupg -type d -exec chmod 700 {} \;
    find $HOME/.gnupg -type d -exec chmod 700 {} \;
    gpg --keyserver keys.openpgp.org --recv-keys ${GPG_ID}
    gpgconf --kill gpg-agent
    git config --global user.signingkey $GPG_ID
    git config commit.gpgsign true
    # ensure the gpg-agent is gone for ssh to create it since
    # we don't have StreamLocalBindUnlink on the server / workspace
    rm -f "$HOME/.gnupg/S.gpg-agent*"
    echo "trusted-key $GPG_ID" >> "$HOME/.gnupg/gpg.conf"
else
    echo "You don't have a GPG_ID so this example won't run right now"
fi