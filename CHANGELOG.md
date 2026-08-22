# Changelog

The about page lists these notes; every release needs a section here matching
CloudronManifest.json.

## 1.8.1

- The booking page's cancel appointment button says Cancel, as its hint text does, instead of Delete

## 1.8.0

- Calendar view divided into Appointments (a table view) and the traditional Calendar view and the Appointments view has been improved with better filters and navigation
- Appointments view only shows working providers with a list of providers not working on that day at the top
- Improvements to provider working plans: buttons for adding holidays and overtime are clearer in a provider working plan; working days added inside a longer unavailable period are shown correctly in the admin interface
- Backup improvements: backups are now shown in the spreadsheet in the order they are saved in, backups covers message templates, webhooks and more settings - note the backup can contain passwords and other authentication data so store it securely
- Fixed Timezone: new option under general settings to use the default timezone everywhere
- Messages and notification settings moved to the cog menu with the other settings
- Message Settings can email a report to admins when a message fails to send
- robots.txt blocks AI crawlers (Ultimate AI Block List v1.8)
- The browser warns before leaving a page with unsaved changes
- Minor fixes: pictures save correctly when adding a provider; settings side menus indicate the current page; 10to8 import matches existing providers by name as well as email

## 1.7.0

- General Settings can rename Provider and Service (e.g. Stylist) across the English interface

## 1.6.4

- Crash reports are emailed to the administrator

## 1.6.3

- Hidden providers added to backup and restore

## 1.6.2

- Message button on the calendar opens the customer page scrolled to the conversation panel

## 1.6.1

- The Messages button on the calendar appointment popover shows the customer's unread message count in a bubble
- Fix 406 Not Acceptable on mobile and other unrecognised browsers (the rails browser version guard is gone)
- Messages button in calendar neater

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
