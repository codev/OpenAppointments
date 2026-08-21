/**
 * Appointments page: a column per date, a FullCalendar day list per provider inside it.
 */
App.Pages.Appointments = (function () {
    const $calendarView = $('#calendar .calendar-view');
    const $selectDayInterval = $('#select-day-interval');
    const $filterProvider = $('#filter-provider');
    const $filterService = $('#filter-service');
    const $selectDate = $('#select-date');

    const Events = App.Utils.CalendarEvents;
    const moment = window.moment;

    function dayInterval() {
        return parseInt($selectDayInterval.val());
    }

    function startDate() {
        return moment(App.Utils.UI.getDateTimePickerValue($selectDate)).startOf('day');
    }

    function calendarHeight() {
        return Events.calendarHeight($('#calendar .calendar-header').outerHeight() + 65);
    }

    function selectedId($select) {
        return $select.val() ? Number($select.val()) : null;
    }

    /**
     * Providers to show: the selected one, or those serving the selected service, or all.
     */
    function visibleProviders() {
        const providerId = selectedId($filterProvider);
        const serviceId = selectedId($filterService);

        return vars('available_providers').filter((provider) => {
            if (!provider.services.length) {
                return false;
            }
            if (providerId && Number(provider.id) !== providerId) {
                return false;
            }
            return !serviceId || provider.services.some((id) => Number(id) === serviceId);
        });
    }

    function interval(record) {
        return {start: moment(record.start_datetime).toDate(), end: moment(record.end_datetime).toDate()};
    }

    /**
     * Rebuild the grid for the selected date and interval.
     */
    function reload() {
        Events.closePopover();

        const start = startDate();
        const end = start.clone().add(dayInterval() - 1, 'days');
        const navButtons = $('#calendar .calendar-header .fc-button').prop('disabled', true);

        App.Http.Calendar.getCalendarAppointmentsForTableView(start.toDate(), end.toDate())
            .done((response) => {
                const $wrapper = $calendarView.children('div').empty();
                const $notes = $('#not-working-notes').empty();

                for (const date = start.clone(); date.isSameOrBefore(end); date.add(1, 'day')) {
                    const notWorking = createDateColumn($wrapper, date.toDate(), response);

                    if (notWorking.length) {
                        $('<div/>', {
                            text: lang('not_working_on')
                                .replace('{date}', App.Utils.Date.format(date, vars('date_format'), vars('time_format')))
                                .replace('{names}', joinNames(notWorking.map((p) => p.name))),
                        }).appendTo($notes);
                    }
                }

                resize();
            })
            .always(() => {
                navButtons.prop('disabled', false);
                // Like FullCalendar, Today is disabled while today is the first column.
                $('#today').prop('disabled', start.isSame(moment(), 'day'));
            });
    }

    /**
     * "A, B and C".
     */
    function joinNames(names) {
        if (names.length < 2) {
            return names.join('');
        }
        return names.slice(0, -1).join(', ') + ' ' + lang('and') + ' ' + names[names.length - 1];
    }

    /**
     * Render a column per working provider for the date; returns the providers not working.
     */
    function createDateColumn($wrapper, date, events) {
        const $dateColumn = $('<div/>', {class: 'date-column'}).appendTo($wrapper);
        const notWorking = [];

        $('<h5/>', {
            class: 'date-column-title',
            text: App.Utils.Date.format(date, vars('date_format'), vars('time_format')),
        }).appendTo($dateColumn);

        visibleProviders().forEach((provider) => {
            if (Events.workingIntervals(provider, date).length) {
                createProviderColumn($dateColumn, date, provider, events);
            } else {
                notWorking.push(provider);
            }
        });

        return notWorking;
    }

    function createProviderColumn($dateColumn, date, provider, events) {
        const $column = $('<div/>', {class: 'provider-column'}).appendTo($dateColumn);
        const $wrapper = $('<div/>', {class: 'calendar-wrapper'}).appendTo($column);
        const serviceId = selectedId($filterService);
        const providerId = Number(provider.id);

        $('<h6/>', {text: provider.name}).prependTo($column);

        const fullCalendar = new FullCalendar.Calendar(
            $wrapper[0],
            Events.calendarOptions({
                initialView: 'listDay',
                initialDate: date,
                height: calendarHeight(),
                headerToolbar: false,
            }),
        );

        fullCalendar.render();
        $column.data('provider', provider);

        const dayStart = moment(date).startOf('day');
        const providerAppointments = events.appointments.filter((a) => Number(a.id_users_provider) === providerId);
        const appointments = providerAppointments.filter((a) => !serviceId || Number(a.id_services) === serviceId);
        const unavailabilities = events.unavailabilities.filter((u) => Number(u.id_users_provider) === providerId);
        const busy = [...providerAppointments, ...unavailabilities].map(interval);

        fullCalendar.addEventSource([
            ...Events.workingPlanEvents(provider, dayStart.toDate(), dayStart.clone().add(1, 'day').toDate()),
            ...Events.appointmentEvents(appointments),
            ...Events.unavailabilityEvents(unavailabilities),
            ...Events.blockedPeriodEvents(events.blocked_periods),
            ...Events.freeSlotEvents(provider, date, busy),
        ]);
    }

    function resize() {
        const $columns = $calendarView.find('.date-column');
        const $wrapper = $calendarView.children('div');

        $wrapper.css('min-width', '1000%');
        let width = 0;
        $columns.each((index, column) => {
            width += $(column).outerWidth();
        });
        $wrapper.css('min-width', width + 200);

        $calendarView.find('.calendar-wrapper').height(calendarHeight());
    }

    function goTo(date) {
        App.Utils.UI.setDateTimePickerValue($selectDate, date.toDate());
        reload();
    }

    function addEventListeners() {
        $('#previous-day').on('click', () => goTo(startDate().subtract(1, 'day')));
        $('#next-day').on('click', () => goTo(startDate().add(1, 'day')));
        $('#today').on('click', () => goTo(moment().startOf('day')));
        $selectDayInterval.on('change', reload);
        $filterProvider.on('change', reload);
        $filterService.on('change', reload);
        $('#reload-appointments').on('click', reload);
        $(window).on('resize', resize);
    }

    function initialize() {
        App.Utils.UI.initializeDatePicker($selectDate, {onChange: reload});

        Events.configure(reload);
        addEventListeners();

        const edit = vars('edit_appointment');
        App.Utils.UI.setDateTimePickerValue($selectDate, edit ? moment(edit.start_datetime).toDate() : new Date());
        reload();

        if (edit) {
            Events.populateAppointmentModal(edit);
        }
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
