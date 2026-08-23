/**
 * Public booking wizard. The steps are server rendered into the wizard frame;
 * this script handles what stays client side: the calendar and hour buttons
 * (the whole window's hours arrive with the time step, so switching days needs
 * no request), card selection, live descriptions, the remembered details and
 * the captcha.
 */
App.Pages.Booking = (function () {
    function timeLabel(hhmm, timeFormat) {
        const [hour, minute] = hhmm.split(':').map(Number);
        if (timeFormat === 'military') {
            return hhmm;
        }
        const suffix = hour >= 12 ? 'pm' : 'am';
        const twelve = hour % 12 === 0 ? 12 : hour % 12;
        return twelve + ':' + String(minute).padStart(2, '0') + ' ' + suffix;
    }

    function renderHours($frame, date) {
        const windowHours = $frame.data('window') || {};
        const timeFormat = $frame.data('timeFormat');
        const $hours = $('#available-hours').empty();
        const hours = windowHours[date] || [];

        $('#selected-date').val(date);
        $('#selected-time').val('');

        if (!hours.length) {
            $('<em/>', {text: lang('no_available_hours')}).appendTo($hours);
            return;
        }

        // A reschedule keeps its original hour selectable on its own day.
        const appointmentStart = String($frame.data('appointmentStart') || '');
        const shown = hours.slice();
        if (appointmentStart.startsWith(date)) {
            const original = appointmentStart.slice(11, 16);
            if (original && !shown.includes(original)) {
                shown.push(original);
                shown.sort();
            }
        }

        shown.forEach((hour) => {
            $('<button/>', {
                'type': 'button',
                'class': 'btn btn-outline-secondary w-100 shadow-none available-hour my-1',
                'data-value': hour,
                'text': timeLabel(hour, timeFormat),
            }).appendTo($hours);
        });

        const selected = $frame.data('selectedTime');
        if (selected && shown.includes(selected)) {
            selectHour(selected);
        }
    }

    function selectHour(hour) {
        $('#select-hour-prompt').remove();
        $('.available-hour').removeClass('selected-hour btn-primary').addClass('btn-outline-secondary');
        $('.available-hour[data-value="' + hour + '"]').addClass('selected-hour btn-primary').removeClass('btn-outline-secondary');
        $('#selected-time').val(hour);
    }

    function initializeTimeStep() {
        const $frame = $('#time-step-form').closest('.wizard-frame');

        if (!$frame.length) {
            return;
        }

        const windowHours = $frame.data('window') || {};
        const enabled = Object.keys(windowHours);
        const initial = $frame.data('selectedDate') || enabled[0];

        flatpickr('#select-date', {
            inline: true,
            static: true,
            enable: enabled.length ? enabled : [ () => false ],
            defaultDate: initial,
            locale: App.Utils.UI.getFlatpickrLocale ? undefined : undefined,
            onChange: (dates, dateStr) => renderHours($frame, dateStr),
        });

        if (initial) {
            renderHours($frame, initial);
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
        const step = Number($('turbo-frame#wizard').data('step') || $('.wizard-frame').attr('id')?.replace('wizard-frame-', ''));

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

    function initialize() {
        if (!$('turbo-frame#wizard').length) {
            return;
        }

        App.once('booking-wizard', () => {
            document.addEventListener('turbo:frame-load', (event) => {
                if (event.target.id !== 'wizard') {
                    return;
                }
                initializeTimeStep();
                initializeInfoStep();
                initializeFinalStep();
                updateStepIndicator();
                showDescription();
                window.scrollTo({top: 0});
            });

            $(document).on('change', '#select-service, #select-provider', showDescription);
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

        initializeTimeStep();
        initializeInfoStep();
        initializeFinalStep();
        updateStepIndicator();
        showDescription();
    }

    App.page(initialize);

    return {};
})();
