# Changelog

The about page lists these notes; every release needs a section here matching
CloudronManifest.json.

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
