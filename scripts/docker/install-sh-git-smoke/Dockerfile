FROM node:25-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/docker/install-sh-git-smoke/run.sh /usr/local/bin/clawdbot-install-git-smoke
COPY public/install.sh /opt/clawdbot-install.sh
RUN chmod +x /usr/local/bin/clawdbot-install-git-smoke \
  && chmod a+r /opt/clawdbot-install.sh

ENTRYPOINT ["/usr/local/bin/clawdbot-install-git-smoke"]
