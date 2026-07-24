#!/bin/bash
# Cloudron entrypoint: prepare /app/data, map Cloudron env, migrate, start the server.
set -eu

mkdir -p /app/data/db /app/data/storage /run/app-tmp /run/app-log

# Persist SECRET_KEY_BASE across restarts and updates.
if [[ ! -f /app/data/env ]]; then
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > /app/data/env
fi
source /app/data/env
export SECRET_KEY_BASE

# App host for mailer links (EA site_url equivalent).
export APP_HOST="${CLOUDRON_APP_DOMAIN:-localhost}"

# Sendmail addon -> Action Mailer SMTP env consumed by config/environments/production.rb.
export SMTP_ADDRESS="${CLOUDRON_MAIL_SMTP_SERVER:-}"
export SMTP_PORT="${CLOUDRON_MAIL_SMTP_PORT:-25}"
export SMTP_USERNAME="${CLOUDRON_MAIL_SMTP_USERNAME:-}"
export SMTP_PASSWORD="${CLOUDRON_MAIL_SMTP_PASSWORD:-}"
export SMTP_FROM="${CLOUDRON_MAIL_FROM:-}"

# Recvmail addon -> IMAP env for "Receive email through server" (Messages > Providers > Email).
export IMAP_HOST="${CLOUDRON_MAIL_IMAP_SERVER:-}"
export IMAP_PORT="${CLOUDRON_MAIL_IMAP_PORT:-993}"
export IMAP_USERNAME="${CLOUDRON_MAIL_IMAP_USERNAME:-${CLOUDRON_MAIL_SMTP_USERNAME:-}}"
export IMAP_PASSWORD="${CLOUDRON_MAIL_IMAP_PASSWORD:-${CLOUDRON_MAIL_SMTP_PASSWORD:-}}"

# Run Solid Queue inside Puma: delivers queued mail/SMS and the recurring
# reminder scan + IMAP fetch (config/recurring.yml).
export SOLID_QUEUE_IN_PUMA=1

cd /app/code

# Old container is stopped before update, SQLite is single-writer: safe to migrate on boot.
bin/rails db:prepare

# First run: seed and create the admin account (password lands in the app logs).
if [[ ! -f /app/data/.installed ]]; then
    bin/rails openappointments:install
    touch /app/data/.installed
fi

chown -R cloudron:cloudron /app/data /run/app-tmp /run/app-log

# Cloudron's nginx fronts the app; no thruster layer needed.
exec gosu cloudron:cloudron bundle exec puma -b tcp://0.0.0.0:3000 -e production
