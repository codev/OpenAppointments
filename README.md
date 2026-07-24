# OpenAppointments

Appointment scheduler, a Rails 8.1 port of Easy!Appointments 1.6.0.

## Setup

```bash
mise install
bundle install
bin/rails openappointments:install
bin/dev
```

Reset the database with:

```
bin/rails db:reset openappointments:install
```

## Admin login

Username: administrator
Password: let!me!in

Change the password on first login.

## Tests

```bash
bin/rails test    # unit + integration
bin/ci            # full check: rubocop, brakeman, tests
```

## Stack

Rails 8.1, SQLite (all environments), Solid Queue/Cache/Cable, Propshaft, dartsass.
Frontend is the Easy!Appointments jQuery UI ported as-is.

Datetimes are stored as provider-local wall-clock, not UTC. See config/application.rb.

## New features

New features since the fork from Easy!Appointments 1.6.0 - many of these are opinionated features:

### Name field replaces first name and last name

There is now a single `Name` field instead of First/Last names. The REST API is still EA compatible: firstName carries the full name and lastName is accepted and merged when passed on write.

### Service and provider divided into two pages

There are now 5 pages - the booking page asks for the service first then the provider. The user can click "Select Provider First" link to swap the order or append `?first=provider` to the URL to swap the order.

### Card display mode

Set Settings - Booking - Display mode - cards. This shows categories, services and providers as cards instead of a dropdown. Pictures can be uploaded on each category, service and provider edit page.

### Phone OR Email

New "Required phone or email" in booking settings, by default on, to require a customer to enter either a phone number or an email address. You can still turn requiring them separately.


### Cloudflare Turnstile captcha option

Captcha providers now include Cloudflare Turnstile as well as Altcha. Pick the provider on the captcha settings page and paste in the site key and secret key from your Cloudflare dashboard to verify each booking is coming from a human before accepting it.

### Manage data page

An admin-only Manage data page exports the whole database as a dated ODS backup
(one sheet per record type) and imports OpenAppointments ODS backups or Sign In
App/10to8 CSV exports, with selectable record types and an appointment date
window. Re-running is safe: existing records are matched by name, email or phone
instead of being duplicated. Ticking providers creates login-capable user
accounts, so it is off by default.

### Database reset option

The Manage data page has a database reset behind a typed confirmation that wipes
business data but keeps admin accounts and settings. A full reset also deletes
administrators and settings, reseeds the defaults and recreates the install
admin with the default password.

### Themes

Seven themes replace the stock set. Themes are structural: the company,
secondary and background colours from General Settings flow into every theme as
CSS variables, and each theme offers two one-click suggested palettes. All
themes use system font stacks only (no remote fonts). General Settings shows
live WCAG AA contrast warnings with fix suggestions; every suggested palette
passes AA, guarded by test. On Coder and Fruit the background colour paints the
top bar only and the page stays white.

- Nice (default): refined modern forms with quiet fills, an accent bottom edge
  on inputs and soft depth. Friendly and neutral; works with almost any colours.
- Material: Google's Material 3 language - pill buttons, filled text fields with
  a strong active indicator, tonal surfaces and gentle elevation.
- Coder: GitHub's interface style - quiet greys, crisp 1px borders, 6px corners
  and monospace accents on step numbers and badges.
- Fruit: Apple's website look - large friendly type, generous rounding, airy
  neutral surfaces and a translucent blurred top bar.
- Neo Brutalism: monospace type, hard 2px black borders, offset block shadows
  and bold flat colour; buttons shift and cast shadows on hover.
- Outline: transparent surfaces with coloured borders instead of fills; the top
  bar is white with a primary rule under it.
- Solid: confident filled colour blocks, geometric type, soft corners and a
  gradient-tinted page.

### Iframe embedding

Under Settings - Embedding - enter the website you want to embed the booking widget on and copy the code to your website.

### Calendar sync

