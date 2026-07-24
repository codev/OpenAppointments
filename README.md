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

### Import page

An admin-only Import page can import data , it initially supports Sign In App/10to8 CSV files. Re-running is safe: existing records are matched by name, email or phone instead of being duplicated.

### Database reset option

The admin-only Import page has a database reset that wipes business data but keeps admin account and settings.

### Outline theme

New theme rendering with outlined boxes instead of solid fills.

### Iframe embedding

Under Settings - Embedding - enter the website you want to embed the booking widget on and copy the code to your website.

### Calendar sync

Each provider can sync their calendar - outbound sync works for CalDAV and Google Calendar. Google Calendar also supports inbound sync so events created in Google prevent booking those times as unavailable and events that are removed are canceled. Still todo: All-day event support.


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
