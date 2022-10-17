FROM docker.io/gitpod/workspace-full

RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add - \
     && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list \
     && apt-get update \
     && apt-get install -y tailscale jq mosh screenie iputils-ping tmux\
     && update-alternatives --set ip6tables /usr/sbin/ip6tables-nft \
