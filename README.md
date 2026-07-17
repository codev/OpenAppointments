# OpenAppointments

Appointment scheduler, a Rails 8.1 port of Easy!Appointments 1.6.0.

## Setup

```bash
mise install                     # ruby per mise.toml
bundle install
bin/rails openappointments:install   # db:prepare + seeds + initial admin (password printed)
bin/dev
```

## Tests

```bash
bin/rails test    # unit + integration
bin/ci            # full check: rubocop, brakeman, tests
```

## Stack

Rails 8.1, SQLite (all environments), Solid Queue/Cache/Cable, Propshaft, dartsass.
Frontend is the Easy!Appointments jQuery UI ported as-is.

Datetimes are stored as provider-local wall-clock, not UTC. See config/application.rb.
