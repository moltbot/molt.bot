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

COPY scripts/docker/install-cli-git-smoke/run.sh /usr/local/bin/openclaw-install-cli-git-smoke
COPY public/install-cli.sh /opt/openclaw-install-cli.sh
RUN chmod +x /usr/local/bin/openclaw-install-cli-git-smoke \
  && chmod a+r /opt/openclaw-install-cli.sh

ENTRYPOINT ["/usr/local/bin/openclaw-install-cli-git-smoke"]
