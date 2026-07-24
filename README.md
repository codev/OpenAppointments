# OpenAppointments

Appointment scheduler, a Rails 8.1 port of Easy!Appointments 1.6.0.

## Setup

```bash
mise install                     # ruby per mise.toml
bundle install
bin/rails openappointments:install   # db:prepare + seeds + initial admin (password printed)
bin/dev
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

New features since the fork from Easy!Appointments 1.6.0 - many of these are opinionated features, the Easy!Appointment choices weren't wrong, they just weren't what I needed:

- Name field (replaces first and last name fields)
- Service page and provider divided into two pages. Service page is first by default but you can pass a parameter to the URL - `?first=provider`) - to swap them
- Card display mode - option instead of dropdowns, also includes optional uploadable pictures for each service and provider
- Option to require phone OR email as well as the existing options to require either of them
- Cloudflare Turnstile captcha option
- Admin import page (supporting Sign In App/10to8 CSV)
- Database reset option
- Outline theme
- Iframe embedding support to embed the booking widget on a website + embed code page


## Operations

Scheduled tasks (driven by the Cloudron scheduler addon in production, see CloudronManifest.json):

```bash
bin/rails openappointments:sync     # pull provider Google Calendar changes
bin/rails openappointments:cleanup  # GDPR retention: purge stale customers
bin/rails openappointments:backup   # VACUUM INTO a timestamped SQLite copy
```

- Data retention: set the `data_retention_days` setting (0 disables). Cleanup deletes
  customers created before the cutoff with no appointment ending on or after it;
  deletion cascades their appointments.
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
