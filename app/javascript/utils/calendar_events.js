/**
 * Calendar events utility.
 *
 * Everything the calendar and appointments pages share: FullCalendar options,
 * event builders (appointments, unavailabilities, blocked periods, working plans),
 * popovers, drag/resize/delete handlers and the edit modals.
 */
App.Utils.CalendarEvents = (function () {
    const COLORS = {
        unavailability: '#879DB4',
        blockedPeriod: '#d65069',
        notWorking: '#BEBEBE',
        free: '#9fd69f',
        default: '#7cbae8',
    };

    const DATETIME = 'YYYY-MM-DD HH:mm:ss';

    const $calendarPage = () => $('#calendar-page');
    const $notification = () => $('#notification');
    const $unavailabilitiesModal = () => $('#unavailabilities-modal');

    const moment = window.moment;

    let $popoverTarget = null;
    let lastFocusedEvent = null;
    let reload = () => {};

    // Helpers

    function findProvider(providerId) {
        return vars('available_providers').find((provider) => Number(provider.id) === Number(providerId));
    }

    function findService(serviceId) {
        return vars('available_services').find((service) => Number(service.id) === Number(serviceId));
    }

    function isUnavailability(eventData) {
        return Boolean(Number(eventData?.is_unavailability));
    }

    function isWorkingPlanException(eventData) {
        return eventData?.workingPlanException !== undefined;
    }

    function canEdit() {
        return Boolean(vars('privileges').appointments.edit);
    }

    function canDelete() {
        return Boolean(vars('privileges').appointments.delete);
    }

    /**
     * Page height left for the calendar after the header, footer and toolbar.
     *
     * @param {number} [extraOffset]
     * @returns {number}
     */
    function calendarHeight(extraOffset = 35) {
        const offset =
            $('#footer').outerHeight() + $('#header').outerHeight() + $('#calendar-toolbar').outerHeight() + extraOffset;

        return Math.max(window.innerHeight - offset, 700);
    }

    /**
     * FullCalendar options common to every calendar instance.
     *
     * @param {Object} overrides
     * @returns {Object}
     */
    function calendarOptions(overrides = {}) {
        let timeFormat, slotTimeFormat;

        switch (vars('time_format')) {
            case 'military':
                timeFormat = 'HH:mm';
                slotTimeFormat = 'HH:mm';
                break;
            case 'regular':
                timeFormat = 'h:mm a';
                slotTimeFormat = 'h a';
                break;
            default:
                throw new Error('Invalid time format setting: ' + vars('time_format'));
        }

        return {
            locale: vars('language_code'),
            nowIndicator: true,
            editable: true,
            firstDay: App.Utils.Date.getWeekdayId(vars('first_weekday')),
            slotDuration: '00:15:00',
            snapDuration: '00:15:00',
            scrollTime: '07:00:00',
            slotLabelInterval: '01:00',
            eventTimeFormat: timeFormat,
            eventTextColor: '#333',
            eventColor: COLORS.default,
            slotLabelFormat: slotTimeFormat,
            allDayContent: lang('all_day'),
            dayHeaderFormat: vars('date_format') === 'DMY' ? 'ddd D/M' : 'ddd M/D',
            selectable: true,
            selectMirror: true,
            themeSystem: 'standard',
            selectLongPressDelay: 100,
            buttonText: {
                today: lang('today'),
                day: lang('day'),
                week: lang('week'),
                month: lang('month'),
            },
            eventClick: onEventClick,
            eventResize: onEventResize,
            eventDrop: onEventDrop,
            ...overrides,
        };
    }

    /**
     * Register the page's reload function, called after every change.
     *
     * @param {Function} reloadFunction
     */
    function configure(reloadFunction) {
        reload = reloadFunction;
        $calendarPage().on('click', '.close-popover', closePopover);
        $calendarPage().on('click', '.edit-popover', onEditPopoverClick);
        $calendarPage().on('click', '.delete-popover', onDeletePopoverClick);
        $calendarPage().on('click', '.cancel-popover', onCancelPopoverClick);
    }

    /**
     * Save an exception, update the provider's in-memory exceptions and reload.
     *
     * @param {Object} provider
     * @param {Object} exception
     */
    function saveWorkingPlanException(provider, exception) {
        App.Http.Calendar.saveWorkingPlanException(
            exception,
            provider.id,
            (response) => {
                App.Layouts.Backend.displayNotification(lang('working_plan_exception_saved'));

                let exceptions = JSON.parse(provider.settings.working_plan_exceptions || '[]');
                if (!Array.isArray(exceptions)) {
                    exceptions = [];
                }
                const index = exceptions.findIndex((e) => e.id === exception.id);
                if (index >= 0) {
                    exceptions[index] = exception;
                } else {
                    if (response?.id) {
                        exception.id = response.id;
                    }
                    exceptions.push(exception);
                }
                provider.settings.working_plan_exceptions = JSON.stringify(exceptions);

                reload();
            },
            null,
        );
    }

    function deleteWorkingPlanException(provider, exception) {
        if (!exception?.id) {
            App.Layouts.Backend.displayNotification(lang('working_plan_exception_deleted'));
            reload();
            return;
        }

        App.Http.Calendar.deleteWorkingPlanException(exception.id, provider.id, () => {
            App.Layouts.Backend.displayNotification(lang('working_plan_exception_deleted'));

            let exceptions = JSON.parse(provider.settings.working_plan_exceptions || '[]');
            if (Array.isArray(exceptions)) {
                exceptions = exceptions.filter((e) => e.id !== exception.id);
                provider.settings.working_plan_exceptions = JSON.stringify(exceptions);
            }

            reload();
        });
    }

    // Popover

    // The event popover is a tippy with the built content; .popover marks it for the page scripts.
    function closePopover() {
        if ($popoverTarget) {
            $popoverTarget[0]._tippy?.destroy();
            $popoverTarget = null;
        }
        $('.popover').remove();
    }

    // Event dialog: forms load into the event frame (components/event_modal.js shows it).

    function openEventForm(url) {
        App.Components.EventModal.open(url);
    }

    function query(params) {
        return new URLSearchParams(
            Object.entries(params).filter(([, value]) => value !== undefined && value !== null && value !== ''),
        ).toString();
    }

    function newEventDialog(info, preselect) {
        const start = moment(info.start).format(DATETIME);
        const buttons = [
            {
                text: lang('unavailability'),
                click: (event, messageModal) => {
                    openEventForm('unavailabilities/new?' + query({
                        start,
                        end: moment(info.end).format(DATETIME),
                        provider_id: preselect.providerId,
                    }));
                    messageModal.hide();
                },
            },
            {
                text: lang('appointment'),
                click: (event, messageModal) => {
                    openEventForm('appointments/new?' + query({
                        start,
                        end: selectionEndDate(info, preselect.serviceId),
                        provider_id: preselect.providerId,
                        service_id: preselect.serviceId,
                    }));
                    messageModal.hide();
                },
            },
        ];

        App.Utils.Message.show(lang('add_new_event'), lang('what_kind_of_event'), buttons);
        $('#message-modal footer').addClass('spread');
    }

    function newAppointmentAt(providerId, start) {
        openEventForm('appointments/new?' + query({start: moment(start).format(DATETIME), provider_id: providerId}));
    }

    // A click-sized selection gets the service's duration (or an hour); the server adds it when end is empty.
    function selectionEndDate(info, serviceId) {
        const minutes = moment(info.end).diff(moment(info.start), 'minutes');

        if (minutes > 15) {
            return moment(info.end).format(DATETIME);
        }

        const service = findService(serviceId);
        return moment(info.start).add(service ? service.duration : 60, 'minutes').format(DATETIME);
    }

    function removeAppointmentDialog(appointmentId, action) {
        openEventForm('appointments/' + appointmentId + '/remove?kind=' + action);
    }

    function onEventClick(info) {
        const $target = $(info.el);
        closePopover();

        const Popover = App.Utils.CalendarEventPopover;
        const isCustom = $target.hasClass('fc-custom');
        let $html;

        if ($target.hasClass('fc-free')) {
            newAppointmentAt(info.event.extendedProps.data.providerId, info.event.start);
            return;
        }

        if ($target.hasClass('fc-blocked-period')) {
            $html = Popover.buildBlockedPeriodPopover(info);
        } else {
            const generated = $target.hasClass('fc-unavailability') || $target.hasClass('fc-working-plan-exception');
            const editable = generated ? isCustom : true;
            const displayEdit = editable && canEdit() ? '' : 'is-hidden';
            const displayDelete = editable && canDelete() ? '' : 'is-hidden';

            if ($target.hasClass('fc-working-plan-exception')) {
                $html = Popover.buildWorkingPlanExceptionPopover(info, displayEdit, displayDelete);
            } else if ($target.hasClass('fc-unavailability')) {
                $html = Popover.buildUnavailabilityPopover(info, displayEdit, displayDelete);
            } else {
                $html = Popover.buildAppointmentPopover(info, displayEdit, displayDelete);
            }
        }

        const $popover = $('<div/>', {class: 'popover'})
            .append($('<h3/>', {class: 'popover-title', text: info.event.title}))
            .append($('<div/>', {class: 'popover-body'}).append($html));

        lastFocusedEvent = info.event;
        $popoverTarget = $target;
        tippy($target[0], {
            content: $popover[0],
            allowHTML: true,
            interactive: true,
            trigger: 'manual',
            placement: 'top',
            arrow: false,
            theme: 'event',
            maxWidth: 'none',
            appendTo: document.getElementById('calendar-page') || document.body,
            onHidden: (instance) => instance.destroy(),
        }).show();
    }

    function onEditPopoverClick() {
        closePopover();

        const data = lastFocusedEvent.extendedProps.data;

        if (isWorkingPlanException(data)) {
            App.Components.WorkingPlanExceptionsModal.edit(data.workingPlanException).done((updated) => {
                saveWorkingPlanException(data.provider, updated);
            });
        } else if (isUnavailability(data)) {
            openEventForm('unavailabilities/' + data.id + '/edit');
        } else {
            openEventForm('appointments/' + data.id + '/edit');
        }
    }

    function onDeletePopoverClick() {
        closePopover();

        const data = lastFocusedEvent.extendedProps.data;

        if (isWorkingPlanException(data)) {
            deleteWorkingPlanException(data.provider, data.workingPlanException);
        } else if (isUnavailability(data)) {
            App.Http.Calendar.deleteUnavailability(data.id).done(reload);
        } else {
            removeAppointmentDialog(data.id, 'delete');
        }
    }

    function onCancelPopoverClick() {
        closePopover();
        removeAppointmentDialog(lastFocusedEvent.extendedProps.data.id, 'cancel');
    }

    // Drag and resize

    function guardEdit(info) {
        if (!canEdit()) {
            info.revert();
            App.Layouts.Backend.displayNotification(lang('no_privileges_edit_appointments'));
            return false;
        }

        if ($notification().is(':visible')) {
            $notification().hide('bind');
        }

        return true;
    }

    function onEventResize(info) {
        if (!guardEdit(info)) {
            return;
        }

        const eventData = info.event.extendedProps.data;
        const delta = {days: info.endDelta.days, milliseconds: info.endDelta.milliseconds};

        if (isUnavailability(eventData)) {
            saveMovedUnavailability(info, eventData, {end: delta});
        } else {
            saveMovedAppointment(info, eventData, {end: delta});
        }
    }

    function onEventDrop(info) {
        if (!guardEdit(info)) {
            return;
        }

        const eventData = info.event.extendedProps.data;
        const delta = {days: info.delta.days, milliseconds: info.delta.milliseconds};

        if (isUnavailability(eventData)) {
            saveMovedUnavailability(info, eventData, {start: delta, end: delta});
        } else {
            saveMovedAppointment(info, eventData, {start: delta, end: delta});
        }
    }

    function negate(delta) {
        return {days: -delta.days, milliseconds: -delta.milliseconds};
    }

    function shift(datetime, delta) {
        return moment(datetime).add(delta).format(DATETIME);
    }

    /**
     * Persist a dragged or resized appointment, asking whether to notify, with undo.
     *
     * @param {Object} info FullCalendar drop/resize info.
     * @param {Object} eventData
     * @param {Object} deltas {start?, end?} moment durations applied to the stored times.
     */
    function saveMovedAppointment(info, eventData, deltas) {
        const apply = (target, sign) => {
            if (deltas.start) {
                target.start_datetime = shift(target.start_datetime, sign(deltas.start));
            }
            if (deltas.end) {
                target.end_datetime = shift(target.end_datetime, sign(deltas.end));
            }
        };

        apply(eventData, (d) => d);

        const appointment = {...eventData, is_unavailability: 0};
        delete appointment.customer;
        delete appointment.provider;
        delete appointment.service;

        const saved = (notifyUsers) => {
            App.Layouts.Backend.displayNotification(lang('appointment_updated'), [
                {
                    label: lang('undo'),
                    function: () => {
                        apply(appointment, negate);
                        apply(eventData, negate);
                        App.Http.Calendar.saveAppointment(appointment, null, null, null, notifyUsers).done(() =>
                            $notification().hide('blind'),
                        );
                        info.revert();
                    },
                },
            ]);
            info.event.setProp('data', eventData);
        };

        App.Utils.Message.show(lang('appointment_update'), lang('notify_users_on_update_question'), [
            {
                text: lang('no'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    App.Http.Calendar.saveAppointmentWithConflictHandling(
                        appointment,
                        null,
                        () => saved(false),
                        null,
                        false,
                        () => info.revert(),
                    );
                },
            },
            {
                text: lang('yes'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    App.Http.Calendar.saveAppointmentWithConflictHandling(
                        appointment,
                        null,
                        () => saved(true),
                        null,
                        true,
                        () => info.revert(),
                    );
                },
            },
        ]);
    }

    function saveMovedUnavailability(info, eventData, deltas) {
        const unavailability = {
            id: eventData.id,
            start_datetime: moment(info.event.start).format(DATETIME),
            end_datetime: moment(info.event.end).format(DATETIME),
            id_users_provider: eventData.id_users_provider,
        };

        eventData.start_datetime = unavailability.start_datetime;
        eventData.end_datetime = unavailability.end_datetime;

        App.Http.Calendar.saveUnavailability(unavailability, () => {
            App.Layouts.Backend.displayNotification(lang('unavailability_updated'), [
                {
                    label: lang('undo'),
                    function: () => {
                        if (deltas.start) {
                            unavailability.start_datetime = shift(unavailability.start_datetime, negate(deltas.start));
                        }
                        unavailability.end_datetime = shift(unavailability.end_datetime, negate(deltas.end));
                        eventData.start_datetime = unavailability.start_datetime;
                        eventData.end_datetime = unavailability.end_datetime;
                        App.Http.Calendar.saveUnavailability(unavailability).done(() => $notification().hide('blind'));
                        info.revert();
                    },
                },
            ]);
            info.event.setProp('data', eventData);
        });
    }

    // Event builders

    /**
     * @param {Array} appointments
     * @param {string} titleBy 'service' or 'provider', shown after the customer name.
     * @param {boolean} byProvider colour by the provider (everyone's calendar) instead of the appointment.
     * @returns {Array}
     */
    function appointmentEvents(appointments, titleBy = 'service', byProvider = false) {
        return appointments.map((appointment) => {
            const detail = titleBy === 'provider' ? appointment.provider.name : appointment.service.name;
            const title = appointment.customer.name ? appointment.customer.name + ' - ' + detail : detail;
            const color = (byProvider && appointment.provider.color) || appointment.color || COLORS.default;

            return {
                id: appointment.id,
                title,
                start: moment(appointment.start_datetime).toDate(),
                end: moment(appointment.end_datetime).toDate(),
                allDay: false,
                ...eventColors(color),
                data: appointment,
                display: 'block',
                className: appointment.frees_slot ? 'fc-freed-slot' : '',
            };
        });
    }

    // A solid colour on the left edge over a light tint keeps dark text readable.
    function eventColors(color) {
        return {
            backgroundColor: tint(color),
            borderColor: color,
            textColor: '#212529',
        };
    }

    function tint(color) {
        const hex = color.replace('#', '');
        if (hex.length !== 6) {
            return color;
        }
        const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.substr(i, 2), 16));
        return `rgba(${r}, ${g}, ${b}, 0.28)`;
    }

    function unavailabilityEvents(unavailabilities) {
        return unavailabilities.map((unavailability) => {
            let notes = unavailability.notes ? ' - ' + unavailability.notes : '';
            if (notes.length > 33) {
                notes = ' - ' + unavailability.notes.substring(0, 30) + '...';
            }

            return {
                title: lang('unavailability') + notes,
                start: moment(unavailability.start_datetime).toDate(),
                end: moment(unavailability.end_datetime).toDate(),
                allDay: false,
                color: COLORS.unavailability,
                editable: true,
                className: 'fc-unavailability fc-custom',
                data: unavailability,
                display: 'block',
            };
        });
    }

    function blockedPeriodEvents(blockedPeriods) {
        return (blockedPeriods || []).map((blockedPeriod) => ({
            title: blockedPeriod.name,
            start: moment(blockedPeriod.start_datetime).toDate(),
            end: moment(blockedPeriod.end_datetime).toDate(),
            allDay: true,
            backgroundColor: COLORS.blockedPeriod,
            borderColor: COLORS.blockedPeriod,
            textColor: '#ffffff',
            editable: false,
            className: 'fc-blocked-period fc-unavailability',
            data: blockedPeriod,
            display: 'block',
        }));
    }

    function backgroundEvent(title, start, end, className = 'fc-unavailability') {
        return {
            title,
            start,
            end,
            allDay: false,
            color: COLORS.notWorking,
            editable: false,
            display: 'background',
            className,
        };
    }

    /**
     * Non-working time, breaks and working plan exceptions for a provider between two dates.
     *
     * @param {Object|undefined} provider Falls back to the company working plan.
     * @param {Date} rangeStart
     * @param {Date} rangeEnd Exclusive.
     * @returns {Array}
     */
    /**
     * The working plan for one day: the exception covering it if any, else the weekly plan.
     * Exceptions arrive ordered by start date then id and the last covering one wins, matching
     * WorkingPlanException.expanded_for, so a working day inside a week off is shown as working.
     *
     * @param {Object|undefined} provider Falls back to the company working plan.
     * @param {moment.Moment} date
     * @returns {Object} {dayPlan: {start, end, breaks} or null when not working, exception}
     */
    function dayPlanFor(provider, date) {
        const workingPlan = JSON.parse(provider?.settings?.working_plan || vars('company_working_plan'));
        const exceptions = JSON.parse(provider?.settings?.working_plan_exceptions || '[]');
        const exception = Array.isArray(exceptions)
            ? exceptions.findLast((e) => date.isBetween(e.startDate, e.endDate, 'day', '[]'))
            : undefined;

        if (exception) {
            // A non-working exception has no times; treat the day as non-working.
            const dayPlan = exception.startTime
                ? {start: exception.startTime, end: exception.endTime, breaks: exception.breaks || []}
                : null;
            return {dayPlan, exception};
        }

        return {dayPlan: workingPlan[date.format('dddd').toLowerCase()] || null, exception};
    }

    function at(date, time) {
        return moment(date.format('YYYY-MM-DD') + ' ' + time, 'YYYY-MM-DD HH:mm').toDate();
    }

    /**
     * Working hours minus breaks for one day, as [{start, end}] Date pairs.
     *
     * @param {Object|undefined} provider
     * @param {Date} day
     * @returns {Array}
     */
    function workingIntervals(provider, day) {
        const date = moment(day).startOf('day');
        const {dayPlan} = dayPlanFor(provider, date);

        if (!dayPlan) {
            return [];
        }

        const intervals = [];
        let cursor = at(date, dayPlan.start);
        const end = at(date, dayPlan.end);

        (dayPlan.breaks || [])
            .map((b) => ({start: at(date, b.start), end: at(date, b.end)}))
            .sort((a, b) => a.start - b.start)
            .forEach((b) => {
                if (b.start > cursor) {
                    intervals.push({start: cursor, end: b.start});
                }
                cursor = b.end > cursor ? b.end : cursor;
            });

        if (end > cursor) {
            intervals.push({start: cursor, end});
        }

        return intervals;
    }

    /**
     * Working time not covered by any busy interval, as "free" list entries.
     *
     * @param {Object} provider
     * @param {Date} day
     * @param {Array} busy [{start, end}] Date pairs.
     * @returns {Array}
     */
    function freeSlotEvents(provider, day, busy) {
        const MIN_MINUTES = 15;
        const sortedBusy = busy.slice().sort((a, b) => a.start - b.start);
        const events = [];

        workingIntervals(provider, day).forEach((interval) => {
            let cursor = interval.start;

            sortedBusy.forEach((b) => {
                if (b.end <= cursor || b.start >= interval.end) {
                    return;
                }
                if (b.start > cursor) {
                    events.push({start: cursor, end: b.start});
                }
                cursor = b.end > cursor ? b.end : cursor;
            });

            if (interval.end > cursor) {
                events.push({start: cursor, end: interval.end});
            }
        });

        return events
            .filter((gap) => moment(gap.end).diff(gap.start, 'minutes') >= MIN_MINUTES)
            .map((gap) => ({
                title: lang('free_for_appointments'),
                start: gap.start,
                end: gap.end,
                allDay: false,
                color: COLORS.free,
                editable: false,
                className: 'fc-free',
                display: 'block',
                extendedProps: {data: {providerId: provider.id}},
            }));
    }

    function workingPlanEvents(provider, rangeStart, rangeEnd) {
        const events = [];
        const date = moment(rangeStart).startOf('day');

        while (date.toDate() < rangeEnd) {
            const dateStr = date.format('YYYY-MM-DD');
            const dayStart = date.clone().toDate();
            const dayEnd = date.clone().add(1, 'day').toDate();
            const {dayPlan, exception} = dayPlanFor(provider, date);

            if (exception) {
                events.push({
                    title: lang('working_plan_exception'),
                    start: moment(dateStr + ' ' + (exception.startTime || '00:00'), 'YYYY-MM-DD HH:mm').toDate(),
                    end: moment(dateStr + ' ' + (exception.endTime || '00:00'), 'YYYY-MM-DD HH:mm')
                        .add(1, 'day')
                        .toDate(),
                    allDay: true,
                    color: COLORS.unavailability,
                    editable: false,
                    className: 'fc-working-plan-exception fc-custom',
                    display: 'block',
                    extendedProps: {data: {workingPlanException: exception, provider}},
                });
            }

            if (!dayPlan) {
                events.push(backgroundEvent(lang('not_working'), dayStart, dayEnd));
                date.add(1, 'day');
                continue;
            }

            const workStart = at(date, dayPlan.start);
            const workEnd = at(date, dayPlan.end);

            if (dayStart < workStart) {
                events.push(backgroundEvent(lang('not_working'), dayStart, workStart));
            }
            if (workEnd < dayEnd) {
                events.push(backgroundEvent(lang('not_working'), workEnd, dayEnd));
            }
            (dayPlan.breaks || []).forEach((breakPeriod) => {
                events.push(
                    backgroundEvent(
                        lang('break'),
                        at(date, breakPeriod.start),
                        at(date, breakPeriod.end),
                        'fc-unavailability fc-break',
                    ),
                );
            });

            date.add(1, 'day');
        }

        return events;
    }

    return {
        configure,
        calendarOptions,
        calendarHeight,
        findProvider,
        findService,
        closePopover,
        openEventForm,
        newEventDialog,
        saveWorkingPlanException,
        appointmentEvents,
        unavailabilityEvents,
        blockedPeriodEvents,
        workingPlanEvents,
        workingIntervals,
        freeSlotEvents,
    };
})();
