# Changelog

The about page lists these notes; every release needs a section here matching
CloudronManifest.json.

## 1.4.1

- Fix receiving email through the server: connect to the mail server's TLS IMAP port
- Fix clicking a customer doing nothing when the customer has appointment history

## 1.4.0

- Captchas: there is now one control on the Integrations page, you can select ALTCHA or Cloudflare Turnstile and activate it for customer booking and/or provider logins
- Integrations page now shows what is active
- New Umami Analytics integration
- Theme page: live preview cards for every theme and a Custom CSS section for changing the theme
- Backups: export creates an ODS and an images zip to download separately, the five newest are kept for admin download
- Import: settings, assistants, admins and staff passwords restore with images being imported from an optional separate zip
- Card booking revamp: pick a category then a service, categories can be hidden, four cards per row, pictures processed to 400x400 with White Border or Zoomed styles per set
- Drag to reorder services, categories and providers, with the order used on the booking page
- Booking wizard polish: themed Next buttons, description pictures in the dropdown view, back navigation starts a step over
- Admin header and footer tidy up

## 1.3.2

- Fix Internal server error from captchas
- Security: update Rails to 8.1.3.1 for the Active Storage variant processing vulnerability (CVE-2026-66066)

## 1.3.1

- Secretaries are now called Assistants throughout, including all translations
- Former /secretaries URLs and the /api/v1/secretaries endpoints keep working as aliases
- Bulgarian translation fixes

## 1.3.0

- Unguessable booking link slugs for services and providers with a Regenerate Link button
- Booking wizard: clickable step indicators with completion checks, provider-first option, hideable order switch and Powered by credit
- Service and provider pictures and descriptions under the booking dropdowns; provider About and Description of services fields
- Improvements to zip import
- Confirmation page links to the company website and allows the customer to download an ics file; the ics file is attached to confirmation emails
- Longer text custom fields, taller notes, alphabetical admin lists, customers by last interaction
- Embedding: login button hidden in iframes, WordPress embed boxes, frames shrink as well as grow
- Backend footer spread evenly; release notes on the about page

## 1.2.0

- Messages: unified notifications system with templates, audiences, channels and logs; incoming email; SMS provider settings
- Seven new themes with brand colours, suggested palettes and live accessibility checks on new Theme settings page
- Manage data: ODS export, ODS/CSV import, database reset

## 1.1.1

- Ten new features: OpenAppointments branding, single name field, service-first wizard, cards display with pictures, phone or email rule, Cloudflare Turnstile, 10to8 import page, Outline theme, iframe embedding, new app icon

## 1.1.0

- Cloudron packaging fixes

## 1.0.0

- Port of Easy!Appointments from PHP to Rails
