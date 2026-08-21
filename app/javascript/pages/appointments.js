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

    function selectedIds($select) {
        return ($select.val() || []).map(Number);
    }

    /**
     * Providers to show: those selected, or those serving a selected service, or all.
     */
    function visibleProviders() {
        const providerIds = selectedIds($filterProvider);
        const serviceIds = selectedIds($filterService);

        return vars('available_providers').filter((provider) => {
            if (!provider.services.length) {
                return false;
            }
            if (providerIds.length && !providerIds.includes(Number(provider.id))) {
                return false;
            }
            return !serviceIds.length || provider.services.some((id) => serviceIds.includes(Number(id)));
        });
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

                for (const date = start.clone(); date.isSameOrBefore(end); date.add(1, 'day')) {
                    createDateColumn($wrapper, date.toDate(), response);
                }

                resize();
            })
            .always(() => navButtons.prop('disabled', false));
    }

    function createDateColumn($wrapper, date, events) {
        const $dateColumn = $('<div/>', {class: 'date-column'}).appendTo($wrapper);

        $('<h5/>', {
            class: 'date-column-title',
            text: App.Utils.Date.format(date, vars('date_format'), vars('time_format')),
        }).appendTo($dateColumn);

        visibleProviders().forEach((provider) => {
            createProviderColumn($dateColumn, date, provider, events);
        });
    }

    function createProviderColumn($dateColumn, date, provider, events) {
        const $column = $('<div/>', {class: 'provider-column'}).appendTo($dateColumn);
        const $wrapper = $('<div/>', {class: 'calendar-wrapper'}).appendTo($column);
        const serviceIds = selectedIds($filterService);
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
        const appointments = events.appointments.filter(
            (a) =>
                Number(a.id_users_provider) === providerId &&
                (!serviceIds.length || serviceIds.includes(Number(a.id_services))),
        );
        const unavailabilities = events.unavailabilities.filter((u) => Number(u.id_users_provider) === providerId);

        fullCalendar.addEventSource([
            ...Events.workingPlanEvents(provider, dayStart.toDate(), dayStart.clone().add(1, 'day').toDate()),
            ...Events.appointmentEvents(appointments),
            ...Events.unavailabilityEvents(unavailabilities),
            ...Events.blockedPeriodEvents(events.blocked_periods),
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
        App.Utils.UI.initializeDropdown($filterProvider, {placeholder: $filterProvider.data('placeholder'), width: '100%'});
        App.Utils.UI.initializeDropdown($filterService, {placeholder: $filterService.data('placeholder'), width: '100%'});

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
