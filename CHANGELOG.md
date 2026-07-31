# Changelog

The about page lists these notes; every release needs a section here matching
CloudronManifest.json.

## 1.4.0

- Captcha settings reworked: the CAPTCHA switch is gone from Booking Settings, the Integrations page switches are the only control
- Separate "Active for customers" and "Active for login" captcha switches; login and recovery are gated with ALTCHA or Turnstile per the provider setting
- Saving captcha settings validates that the active provider is fully configured (ALTCHA HMAC key, Turnstile key pair) and shows an error otherwise
- Activating Turnstile requires solving a live test challenge on the settings page, proving the keys and domain allowlist work on this site before captcha can lock anyone out
- Remove the legacy image captcha code left from the port
- Integrations page shows a status line per integration with a tick when active; webhooks show their count
- Theme settings show live preview cards for every theme, rendered with the current brand colours
- Umami Analytics integration: own instance URL and Website ID, optional session replays and heatmaps recorder
- Exports run in the background and produce both a plain ODS and a zip with images; the five newest backups stay on the server with admin-only dated downloads
- ODS imports can restore settings (integrations included) via a Settings tickbox, unticked by default; new settings flow through export and import automatically
- Exported ODS sheets have bold header rows and columns sized to their contents
- Imports take a plain ODS plus an optional images zip for pictures; the combined zip bundle upload is gone
- Provider, assistant and admin passwords export as stored hashes and restore on import; assistants and admins have their own import tickboxes, unticked by default
- Header: logged in user shown under the OpenAppointments title, settings menu is a cog aligned to the page edge, nav dropdowns stack above page panels; footer booking link removed
- Custom CSS box on the Theme page, applied to the booking pages and the admin interface, kept across theme changes and backed up as a setting
- Card booking: originals are kept (and are what backups carry) while uploads and imports also store two 400x400 variants, White Border and Zoomed; per-set picture style selects on Booking Settings choose which shows; existing pictures are processed once by a migration
- Card booking: starts at Select Category, picking one reveals and scrolls to its services under a Select Service heading; uncategorised services show from the start; four full-width cards per row on desktop and centred text on cards without an image
- Selecting a service or provider scrolls to its description under the cards, shown without repeating the picture
- Going back to a selection step starts it over: category view restored and selections cleared (rescheduling keeps its prefill)
- Categories can be marked Hidden to drop them and their services from the booking page; the flag rides export and import
- The Select Provider First switch is a button beside Next instead of a link under the content
- The wizard Next buttons follow the theme's primary colour instead of always being black

## 1.3.2

- Fix Internal server error from the captcha challenge endpoint (altcha gem 2.0 API), which broke login and booking when ALTCHA captcha was enabled
- Security: update Rails to 8.1.3.1 for the Active Storage variant processing vulnerability (CVE-2026-66066)
- Disable the unused Active Storage variant processor; pictures are served as uploaded

## 1.3.1

- Secretaries are now called Assistants throughout, including all translations
- Old /secretaries URLs and the /api/v1/secretaries endpoints keep working as aliases
- Bulgarian translation fixes

## 1.3.0

- Unguessable booking link slugs for services and providers with a Regenerate Link button
- Booking wizard: clickable step indicators with completion checks, provider-first option, hideable order switch and Powered by credit
- Service and provider pictures and descriptions under the booking dropdowns; provider About and Description of services fields
- Zip import bundles (ODS plus images), import failure summaries, per-record error handling
- Confirmation page links the company website, downloads an ics file; ics attached to confirmation emails
- Longer text custom fields, taller notes, alphabetical admin lists, customers by last interaction
- Embedding: login button hidden in iframes, WordPress embed boxes, frames shrink as well as grow
- Backend footer spread evenly; release notes on the about page

## 1.2.0

- Messages: unified notifications system with templates, audiences, channels and logs; incoming email; SMS provider settings
- Seven new themes with brand colours, suggested palettes and live accessibility checks; Theme settings page
- Manage data: ODS export, ODS/CSV import, database reset; REST API name alias; AGPL license correction

## 1.1.1

- Ten feature round: OpenAppointments branding, single name field, service-first wizard, cards display with pictures, phone or email rule, Cloudflare Turnstile, 10to8 import page, Outline theme, iframe embedding, new app icon

## 1.1.0

- Cloudron packaging fixes

## 1.0.0

- Port of Easy!Appointments from PHP to Rails
