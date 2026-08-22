# Changelog

The about page lists these notes; every release needs a section here matching
CloudronManifest.json.

## 1.7.1

- Terminology hint says to capitalise the labels
- A picture chosen while adding a provider, assistant, admin, service or category is uploaded when the record is saved instead of being lost
- robots.txt blocks AI crawlers (Ultimate AI Block List v1.8)
- The browser warns before leaving a page with unsaved changes, on the record pages while adding or editing and on the settings pages once a field has been changed
- A working day added inside a longer unavailable period shows as working on the calendar and appointments pages, matching what customers can book
- Provider Working Plan: "Add Extra Days/Times Available" and "Add Unavailable Days/Times" buttons replace the single exception button; the unavailable dialog asks only for dates; the exceptions table shows a Status column instead of times
- 10to8 import matches existing providers by name as well as email, including a first name against the export's full name, so appointments land under the providers already set up
- Appointments menu item shows the table view; Calendar always shows the calendar. The per-user calendar view preference is removed
- Messages moves under the cog menu as Message Settings, with Unknown Inbox below it; Manage data is now Data Settings
- Calendar and Appointments are separate pages with their toolbars in HTML; the shared calendar behaviour lives in one JS module instead of two copies
- Appointments view: each provider column is a plain list; provider and service filters sit in the top bar next to the days selector, empty means all; prev, next and Today buttons and the date picker styled like the calendar view

## 1.7.0

- General Settings can rename Provider and Service (e.g. Stylist) across the English interface

## 1.6.4

- Crash reports are emailed to the administrator

## 1.6.3

- Provider Private flags export and import, so private providers survive a backup restore

## 1.6.2

- The calendar Messages button opens the customer page scrolled to the conversation panel with the composer focused

## 1.6.1

- The Messages button on the calendar appointment popover shows the customer's unread message count in a bubble
- Fix 406 Not Acceptable on mobile and other unrecognised browsers (the browser version guard is gone)
- The popover Messages button is the same size as the other popover buttons

## 1.6.0

- Private booking links: private providers and services (and hidden categories) can now be booked through their direct booking link while staying off the public booking page - a private provider's link locks the wizard to that provider and their services
- Rescheduling appointments on private providers or services now works
- Saving a provider, service, customer, admin, assistant or category with a duplicate email or other server error now shows the error instead of pretending it saved
- Calendar appointment popover shows the customer custom fields (for example pronouns and access needs) and has a Messages button that opens the customer conversation
- New installs default the confirmation notification to "Your appointment is confirmed"

## 1.5.2

- Fix the text editor toolbar buttons showing as empty grey squares on the legal contents and other editor pages

## 1.5.1

- SMS Gateway page now has step by step setup instructions, validates settings when you save and has a Send Test SMS button
- Default country code setting converts local numbers for SMS - each SMS provider can be restricted to only sending to default-country phones
- SMS numbers normalise to E.164 format when sending for customer who type local numbers in the booking form

## 1.5.0

- SMS through your own Android phone: new SMS Gateway provider (sms-gate.app private server) with sending, signed incoming webhooks and one-click webhook registration

## 1.4.1

- Minor fixes for receiving email through a Cloudron server and viewing customer records

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
