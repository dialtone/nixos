#!/usr/bin/env bash
# One-time setup for the Hermes agent on dabass.
#
# Run on dabass from the root of this repo, after pulling the commit that adds
# modules/homelab/hermes.nix:
#
#   ./scripts/setup-hermes.sh
#
# It prompts for the secrets, encrypts them into secrets/hermesEnv.age with
# agenix (the plaintext never touches the repo), rebuilds, and checks that the
# container came up. Leave any platform you don't have credentials for yet
# empty; you can add it later (see the end of this script).
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true # keep '&' literal in ${var//x/y}

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

TEMPLATE=secrets/hermesEnv.template
SECRET=secrets/hermesEnv.age
IDENTITY=/persist/nixos-keys/id_ed25519

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

[[ $(hostname) == dabass ]] || die "run this on dabass"
for cmd in agenix openssl nixos-rebuild docker git; do
  command -v "$cmd" >/dev/null || [[ $cmd == docker ]] || die "missing $cmd"
done
[[ -f $TEMPLATE ]] || die "$TEMPLATE not found; pull the latest config first"

if [[ -e $SECRET ]]; then
  echo "$SECRET already exists. To change values, edit it instead:"
  echo "  cd secrets && sudo agenix -e hermesEnv.age -i $IDENTITY"
  read -rp "Overwrite it from scratch? [y/N] " ans
  [[ $ans == [yY] ]] || exit 0
  rm -f "$SECRET"
fi

cat <<'EOF'

Before you start, have these ready (anything you skip can be added later):
  - Anthropic Console API key (console.anthropic.com -> API keys, sk-ant-api03-...)
  - Telegram: bot token from @BotFather, your user id from @userinfobot
  - Discord: bot token (discord.com/developers, enable Message Content intent),
    your user id and the private channel id (Developer Mode -> Copy ID)
  - Email: dedicated mailbox address, app password, IMAP/SMTP hosts
  - Home Assistant: create a non-admin user "hermes" (Settings -> People),
    log in as it, Profile -> Security -> Long-lived access token
  - WhatsApp: your own number, digits with country code (e.g. 14155550123)
EOF

# Pasted text arrives wrapped in bracketed-paste escapes on many terminals;
# plain `read` keeps them. Turn the mode off and strip any that still arrive.
printf '\e[?2004l'

