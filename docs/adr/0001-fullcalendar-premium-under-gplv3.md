# ADR-0001: FullCalendar Premium under its GPLv3 option

Date: 2026-11-25. Status: accepted.

## Context

The Calendar's Day view needs one column per stylist (resource columns) and a day that
scrolls sideways rather than squashing the columns. FullCalendar's Standard bundle, vendored
since the port, has neither; its Premium bundle of the same version (6.1.19) has both
(`resourceTimeGridDay`, `dayMinWidth`) and is a superset: same global, same views, same
options, so the swap is one file.

FullCalendar Premium is tri-licensed: commercial, Creative Commons non-commercial, or GPLv3
for open source projects, the last enabled with the key `GPL-My-Project-Is-Open-Source`.

## Decision

Vendor the Premium bundle in place of the Standard one and use it under the GPLv3 option.
OpenAppointments is AGPLv3, which is GPLv3 compatible. The key is set once in
`calendarOptions` (`app/javascript/utils/calendar_events.js`) and a test in
`test/integration/calendar_test.rb` checks the bundle and the key.

## Consequences

- Anyone deploying a closed fork needs a FullCalendar commercial licence; the AGPL already
  requires the source to be offered, so this adds no new obligation for this project.
- Upgrades fetch `fullcalendar-scheduler@<version>/index.global.min.js` from npm, not
  `fullcalendar`; the moment plugin stays as it is.
