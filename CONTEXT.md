# OpenAppointments

Booking system for Open Out, a community hairdresser. Customers book appointments with
stylists online; staff manage the diary, messages and notifications.

## People

**Customer**:
One person who receives a service. Two customers may share an email address or phone
number (a partner booking for someone else), so contact details do not identify a customer
on their own: a booking is the same customer only when the contact details and the name
both match.
_Avoid_: Client, user

**Stylist**:
Staff member whose time customers book; each has a working plan and a column on the
Appointments page.
_Avoid_: Provider (code and upstream Easy!Appointments term only)

**Working stylist**:
A stylist who, on a day being viewed, has working hours after exceptions and all-day time
off, or has any appointment that day.

**Admin**:
Staff member who manages settings, customers and the Inbox. Cannot have a calendar column;
a person who is both keeps a separate stylist account.

## Booking

**Service**:
Something a customer can book, with a duration and a slot interval.

**Non-service**:
A service hidden from the public booking pages that staff book to reserve stylist time,
such as Meeting or Admin tasks.
_Avoid_: Unavailability (blocked time with no service)

**Booking window**:
How far ahead customers can book, in days. Each day at the release time (business
timezone) the next day at the far end of the window opens for booking.
_Avoid_: Future booking limit, horizon

**Release time**:
The time of day at which the next day in the booking window opens.

**Slot interval**:
The step between the start times offered to customers for a service (every 15 minutes,
every 30 minutes). It is not a gap kept free after an appointment.
_Avoid_: Buffer

## Messages

**Inbox**:
Admin-only list of individual inbound customer messages waiting to be dealt with.

**Unknown Inbox**:
Admin-only list of inbound messages from senders that match no customer, with the same Done
as the Inbox.

**Done**:
An Inbox message an admin has dealt with. It leaves the Inbox, can be undone, and stays in
the customer history.
_Avoid_: Archived, deleted

**Extra questions**:
The configurable questions a customer answers when booking, such as Pronouns and Access
needs.
_Avoid_: Custom fields

**Customer history**:
Every message to and from a customer, shown on the customer page; marking an Inbox message
as dealt with never removes it from here.