Each provider can sync their calendar - outbound sync works for CalDAV and Google Calendar. Google Calendar also supports inbound sync so events created in Google prevent booking those times as unavailable and events that are removed are canceled. Still todo: All-day event support.

### Minor fixes

Better layout of customer fields; Captcha and Google Calendar first on the Integrations page; per-provider captcha settings sections; Any Provider is the default in the provider dropdown instead of Please Select; Pagination in the admin views; customers page and appointments modal respect the booking field display/require settings; booking form validation messages now display; the install task's admin is redirected to the account page with a banner until the default password is changed


## Messages

Admin > Messages manages all notifications:

- Settings: global on/off switch (password resets always send), message retention,
  outgoing email subject line.
- Providers: Email (server or SMTP out, server or IMAP in), Twilio, Plivo,
  TextAnywhere, each with an Incoming switch; Android SMS Gateway is coming soon.
- Notifications: template panels with event (including Appointment Coming Up
  reminders), audiences, providers and {{Token}} texts. Defaults replicate the old
  hardcoded emails plus an 8am same-day reminder.
- Logs: every message sent/received; unknown senders land in the Unknown Inbox
  (user menu). The customer page shows each customer's thread, unread badges and a
  manual send box.

## Operations

Scheduled tasks (driven by the Cloudron scheduler addon in production, see CloudronManifest.json):

```bash
bin/rails openappointments:sync       # pull provider Google Calendar changes
bin/rails openappointments:cleanup    # GDPR retention: purge stale customers + old messages
bin/rails openappointments:backup     # VACUUM INTO a timestamped SQLite copy
bin/rails openappointments:reminders  # send due coming-up notifications
bin/rails openappointments:fetch_mail # pull unread IMAP mail into Action Mailbox
```

In production Solid Queue runs inside Puma (start.sh sets SOLID_QUEUE_IN_PUMA) and
config/recurring.yml already runs the reminder scan and mail fetch every 5 minutes;
the rake targets are for manual runs or an external cron.

- Data retention: set the `data_retention_days` setting (0 disables). Cleanup deletes
  customers created before the cutoff with no appointment ending on or after it;
  deletion cascades their appointments.
- Message retention: Messages > Settings > delete messages older than N days (0 keeps all).
- Rate limits: login, recovery, booking register, and the public availability lookups
  are per-IP rate limited (Rails 8 `rate_limit`, backed by Solid Cache).
- Security headers (X-Frame-Options SAMEORIGIN, X-Content-Type-Options, Referrer-Policy,
  Permissions-Policy) are set on every response, matching EA. See
  config/initializers/security_headers.rb.

## Icons

The app icon  `app/assets/images/logo.svg` and is duplicated at`public/icon.svg

All other variants are rendered from it:

- `app/assets/images/logo.svg` - SVG favicon link in the backend/booking/message/account layouts.
- `app/assets/images/logo.png` (192px) - login/logout/recovery/about pages, backend header and
  footer, booking header fallback when no company logo is set, 192x192 icon link in the layouts,
  and the inline CID logo in every mail (`app/mailers/application_mailer.rb`; mail clients need PNG).
- `app/assets/images/logo-16x16.png` - backend footer.
- `app/assets/images/favicon.ico` (16/32/48) - legacy favicon in the layouts.
- `app/assets/images/social-card.png` (1200x630) - og:image on the booking page.
- `public/icon.png` (512px) + `public/icon.svg` - application layout and the PWA manifest
  (`app/views/pwa/manifest.json.erb`).
- `icon.png` (256px, repo root) - Cloudron dashboard icon (`CloudronManifest.json`).

To regenerate after changing the SVG: render the sizes above with inkscape and rebuild
`favicon.ico` from the 16/32/48 PNGs with ImageMagick.

## Deployment

Cloudron packaging (manifest, Dockerfile, start.sh) and the release process are documented
in RELEASING.md.
