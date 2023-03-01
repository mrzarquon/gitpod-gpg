## GPG Signing

With the latest updates making gitpod remote IDE connections use SSH, and the just added "bring your own ssh publickey" to gitpod.io, combined that means to enable gpg signing you via agent forwarding you can now accomplish it this way:
- add publickey to your profile<br>
<img src="ssh_keys.png" alt="Screenshot of SSH Keys Setting" width="450"/><br>
- update your .ssh/config to forward gpg keys to *.gitpod.io servers, this is my example (replace with your home directory, etc):
```
Host *.gitpod.io
    ServerAliveInterval 15
    IdentityFile <YOUR_HOMEDIR>/.ssh/gitpod
    RemoteForward /home/gitpod/.gnupg/S.gpg-agent <YOUR_HOMEDIR>/.gnupg/S.gpg-agent.extra
    # currently waiting on fix to enable this properly gitpod server side
    StreamLocalBindUnlink yes
```
- Set your local machine to create an extra socket agent:
```bash
echo "extra-socket $HOME/.gnupg/S.gpg-agent.extra" >> $HOME/.gnupg/gpg-agent.conf
```
- Set your GPG_ID environment variable, using the key-id from a public key server (the prep_gpg.sh in this g.itpod.yml only runs this conditionally), in the output of `gpg --list-secret-keys --keyid-format=long` below, the AC3A6CB9E464DBDA is my public key ID, useful for both installing the key and establishing trust with it.
```
cbarker@rocinante ~ % gpg --list-secret-keys --keyid-format=long
/Users/cbarker/.gnupg/pubring.kbx
---------------------------------
sec#  rsa4096/AC3A6CB9E464DBDA 2021-02-15 [C]
```
- prep_gpg.sh is a script that I include in my before tasks to deploy my key and ensure that ~/.gnupg is configured appropriately to allow for gpg-agent socket to be bound, I have this run in my gitpod.yml before stage.
```bash
#!/bin/bash

set -euo pipefail

if [[ -v GPG_ID && ! -z "$GPG_ID" ]]; then
    # pedantically ensure $HOME/.gnupg is setup correctly
    # if it's not present when an SSH session starts, the socket won't get mounted
    mkdir -p $HOME/.gnupg
    chown -R $(whoami) $HOME/.gnupg
    chmod 700 $HOME/.gnupg
    find $HOME/.gnupg -type f -exec chmod 600 {} \;
    find $HOME/.gnupg -type d -exec chmod 700 {} \;
    gpg --keyserver keys.openpgp.org --recv-keys ${GPG_ID}
    gpgconf --kill gpg-agent
    git config --global user.signingkey $GPG_ID
    git config commit.gpgsign true
    # ensure the gpg-agent is gone for ssh to create it since
    # we don't have StreamLocalBindUnlink on the server / workspace
    rm -f "$HOME/.gnupg/S.gpg-agent*"
    echo "trusted-key $GPG_ID" >> "$HOME/.gnupg/gpg.conf"
fi
```
- Ensure your VSCode desktop settings are configured to use the ssh config file (these are all my remote ssh settings, I use non apple ssh because I like to make my life difficult):
```json
"remote.SSH.path": "/opt/homebrew/opt/openssh/bin/ssh",
"remote.SSH.enableX11Forwarding": false,
"remote.SSH.configFile": "<YOUR_HOMEDIR>/.ssh/config",
"remote.SSH.defaultExtensions": [
    "gitpod.gitpod-remote-ssh"
],
"remote.SSH.logLevel": "debug"
```

Now when you launch your workspace via VS Code IDE or Jetbrains, it should automatically forward your SSH key. If you're in the web IDE, starting an ssh session from your workstation would also suffice.

In my configuration, my yubikey (setup from drduh's [guide](https://github.com/drduh/YubiKey-Guide)) hosts my private key. A side effect of this is that any commit signing or gpg action requires either pin + physical touch, or physical touch, before it will proceed. That makes me feel relatively secure knowing that while the socket is on a remote machine, the yubikey means I have to approve any use / access to the socket (I always require touch to sign and you can set a timeout for the pin approval).

## Troubleshooting

Check that you have an agent socket mounted:
```bash
gitpod /workspace/gitpod-gpg (main) $ ls -la ~/.gnupg/
total 84
drwx------ 1 gitpod gitpod   139 Mar  1 15:52 .
drwxr-xr-x 1 gitpod gitpod  4096 Mar  1 15:52 ..
drwx------ 2 gitpod gitpod    21 Mar  1 15:52 crls.d
drwx------ 1 gitpod gitpod     6 Sep  3 01:38 private-keys-v1.d
-rw-r--r-- 1 gitpod gitpod 43401 Mar  1 15:52 pubring.kbx
-rw-r--r-- 1 gitpod gitpod 30889 Sep  3 01:38 pubring.kbx~
srwx------ 1 gitpod gitpod     0 Mar  1 15:52 S.dirmngr
srw------- 1 gitpod gitpod     0 Mar  1 15:52 S.gpg-agent
-rw------- 1 gitpod gitpod  1200 Sep  3 01:38 trustdb.gpg
```
Check that you can read the card `gpg --card-status` returning Forbidden is good:
```bash
gitpod /workspace/gitpod-gpg (main) $  gpg --card-status
gpg: error getting version from 'scdaemon': Forbidden
gpg: selecting card failed: Forbidden
gpg: OpenPGP card not available: Forbidden
```
Check that locally you can read the card with the same command:
```bash
cbarker@rocinante ~ % gpg --card-status
Reader ...........: Yubico YubiKey OTP FIDO CCID
...
...
```
Test local GPG encryption works without issue:
```bash
$ echo "test message string" | gpg --encrypt --armor --recipient $GPG_ID -o encrypted.txt && gpg --decrypt --armor encrypted.txt
gpg: encrypted with 4096-bit RSA key, ID 8F2CFC36BC781D08, created 2021-02-15
      "Chris Barker <chris@sneezingdog.com>"
test message string
``` 

## Tailscale Bonus Feature

If you set a TS_AUTH environment variable with a [tailscale auth key](https://tailscale.com/kb/1085/auth-keys/), this workspace will launch an ephemeral tailscale session for your during the command phase. See the tailscale.sh for how it works.

## Changes
2023-03-01: 
- Includes working examples for latest versions of VS code/Gitpod
- Includes Tailscale setup script