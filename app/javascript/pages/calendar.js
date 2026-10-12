/**
 * Calendar page: one FullCalendar showing a provider, a service or everything.
 */
App.Pages.Calendar = (function () {
    const FILTER_TYPE_ALL = 'all';
    const FILTER_TYPE_PROVIDER = 'provider';
    const FILTER_TYPE_SERVICE = 'service';

    const $calendar = () => $('#calendar');
    const $selectFilterItem = () => $('#select-filter-item');
    const $reloadAppointments = () => $('#reload-appointments');
    const $insertWorkingPlanException = () => $('#insert-working-plan-exception');

    const Events = App.Utils.CalendarEvents;
    const moment = window.moment;

    let fullCalendar = null;
    let refreshTimer = null;
    let request = null; // the events fetch in flight
    let loadedRange = null; // "start/end" dates of the last fetch, null before the first

    // Everyone's calendar colours appointments by provider; the legend names them.
    function renderLegend() {
        const $legend = $('#calendar-legend');
        const providers = filterType() === FILTER_TYPE_PROVIDER ? [] : vars('available_providers').filter((provider) => provider.color);
        $legend.empty().prop('hidden', providers.length === 0);
        providers.forEach((provider) => {
            $('<span/>')
                .append($('<i/>', {class: 'legend-swatch', css: {backgroundColor: provider.color}}))
                .append(document.createTextNode(provider.name))
                .appendTo($legend);
        });
    }

    function filterType() {
        return $selectFilterItem().find('option:selected').attr('type') || FILTER_TYPE_ALL;
    }

    function isProviderFilter() {
        return filterType() === FILTER_TYPE_PROVIDER;
    }

    function filterKey() {
        return filterType() + ':' + $selectFilterItem().val();
    }

    // The dates a view's fetch asks for.
    function visibleDates(view) {
        return [view.activeStart, view.activeEnd].map((date) => moment(date).format('YYYY-MM-DD'));
    }

    /**
     * Fetch the visible range and replace every event source. A fetch still in
     * flight is dropped first, so only the latest answer is drawn.
     */
    function reload() {
        Events.closePopover();

        // No calendar: another page, or torn down with a callback still to land.
        if (!fullCalendar || !$selectFilterItem().val()) {
            return;
        }

        const recordId = $selectFilterItem().val();
        const [startDate, endDate] = visibleDates(fullCalendar.view);

        if (request) {
            request.abort();
        }

        $('#loading').css('visibility', 'hidden');
        loadedRange = startDate + '/' + endDate;

        const current = App.Http.Calendar.getCalendarAppointments(recordId, startDate, endDate, filterType())
            .done((response) => {
                fullCalendar.getEventSources().forEach((source) => source.remove());
                renderLegend();

                const appointmentEvents = Events.appointmentEvents(
                    App.Utils.StatusFilter.apply(response.appointments),
                    filterType() === FILTER_TYPE_SERVICE ? 'provider' : 'service',
                    filterType() !== FILTER_TYPE_PROVIDER,
                );
                const events = [
                    ...appointmentEvents,
                    ...Events.unavailabilityEvents(response.unavailabilities),
                    ...Events.blockedPeriodEvents(response.blocked_periods),
                ];

                if (fullCalendar.view.type !== 'dayGridMonth') {
                    fitHours(recordId, appointmentEvents);
                    events.push(
                        ...Events.workingPlanEvents(
                            Events.findProvider(recordId),
                            fullCalendar.view.currentStart,
                            fullCalendar.view.currentEnd,
                        ),
                    );
                }

                fullCalendar.addEventSource(events);
            })
            .always(() => {
                if (request === current) {
                    request = null;
                    $('#loading').css('visibility', '');
                }
            });
        request = current;
    }

    // The time grid runs from the first working stylist or appointment to the
    // last: the chosen stylist, the stylists offering the chosen service, or all.
    function fitHours(recordId, appointmentEvents) {
        let providers = vars('available_providers');
        if (isProviderFilter()) {
            providers = [Events.findProvider(recordId)].filter(Boolean);
        } else if (filterType() === FILTER_TYPE_SERVICE) {
            providers = providers.filter((provider) => (provider.services || []).map(Number).includes(Number(recordId)));
        }

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
            providerId: isProviderFilter() ? $selectFilterItem().val() : undefined,
            serviceId: filterType() === FILTER_TYPE_SERVICE ? $selectFilterItem().val() : undefined,
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
        App.Utils.StatusFilter.onChange(reload);

        $selectFilterItem().on('change', () => {
            const provider = Events.findProvider($selectFilterItem().val());

            if (provider?.timezone) {
                $('.provider-timezone').text(vars('timezones')[provider.timezone]);
            }

            $insertWorkingPlanException().toggle(isProviderFilter());
            window.localStorage.setItem('EasyAppointments.SelectFilterItem', filterKey());

            // Before the first render's datesSet there is nothing to fetch yet:
            // it loads the restored filter itself.
            if (loadedRange) {
                reload();
            }
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

    // The last choice is kept as "type:id" (a provider and a service can share
    // an id); a bare id is matched by value alone.
    function restoreFilter() {
        const saved = window.localStorage.getItem('EasyAppointments.SelectFilterItem');
        if (!saved) {
            return;
        }

        const [type, value] = saved.includes(':') ? saved.split(':') : [null, saved];
        const typeRule = type === FILTER_TYPE_ALL ? ':not([type])' : type ? '[type="' + type + '"]' : '';
        const $option = $selectFilterItem().find('option[value="' + value + '"]' + typeRule).first();

        if ($option.length) {
            $option.prop('selected', true);
        }
    }

    function initialize() {
        // The appointments page also has a #calendar; only the calendar page has the filter.
        if (!$calendar().length || !$selectFilterItem().length) {
            clearInterval(refreshTimer);
            return;
        }

        loadedRange = null;
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

        // The saved filter is in place before the first render, whose datesSet
        // fetches it once; the change event only sets the dropdown, timezone and button.
        restoreFilter();
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
        FILTER_TYPE_PROVIDER,
        FILTER_TYPE_SERVICE,
    };
})();
