/**
 * Calendar page: one FullCalendar showing a provider, a service or everything.
 */
App.Pages.Calendar = (function () {
    const FILTER_TYPE_ALL = 'all';
    const FILTER_TYPE_PROVIDER = 'provider';
    const FILTER_TYPE_SERVICE = 'service';

    const $calendar = $('#calendar');
    const $selectFilterItem = $('#select-filter-item');
    const $reloadAppointments = $('#reload-appointments');
    const $insertWorkingPlanException = $('#insert-working-plan-exception');

    const Events = App.Utils.CalendarEvents;
    const moment = window.moment;

    let fullCalendar = null;

    function filterType() {
        return $selectFilterItem.find('option:selected').attr('type') || FILTER_TYPE_ALL;
    }

    function isProviderFilter() {
        return filterType() === FILTER_TYPE_PROVIDER;
    }

    /**
     * Fetch the visible range and replace every event source.
     */
    function reload() {
        Events.closePopover();

        if (!$selectFilterItem.val()) {
            return;
        }

        const recordId = $selectFilterItem.val();
        const startDate = moment(fullCalendar.view.activeStart).format('YYYY-MM-DD');
        const endDate = moment(fullCalendar.view.activeEnd).format('YYYY-MM-DD');

        $('#loading').css('visibility', 'hidden');

        App.Http.Calendar.getCalendarAppointments(recordId, startDate, endDate, filterType())
            .done((response) => {
                fullCalendar.getEventSources().forEach((source) => source.remove());

                const events = [
                    ...Events.appointmentEvents(
                        response.appointments,
                        filterType() === FILTER_TYPE_SERVICE ? 'provider' : 'service',
                    ),
                    ...Events.unavailabilityEvents(response.unavailabilities),
                    ...Events.blockedPeriodEvents(response.blocked_periods),
                ];

                if (fullCalendar.view.type !== 'dayGridMonth') {
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
            .always(() => $('#loading').css('visibility', ''));
    }

    function onSelect(info) {
        if (info.allDay) {
            return;
        }

        Events.newEventDialog(info, {
            providerId: isProviderFilter() ? $selectFilterItem.val() : undefined,
            serviceId: filterType() === FILTER_TYPE_SERVICE ? $selectFilterItem.val() : undefined,
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
        $reloadAppointments.on('click', reload);

        $selectFilterItem.on('change', () => {
            const provider = Events.findProvider($selectFilterItem.val());

            if (provider?.timezone) {
                $('.provider-timezone').text(vars('timezones')[provider.timezone]);
            }

            $insertWorkingPlanException.toggle(isProviderFilter());
            reload();
            window.localStorage.setItem('EasyAppointments.SelectFilterItem', $selectFilterItem.val());
        });

        $insertWorkingPlanException.on('click', () => {
            const provider = Events.findProvider($selectFilterItem.val());

            if (!provider) {
                return;
            }

            App.Components.WorkingPlanExceptionsModal.add().done((exception) => {
                Events.saveWorkingPlanException(provider, exception);
            });
        });
    }

    function initialize() {
        fullCalendar = new FullCalendar.Calendar(
            $calendar[0],
            Events.calendarOptions({
                initialView: window.innerWidth < 468 ? 'timeGridDay' : 'timeGridWeek',
                height: Events.calendarHeight(),
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'timeGridDay,timeGridWeek,dayGridMonth',
                },
                windowResize: () => fullCalendar.setOption('height', Events.calendarHeight()),
                datesSet: () => {
                    reload();
                    $(window).trigger('resize');
                },
                dateClick: onDateClick,
                select: onSelect,
            }),
        );

        fullCalendar.render();
        $calendar.data('fullCalendar', fullCalendar);

        Events.configure(reload);
        addEventListeners();

        const savedFilter = window.localStorage.getItem('EasyAppointments.SelectFilterItem');
        if (savedFilter && $selectFilterItem.find('option[value="' + savedFilter + '"]').length) {
            $selectFilterItem.val(savedFilter);
        }
        $selectFilterItem.trigger('change');

        if (vars('edit_appointment')) {
            Events.populateAppointmentModal(vars('edit_appointment'));
            fullCalendar.gotoDate(moment(vars('edit_appointment').start_datetime).toDate());
        }

        setInterval(() => {
            if ($('.popover').length || App.Utils.CalendarSync.isCurrentlySyncing()) {
                return;
            }
            reload();
        }, 60000);
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {
        FILTER_TYPE_ALL,
        FILTER_TYPE_PROVIDER,
        FILTER_TYPE_SERVICE,
    };
})();
