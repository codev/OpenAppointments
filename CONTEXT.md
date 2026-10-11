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
In the app: the service's Hide from public setting; the appointment form groups these
under Hidden From Public.
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
Admin-only list of individual inbound messages waiting to be dealt with, from customers and
unknown senders alike. Read state plays no part here: every message looks the same until
it is marked Done, and the header count is the messages not yet Done.
_Avoid_: Unknown Inbox (merged into the Inbox), To Do, Unread

**Unknown sender**:
An inbound message whose email or phone matches no customer. It sits in the Inbox labelled
Unknown sender, outlined in a darker shade of its colour, and, having no customer history,
can be deleted there.

**Done**:
An Inbox message an admin has dealt with or read. It leaves the Inbox, can be undone, and
stays in the customer history (when the sender is a customer).
_Avoid_: Archived, deleted

**Archive**:
The Inbox filter listing Done messages, each with Undo to return them to the Inbox. The
default filter, Inbox, lists the rest.

**Read**:
Whether a customer's message has been looked at, shown on the customer page only (bold until
Mark as read); the Inbox does not use it.

**Extra questions**:
The configurable questions a customer answers when booking, such as Pronouns and Access
needs.
_Avoid_: Custom fields

**Customer history**:
Every message to and from a customer, shown on the customer page; marking an Inbox message
as dealt with never removes it from here.
