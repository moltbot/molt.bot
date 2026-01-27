#!/usr/bin/env bash
set -euo pipefail

LOCAL_INSTALL_PATH="/opt/clawdbot-install.sh"
if [[ -n "${CLAWDBOT_INSTALL_URL:-}" ]]; then
  INSTALL_URL="$CLAWDBOT_INSTALL_URL"
elif [[ -f "$LOCAL_INSTALL_PATH" ]]; then
  INSTALL_URL="file://${LOCAL_INSTALL_PATH}"
else
  INSTALL_URL="https://clawd.bot/install.sh"
fi

curl_install() {
  if [[ "$INSTALL_URL" == file://* ]]; then
    curl -fsSL "$INSTALL_URL"
  else
    curl -fsSL --proto '=https' --tlsv1.2 "$INSTALL_URL"
  fi
}

echo "==> Installer: --help"
curl_install | bash -s -- --help >/tmp/install-help.txt
grep -q -- "--install-method" /tmp/install-help.txt

echo "==> Clone Clawdbot repo"
REPO_DIR="/tmp/moltbot-src"
rm -rf "$REPO_DIR"
git clone --depth 1 https://github.com/moltbot/moltbot.git "$REPO_DIR"

echo "==> Verify autodetect defaults to npm (no TTY)"
(
  cd "$REPO_DIR"
  set +e
  curl_install | bash -s -- --dry-run --no-onboard --no-prompt >/tmp/git-detect.out 2>&1
  code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    echo "ERROR: expected installer to succeed when repo is detected without method" >&2
    cat /tmp/git-detect.out >&2
    exit 1
  fi
  if ! sed -r 's/\x1b\[[0-9;]*m//g' /tmp/git-detect.out | grep -q "Install method: npm"; then
    echo "ERROR: expected autodetect to default to npm" >&2
    cat /tmp/git-detect.out >&2
    exit 1
  fi
)

echo "==> Install from Git (using detected checkout)"
(
  cd "$REPO_DIR"
  curl_install | bash -s -- --install-method git --no-onboard --no-prompt --no-git-update
)

echo "==> Verify wrapper exists"
test -x "$HOME/.local/bin/clawdbot"

echo "==> Verify clawdbot runs"
export PATH="$HOME/.local/bin:$PATH"
clawdbot --help >/dev/null

echo "==> Verify version matches checkout"
EXPECTED_VERSION="$(node -e "console.log(JSON.parse(require('fs').readFileSync('${REPO_DIR}/package.json','utf8')).version)")"
INSTALLED_VERSION="$(clawdbot --version 2>/dev/null | head -n 1 | tr -d '\r')"
echo "installed=$INSTALLED_VERSION expected=$EXPECTED_VERSION"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "ERROR: expected clawdbot@$EXPECTED_VERSION, got $INSTALLED_VERSION" >&2
  exit 1
fi

echo "OK"