ask() { # ask VAR "prompt" [secret]
  local __v
  # Pre-set in the environment (e.g. `read -s ANTHROPIC_API_KEY; export ...`)? Use it.
  if [[ -n ${!1:-} ]]; then
    echo "$2: (taken from environment)"
    return
  fi
  # Input is echoed on purpose: hidden prompts swallow pastes on some terminals.
  read -rp "$2: " __v
  __v=${__v//$'\e[200~'/}
  __v=${__v//$'\e[201~'/}
  __v=${__v//$'\r'/}
  __v=${__v#"${__v%%[![:space:]]*}"} # trim leading whitespace
  __v=${__v%"${__v##*[![:space:]]}"} # trim trailing whitespace
  if [[ ${3:-} == secret && -n $__v ]]; then
    echo "  got ${#__v} chars"
  fi
  printf -v "$1" '%s' "$__v"
}

step "Anthropic"
ask ANTHROPIC_API_KEY "ANTHROPIC_API_KEY" secret
[[ -n $ANTHROPIC_API_KEY ]] || die "an Anthropic API key is required"
if [[ $ANTHROPIC_API_KEY != sk-ant-api* ]]; then
  echo "warning: key does not start with sk-ant-api; Hermes will treat it as an OAuth token, not an API key"
fi

step "Dashboard login (user: dialtone)"
while :; do
  ask DASHBOARD_PASSWORD "Password" secret
  ask confirm "Confirm password" secret
  [[ -n $DASHBOARD_PASSWORD && $DASHBOARD_PASSWORD == "$confirm" ]] && break
  echo "empty or mismatched, try again"
done
DASHBOARD_SECRET=$(openssl rand -hex 32)
API_SERVER_KEY=$(openssl rand -hex 32)

step "Telegram (enter to skip)"
ask TELEGRAM_BOT_TOKEN "Bot token" secret
ask TELEGRAM_ALLOWED_USERS "Your Telegram user id"

step "Discord (enter to skip)"
ask DISCORD_BOT_TOKEN "Bot token" secret
ask DISCORD_ALLOWED_USERS "Your Discord user id"
ask DISCORD_CHANNEL "Private channel id"

step "Email (enter to skip)"
ask EMAIL_ADDRESS "Hermes mailbox address"
ask EMAIL_PASSWORD "Mailbox app password" secret
ask EMAIL_IMAP_HOST "IMAP host (e.g. imap.gmail.com)"
ask EMAIL_SMTP_HOST "SMTP host (e.g. smtp.gmail.com)"
ask EMAIL_ALLOWED_USERS "Your address(es), comma separated"

step "Home Assistant (enter to skip)"
ask HASS_TOKEN "Long-lived token of the hermes HA user" secret

step "WhatsApp (enter to skip)"
ask WHATSAPP_ALLOWED_USERS "Your number(s), digits with country code"

# Refuse a token without its allowlist: the bot would just deny everyone.
[[ -z $TELEGRAM_BOT_TOKEN || -n $TELEGRAM_ALLOWED_USERS ]] || die "Telegram token given without your user id"
[[ -z $DISCORD_BOT_TOKEN || -n $DISCORD_ALLOWED_USERS ]] || die "Discord token given without your user id"
[[ -z $EMAIL_ADDRESS || -n $EMAIL_ALLOWED_USERS ]] || die "Email configured without allowed senders"

step "Encrypting $SECRET"
umask 077
CLEARTEXT=$(mktemp)
trap 'rm -f "$CLEARTEXT"' EXIT
while IFS= read -r line || [[ -n $line ]]; do
  for var in ANTHROPIC_API_KEY DASHBOARD_PASSWORD DASHBOARD_SECRET API_SERVER_KEY \
    TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS DISCORD_BOT_TOKEN DISCORD_ALLOWED_USERS \
    DISCORD_CHANNEL EMAIL_ADDRESS EMAIL_PASSWORD EMAIL_IMAP_HOST EMAIL_SMTP_HOST \
    EMAIL_ALLOWED_USERS HASS_TOKEN WHATSAPP_ALLOWED_USERS; do
    line=${line//@$var@/${!var}}
  done
  printf '%s\n' "$line"
done <"$TEMPLATE" >"$CLEARTEXT"
grep -q '@[A-Z_]*@' "$CLEARTEXT" && die "unfilled placeholder left in template"

# agenix runs "$EDITOR <file>"; using cp as the editor encrypts non-interactively
# to the recipients listed in secrets/secrets.nix.
(cd secrets && EDITOR="cp $CLEARTEXT" agenix -e hermesEnv.age)
[[ -s $SECRET ]] || die "encryption failed"
git add "$SECRET" # flakes only see files tracked by git

step "Rebuilding NixOS"
sudo nixos-rebuild switch --flake ".#dabass"

step "Waiting for the container"
for _ in $(seq 1 30); do
  systemctl is-active --quiet docker-hermes.service && break
  sleep 2
done
systemctl status --no-pager docker-hermes.service | head -n 5 || true
sudo docker logs --tail 30 hermes 2>&1 || true

cat <<EOF

Done. Next steps:

  1. Commit the encrypted secret:  git commit -m "add hermes secrets" $SECRET
  2. Dashboard:  http://hermes.dabass   (user dialtone)
     API:        http://hermes-api.dabass/v1   (bearer key below)
       sudo agenix -d secrets/hermesEnv.age -i $IDENTITY | grep API_SERVER_KEY
  3. Hermes Workspace: smb://dabass/Hermes  (mounted at /workspace in the agent)
  4. WhatsApp (dedicated number): pair once, then scan the QR from
     WhatsApp -> Settings -> Linked Devices on the Hermes phone:
       sudo docker exec -it hermes hermes whatsapp
       sudo systemctl restart docker-hermes
  5. Discord: invite the bot to your server (OAuth2 URL generator, scopes
     "bot" + "applications.commands") and give it access to the private channel.

Changing secrets later (tokens, adding a platform):
  cd secrets && sudo agenix -e hermesEnv.age -i $IDENTITY && cd ..
  git add secrets/hermesEnv.age && sudo nixos-rebuild switch --flake .#dabass
  sudo systemctl restart docker-hermes   # env files are only read at container start

Note: config.yaml in /persist/opt/services/hermes is only seeded on first
start. Delete it (with the container stopped) to re-seed from hermes.nix.
EOF
