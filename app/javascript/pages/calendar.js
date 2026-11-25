/**
 * Calendar page: one FullCalendar showing everyone's events for the visible
 * range, filtered in the browser by the ticked stylists, services and statuses,
 * so ticking a box redraws without a fetch. The Day view gives each stylist
 * working or booked that day a column of their own.
 */
App.Pages.Calendar = (function () {
    const FILTER_TYPE_ALL = 'all';
    const STORAGE_KEY = 'OpenAppointments.CalendarFilter';
    const VIEW_KEY = 'OpenAppointments.CalendarView';
    const DAY_VIEW = 'resourceTimeGridDay';
    const WEEK_VIEW = 'timeGridWeek';
    const MONTH_VIEW = 'dayGridMonth';
    const COLUMN_MIN_WIDTH = 160; // px; narrower and the day scrolls sideways

    const $calendar = () => $('#calendar');
    const $selectFilterItem = () => $('#select-filter-item');
    const $reloadAppointments = () => $('#reload-appointments');
    const $insertWorkingPlanException = () => $('#insert-working-plan-exception');

    const Events = App.Utils.CalendarEvents;
    const TickFilter = App.Utils.TickFilter;
    const moment = window.moment;

    let fullCalendar = null;
    let refreshTimer = null;
    let request = null; // the events fetch in flight
    let loadedRange = null; // "start/end" dates of the last fetch, null before the first
    let loadedView = null; // view type of the last datesSet, so a view change over the same dates redraws
    let lastResponse = null; // the last fetch's events, redrawn when a box is ticked
    let lastResources = null; // JSON of the Day view's columns, reset only when they change

    // Ticked stylist ids, or null on a stylist's own calendar (no Stylists dropdown).
    function tickedProviders() {
        return $('#provider-filter').length ? TickFilter.selected('provider-filter') : null;
    }

    // The one stylist in focus (the hidden select, read by sync, the feed and
    // new events), or null when none or several are ticked.
    function focusProviderId() {
        const value = $selectFilterItem().val();
        return value && value !== FILTER_TYPE_ALL ? value : null;
    }

    function isProviderFilter() {
        return focusProviderId() !== null;
    }

    // Puts the single ticked stylist, else all, in focus. True when it changed.
    function setFocus() {
        const providers = tickedProviders();
        if (!providers) {
            return false; // a stylist's own calendar stays on them
        }

        const value = providers.length === 1 ? String(providers[0]) : FILTER_TYPE_ALL;
        if ($selectFilterItem().val() === value) {
            return false;
        }
        $selectFilterItem().val(value);
        return true;
    }

    function isDayView() {
        return fullCalendar.view.type === DAY_VIEW;
    }

    // With several stylists shown the legend names the ticked ones by their fill
    // colour. The Day view's column headers do that themselves.
    function renderLegend() {
        const $legend = $('#calendar-legend');
        const ticked = tickedProviders();
        const providers =
            isProviderFilter() || isDayView()
                ? []
                : vars('available_providers').filter((provider) => !ticked || ticked.includes(Number(provider.id)));
        $legend.empty().prop('hidden', providers.length === 0);
        providers.forEach((provider) => {
            $('<span/>')
                .append($('<i/>', {class: 'legend-swatch', css: {backgroundColor: Events.providerColor(provider)}}))
                .append(document.createTextNode(provider.name))
                .appendTo($legend);
        });
    }

    // The dates a view's fetch asks for.
    function visibleDates(view) {
        return [view.activeStart, view.activeEnd].map((date) => moment(date).format('YYYY-MM-DD'));
    }

    /**
     * Fetch everyone's events for the visible range, then draw them. A fetch
     * still in flight is dropped first, so only the latest answer is drawn.
     */
    function reload() {
        Events.closePopover();

        // No calendar: another page, or torn down with a callback still to land.
        if (!fullCalendar) {
            return;
        }

        const [startDate, endDate] = visibleDates(fullCalendar.view);

        if (request) {
            request.abort();
        }

        $('#loading').css('visibility', 'hidden');
        loadedRange = startDate + '/' + endDate;

        const current = App.Http.Calendar.getCalendarAppointments(FILTER_TYPE_ALL, startDate, endDate, FILTER_TYPE_ALL)
            .done((response) => {
                lastResponse = response;
                draw();
            })
            .always(() => {
                if (request === current) {
                    request = null;
                    $('#loading').css('visibility', '');
                }
            });
        request = current;
    }

    // Replace every event source with the last fetch, filtered by the ticked
    // stylists (their unavailabilities too), services and statuses.
    function draw() {
        if (!fullCalendar || !lastResponse) {
            return;
        }

        // The lists hold stylists with a service and services with a stylist:
        // an event outside them (a service no longer offered) is always shown.
        const providers = tickedProviders();
        const services = TickFilter.selected('service-filter');
        const listed = (rows, id) => rows.some((row) => Number(row.id) === Number(id));
        const shown = (providerId) =>
            !providers || !listed(vars('available_providers'), providerId) || providers.includes(Number(providerId));
        const shownService = (serviceId) =>
            !listed(vars('available_services'), serviceId) || services.includes(Number(serviceId));
        const appointments = App.Utils.StatusFilter.apply(lastResponse.appointments).filter(
            (appointment) => shown(appointment.id_users_provider) && shownService(appointment.id_services),
        );
        const focus = focusProviderId();
        const columns = isDayView() ? columnProviders(shownProviders(providers, services)) : [];

        fullCalendar.getEventSources().forEach((source) => source.remove());
        renderLegend();
        setResources(columns);

        // Filled with the stylist colour, edged with the service colour. Several
        // stylists are titled by stylist when only one service is ticked.
        const appointmentEvents = Events.appointmentEvents(
            appointments,
            !focus && services.length === 1 ? 'provider' : 'service',
        );
        const events = [
            ...appointmentEvents,
            ...Events.unavailabilityEvents(lastResponse.unavailabilities.filter((event) => shown(event.id_users_provider))),
            ...Events.blockedPeriodEvents(
                lastResponse.blocked_periods,
                columns.map((provider) => String(provider.id)),
            ),
        ];

        if (fullCalendar.view.type !== MONTH_VIEW) {
            fitHours(shownProviders(providers, services), appointmentEvents);
            const {currentStart, currentEnd} = fullCalendar.view;
            if (isDayView()) {
                // Each column is greyed by its own stylist's plan: the free time stands out.
                columns.forEach((provider) => {
                    events.push(...Events.workingPlanEvents(provider, currentStart, currentEnd, String(provider.id)));
                });
            } else {
                events.push(...Events.workingPlanEvents(Events.findProvider(focus), currentStart, currentEnd));
            }
        }

        fullCalendar.addEventSource(events);
    }

    // The ticked stylists who offer a ticked service.
    function shownProviders(tickedIds, serviceIds) {
        return vars('available_providers').filter(
            (provider) =>
                (!tickedIds || tickedIds.includes(Number(provider.id))) &&
                (provider.services || []).map(Number).some((id) => serviceIds.includes(id)),
        );
    }

    // The Day view's columns: the shown stylists working that day or with an
    // appointment that day (the List page's working stylist rule).
    function columnProviders(providers) {
        const day = fullCalendar.view.currentStart;
        const booked = new Set(
            lastResponse.appointments
                .filter((appointment) => moment(appointment.start_datetime).isSame(day, 'day'))
                .map((appointment) => Number(appointment.id_users_provider)),
        );

        return providers.filter(
            (provider) => booked.has(Number(provider.id)) || Events.workingIntervals(provider, day).length > 0,
        );
    }

    // One resource per column, set only when the columns change: setting the
    // option re-renders the view.
    function setResources(columns) {
        const resources = columns.map((provider) => ({
            id: String(provider.id),
            title: provider.name,
            eventColor: Events.providerColor(provider),
        }));
        const serialized = JSON.stringify(resources);

        if (serialized === lastResources) {
            return;
        }
        lastResources = serialized;
        fullCalendar.setOption('resources', resources);
    }

    // A swatch of the stylist's colour before their name in the column header.
    function paintColumnHeader(info) {
        $('<i/>', {class: 'legend-swatch', css: {backgroundColor: info.resource.eventBackgroundColor}}).prependTo(
            $(info.el).find('.fc-col-header-cell-cushion'),
        );
    }

    // The time grid runs from the first working stylist or appointment to the last.
    function fitHours(providers, appointmentEvents) {
        const hours = Events.visibleHours(
            providers,
            fullCalendar.view.currentStart,
            fullCalendar.view.currentEnd,
            appointmentEvents,
        );

        Object.entries(hours).forEach(([option, value]) => {
            if (fullCalendar.getOption(option) !== value) {
                fullCalendar.setOption(option, value);
            }
        });
    }

    function onSelect(info) {
        if (info.allDay) {
            return;
        }

        // In a stylist's column the new event is theirs.
        Events.newEventDialog(info, {
            providerId: info.resource?.id || focusProviderId() || undefined,
            serviceId: TickFilter.single('service-filter'),
        });

        fullCalendar.unselect();

        return false;
    }

    function onDateClick(info) {
        if (info.allDay) {
            fullCalendar.changeView(DAY_VIEW);
            fullCalendar.gotoDate(info.date);
        }
    }

    // The view last used in this browser, when it is one of the three offered.
    function savedView() {
        const view = window.localStorage.getItem(VIEW_KEY);
        return [DAY_VIEW, WEEK_VIEW, MONTH_VIEW].includes(view) ? view : null;
    }

    function saveView(view) {
        window.localStorage.setItem(VIEW_KEY, view.type);
    }

    function addEventListeners() {
        $reloadAppointments().on('click', reload);
        App.Utils.StatusFilter.onChange(draw);

        // The focus select changes only from the ticks below, which then redraw.
        $selectFilterItem().on('change', () => {
            const provider = Events.findProvider($selectFilterItem().val());

            if (provider?.timezone) {
                $('.provider-timezone').text(vars('timezones')[provider.timezone]);
            }

            $insertWorkingPlanException().toggle(isProviderFilter());
        });

        $('#provider-filter, #service-filter').on('tick-filter:change', () => {
            saveFilter();
            if (setFocus()) {
                $selectFilterItem().trigger('change');
            }
            draw();
        });

        $insertWorkingPlanException().on('click', () => {
            const provider = Events.findProvider($selectFilterItem().val());

            if (!provider) {
                return;
            }

            App.Components.WorkingPlanExceptionsModal.add().done((exception) => {
                Events.saveWorkingPlanException(provider, exception);
            });
        });
    }

    // The unticked ids are kept, so a stylist or service added later starts ticked.
    function saveFilter() {
        const saved = {providers: TickFilter.unticked('provider-filter'), services: TickFilter.unticked('service-filter')};
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
    }

    function restoreFilter() {
        let saved = null;
        try {
            saved = JSON.parse(window.localStorage.getItem(STORAGE_KEY));
        } catch {
            saved = null; // unreadable: start with everything ticked
        }
        if (!saved) {
            return;
        }

        TickFilter.untick('provider-filter', saved.providers || []);
        TickFilter.untick('service-filter', saved.services || []);
    }

    function initialize() {
        // The appointments page also has a #calendar; only the calendar page has the filter.
        if (!$calendar().length || !$selectFilterItem().length) {
            clearInterval(refreshTimer);
            return;
        }

        loadedRange = null;
        loadedView = null;
        lastResponse = null;
        lastResources = null;
        fullCalendar = new FullCalendar.Calendar(
            $calendar()[0],
            Events.calendarOptions({
                initialView: savedView() || (window.innerWidth < 468 ? DAY_VIEW : WEEK_VIEW),
                height: Events.calendarHeight(),
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: [DAY_VIEW, WEEK_VIEW, MONTH_VIEW].join(','),
                },
                // Day view: a column per stylist, scrolling sideways rather than
                // squashing; an appointment changes stylist by editing, not dragging.
                views: {[DAY_VIEW]: {buttonText: lang('day'), dayMinWidth: COLUMN_MIN_WIDTH}},
                resourceOrder: 'title',
                eventResourceEditable: false,
                resourceLabelDidMount: paintColumnHeader,
                windowResize: () => fullCalendar.setOption('height', Events.calendarHeight()),
                // Also fired, synchronously, when fitHours changes the slot
                // times (a new date profile), so only a changed range fetches and
                // only a changed view redraws: the view is noted before the draw,
                // or the nested call would add the events a second time.
                datesSet: (info) => {
                    saveView(info.view);
                    const viewChanged = info.view.type !== loadedView;
                    loadedView = info.view.type;
                    if (visibleDates(info.view).join('/') !== loadedRange) {
                        reload();
                    } else if (viewChanged) {
                        draw();
                    }
                    $(window).trigger('resize');
                },
                dateClick: onDateClick,
                select: onSelect,
            }),
        );

        $calendar().data('fullCalendar', fullCalendar);

        Events.configure(reload);
        addEventListeners();

        // The saved ticks are in place before the first render, whose datesSet
        // fetches once; the change event only sets the timezone and buttons.
        restoreFilter();
        setFocus();
        $selectFilterItem().trigger('change');
        fullCalendar.render();

        if (vars('edit_appointment')) {
            Events.openEventForm('appointments/' + vars('edit_appointment').id + '/edit');
            fullCalendar.gotoDate(moment(vars('edit_appointment').start_datetime).toDate());
        }

        clearInterval(refreshTimer);
        refreshTimer = setInterval(() => {
            // A fetch still running is left to finish rather than restarted.
            if (request || $('.popover').length) {
                return;
            }
            reload();
        }, 60000);
    }

    // A Drive visit away from the page: drop the fetch in flight, stop the timer
    // and destroy the calendar, so a late answer is never drawn into a page gone.
    function teardown() {
        if (request) {
            request.abort();
        }

        clearInterval(refreshTimer);

        if (fullCalendar) {
            fullCalendar.destroy();
            fullCalendar = null;
        }
    }

    App.page(initialize);
    document.addEventListener('turbo:before-cache', teardown);

    return {
        FILTER_TYPE_ALL,
    };
})();
