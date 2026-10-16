/**
 * Calendar page: one FullCalendar showing everyone's events for the visible
 * range, filtered in the browser by the ticked stylists, services and statuses,
 * so ticking a box redraws without a fetch.
 */
App.Pages.Calendar = (function () {
    const FILTER_TYPE_ALL = 'all';
    const STORAGE_KEY = 'OpenAppointments.CalendarFilter';

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
    let lastResponse = null; // the last fetch's events, redrawn when a box is ticked

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

    // With several stylists shown the legend names the ticked ones by their fill colour.
    function renderLegend() {
        const $legend = $('#calendar-legend');
        const ticked = tickedProviders();
        const providers = isProviderFilter()
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

        fullCalendar.getEventSources().forEach((source) => source.remove());
        renderLegend();

        // Filled with the stylist colour, edged with the service colour. Several
        // stylists are titled by stylist when only one service is ticked.
        const appointmentEvents = Events.appointmentEvents(
            appointments,
            !focus && services.length === 1 ? 'provider' : 'service',
        );
        const events = [
            ...appointmentEvents,
            ...Events.unavailabilityEvents(lastResponse.unavailabilities.filter((event) => shown(event.id_users_provider))),
            ...Events.blockedPeriodEvents(lastResponse.blocked_periods),
        ];

        if (fullCalendar.view.type !== 'dayGridMonth') {
            fitHours(providers, services, appointmentEvents);
            events.push(
                ...Events.workingPlanEvents(
                    Events.findProvider(focus),
                    fullCalendar.view.currentStart,
                    fullCalendar.view.currentEnd,
                ),
            );
        }

        fullCalendar.addEventSource(events);
    }

    // The time grid runs from the first working stylist or appointment to the
    // last, over the ticked stylists who offer a ticked service.
    function fitHours(tickedIds, serviceIds, appointmentEvents) {
        const providers = vars('available_providers').filter(
            (provider) =>
                (!tickedIds || tickedIds.includes(Number(provider.id))) &&
                (provider.services || []).map(Number).some((id) => serviceIds.includes(id)),
        );

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

        Events.newEventDialog(info, {
            providerId: focusProviderId() || undefined,
            serviceId: TickFilter.single('service-filter'),
        });

        fullCalendar.unselect();

        return false;
    }

    function onDateClick(info) {
        if (info.allDay) {
            fullCalendar.changeView('timeGridDay');
            fullCalendar.gotoDate(info.date);
        }
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
        lastResponse = null;
        fullCalendar = new FullCalendar.Calendar(
            $calendar()[0],
            Events.calendarOptions({
                initialView: window.innerWidth < 468 ? 'timeGridDay' : 'timeGridWeek',
                height: Events.calendarHeight(),
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'timeGridDay,timeGridWeek,dayGridMonth',
                },
                windowResize: () => fullCalendar.setOption('height', Events.calendarHeight()),
                // Also fired when fitHours changes the slot times (a new date
                // profile), so only a changed range fetches.
                datesSet: (info) => {
                    if (visibleDates(info.view).join('/') !== loadedRange) {
                        reload();
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
            if (request || $('.popover').length || App.Utils.CalendarSync.isCurrentlySyncing()) {
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
