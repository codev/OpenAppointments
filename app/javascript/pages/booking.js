/**
 * Public booking wizard. The steps are server rendered into the wizard frame;
 * this script handles what stays client side: the calendar and hour buttons
 * (the whole window's hours arrive with the time step, so switching days needs
 * no request), the timezone labels, card selection, live descriptions, the
 * remembered details and the captcha.
 */
App.Pages.Booking = (function () {
    function timeStepFrame() {
        return $('#time-step-form').closest('.wizard-frame');
    }

    // Hours are provider wall-clock keys; labels show them in the chosen zone.
    function renderHours($frame, date, keepSelection) {
        const windowHours = $frame.data('window') || {};
        const timeFormat = $frame.data('timeFormat') === 'military' ? 'HH:mm' : 'h:mm a';
        const providerTimezone = $frame.data('providerTimezone');
        const timezone = $('#select-timezone').val() || providerTimezone;
        const selected = keepSelection ? $('#selected-time').val() : '';
        const $hours = $('#available-hours').empty();
        const hours = windowHours[date] || [];

        $('#selected-date').val(date);
        $('#selected-time').val('');

        if (!hours.length) {
            $('<em/>', {text: lang('no_available_hours')}).appendTo($hours);
            return;
        }

        hours.forEach((hour) => {
            const moment_ = moment.tz(date + ' ' + hour, providerTimezone).tz(timezone);
            if (moment_.format('YYYY-MM-DD') !== date) {
                return; // In the chosen zone this hour belongs to another day.
            }
            $('<button/>', {
                'type': 'button',
                'class': 'btn btn-outline-secondary w-100 shadow-none available-hour my-1',
                'data-value': hour,
                'text': moment_.format(timeFormat),
            }).appendTo($hours);
        });

        if (selected && hours.includes(selected)) {
            selectHour(selected);
        }
    }

    function selectHour(hour) {
        $('#select-hour-prompt').remove();
        $('.available-hour').removeClass('selected-hour btn-primary').addClass('btn-outline-secondary');
        $('.available-hour[data-value="' + hour + '"]').addClass('selected-hour btn-primary').removeClass('btn-outline-secondary');
        $('#selected-time').val(hour);
    }

    // The chosen zone, else the browser's, else the provider's.
    function initializeTimezone($frame) {
        const $select = $('#select-timezone');
        const wanted = $frame.data('selectedTimezone') || Intl.DateTimeFormat().resolvedOptions().timeZone;
        const supported = $select.find('option[value="' + wanted + '"]').length > 0;
        $select.val(supported ? wanted : $frame.data('providerTimezone'));
    }

    function initializeTimeStep() {
        const $frame = timeStepFrame();

        if (!$frame.length) {
            return;
        }

        initializeTimezone($frame);

        const windowHours = $frame.data('window') || {};
        const enabled = Object.keys(windowHours);
        const initial = $frame.data('selectedDate') || enabled[0];

        flatpickr('#select-date', {
            inline: true,
            static: true,
            enable: enabled.length ? enabled : [() => false],
            defaultDate: initial,
            locale: App.Utils.UI.getFlatpickrLocale(),
            onChange: (dates, dateStr) => renderHours($frame, dateStr, false),
        });

        if (initial) {
            renderHours($frame, initial, true);
        }
    }

    const STORED_FIELDS = ['name', 'email', 'phone-number', 'address', 'city', 'zip-code'];

    function initializeInfoStep() {
        if (!$('#info-step-form').length) {
            return;
        }

        let stored;
        try {
            stored = JSON.parse(window.localStorage.getItem('OpenAppointments.Customer') || 'null');
        } catch (error) {
            stored = null;
        }

        if (stored) {
            $('#remember-me').prop('checked', true);
            STORED_FIELDS.forEach((id) => {
                const $field = $('#' + id);
                if ($field.length && !$field.val()) {
                    $field.val(stored[id] || '');
                }
            });
        }
    }

    function rememberCustomer() {
        if (!$('#remember-me').prop('checked')) {
            window.localStorage.removeItem('OpenAppointments.Customer');
            return;
        }

        const data = {};
        STORED_FIELDS.forEach((id) => {
            data[id] = $('#' + id).val() || '';
        });
        window.localStorage.setItem('OpenAppointments.Customer', JSON.stringify(data));
    }

    function initializeFinalStep() {
        if ($('#altcha-widget').length && App.Utils.Altcha) {
            App.Utils.Altcha.initialize('altcha-widget');
        }
    }

    function updateStepIndicator() {
        const step = Number(($('.wizard-frame').attr('id') || '').replace('wizard-frame-', ''));

        $('.book-step').removeClass('active-step').removeAttr('aria-current');
        if (step) {
            $('#step-' + step).addClass('active-step').attr('aria-current', 'step');
        }
    }

    function showDescription() {
        $('#service-description .selection-description').addClass('d-none');
        $('#service-description .selection-description[data-for-service="' + $('#select-service').val() + '"]').removeClass('d-none');
        $('#provider-description .selection-description').addClass('d-none');
        $('#provider-description .selection-description[data-for-provider="' + $('#select-provider').val() + '"]').removeClass('d-none');
    }

    function initializeStep() {
        initializeTimeStep();
        initializeInfoStep();
        initializeFinalStep();
        updateStepIndicator();
        showDescription();
    }

    function initialize() {
        if (!$('turbo-frame#wizard').length) {
            return;
        }

        App.once('booking-wizard', () => {
            document.addEventListener('turbo:frame-load', (event) => {
                if (event.target.id !== 'wizard') {
                    return;
                }
                initializeStep();
                window.scrollTo({top: 0});
            });

            $(document).on('change', '#select-service, #select-provider', showDescription);
            $(document).on('change', '#select-timezone', () => renderHours(timeStepFrame(), $('#selected-date').val(), true));
            $(document).on('click', '.available-hour', (event) => selectHour($(event.currentTarget).data('value')));

            // The time step's Next needs a chosen hour.
            $(document).on('submit', '#time-step-form', (event) => {
                if ($('#selected-time').val()) {
                    return;
                }
                event.preventDefault();
                if (!$('#select-hour-prompt').length) {
                    $('<div/>', {id: 'select-hour-prompt', class: 'text-danger mb-4', text: lang('appointment_hour_missing')})
                        .prependTo('#available-hours');
                }
            });

            $(document).on('submit', '#info-step-form', rememberCustomer);

            // Card selection writes into the step's select.
            $(document).on('click keypress', '.booking-card', (event) => {
                if (event.type === 'keypress' && event.key !== 'Enter') {
                    return;
                }
                const $card = $(event.currentTarget);
                if ($card.is('[data-category-id]') && !$card.is('[data-service-id]')) {
                    $('#category-cards .booking-card').removeClass('selected');
                    $card.addClass('selected');
                    $('.service-cards').addClass('d-none');
                    $('.service-cards[data-category-id="' + $card.data('categoryId') + '"], .service-cards[data-category-id=""]').removeClass('d-none');
                    $('#select-service-heading').removeClass('d-none');
                    return;
                }
                if ($card.is('[data-service-id]')) {
                    $('.service-cards .booking-card').removeClass('selected');
                    $card.addClass('selected');
                    $('#select-service').val(String($card.data('serviceId'))).trigger('change');
                }
                if ($card.is('[data-provider-id]')) {
                    $('#provider-cards .booking-card').removeClass('selected');
                    $card.addClass('selected');
                    $('#select-provider').val(String($card.data('providerId'))).trigger('change');
                }
            });

            // Cards mode has no visible select: block Next until a card is picked.
            $(document).on('submit', '#service-step-form, #provider-step-form', (event) => {
                const $select = $(event.target).find('#select-service, #select-provider');
                if ($select.hasClass('d-none') && !$select.val()) {
                    event.preventDefault();
                }
            });
        });

        initializeStep();
    }

    App.page(initialize);

    return {};
})();
