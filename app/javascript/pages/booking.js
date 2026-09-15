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
    const DRAFT_KEY = 'OpenAppointments.Draft';

    function readStorage(storage, key) {
        try {
            return JSON.parse(storage.getItem(key) || 'null');
        } catch (error) {
            return null;
        }
    }

    function fillEmptyFields(values) {
        Object.keys(values || {}).forEach((id) => {
            const $field = $('#' + id);
            if ($field.length && !$field.val()) {
                $field.val(values[id] || '');
            }
        });
    }

    // Details typed this session come back when an earlier step is revisited;
    // remembered details (opt-in, kept across sessions) fill what is still empty.
    function initializeInfoStep() {
        if (!$('#info-step-form').length) {
            return;
        }

        fillEmptyFields(readStorage(window.sessionStorage, DRAFT_KEY));

        const stored = readStorage(window.localStorage, 'OpenAppointments.Customer');
        if (stored) {
            $('#remember-me').prop('checked', true);
            fillEmptyFields(stored);
        }
    }

    // The details step's own checks, as the server applies them: required
    // fields, one of phone or email, and the email and phone formats.
    function validateDetails(form) {
        const $form = $(form);
        const $message = $('#form-message');
        const fail = (fields, message) => {
            fields.forEach(($field) => $field.addClass('is-invalid'));
            $message.text(message).prop('hidden', false);
            return false;
        };

        $form.find('.is-invalid').removeClass('is-invalid');
        $message.prop('hidden', true);

        const missing = $form.find('[required]').filter((index, field) => !$(field).val()).toArray().map((field) => $(field));
        if (missing.length) {
            return fail(missing, lang('fields_are_required'));
        }
        const $email = $('#email');
        const $phone = $('#phone-number');
        if ($form.data('requirePhoneOrEmail') === 1 && !$email.val() && !$phone.val()) {
            return fail([$email, $phone], lang('phone_or_email_required'));
        }
        if ($email.val() && !App.Utils.Validation.email($email.val())) {
            return fail([$email], lang('invalid_email'));
        }
        if ($phone.val() && !App.Utils.Validation.phone($phone.val())) {
            return fail([$phone], lang('invalid_phone'));
        }
        return true;
    }

    function saveDraft() {
        const draft = {};
        $('#info-step-form .form-control').each((index, field) => {
            draft[field.id] = $(field).val() || '';
        });
        window.sessionStorage.setItem(DRAFT_KEY, JSON.stringify(draft));
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

    // The header sits outside the frame: mirror #wizard-state into it.
    function updateHeader() {
        const $state = $('#wizard-state');
        if (!$state.length) {
            return;
        }
        const step = Number($state.data('step'));
        const links = JSON.parse($state.attr('data-step-links') || '{}');

        $('.book-step').each((index, element) => {
            const $step = $(element);
            const number = Number($step.data('stepIndex'));
            $step.removeClass('active-step completed-step').removeAttr('aria-current role tabindex data-href');
            if (number === step) {
                $step.addClass('active-step').attr('aria-current', 'step');
            } else if (links[number]) {
                $step.addClass('completed-step').attr({'role': 'button', 'tabindex': 0, 'data-href': links[number]});
            }
        });

        $('.display-booking-selection').text($state.data('selection'));
    }

    // A choice on a selection step shows straight away in the header line.
    function updateSelectionText() {
        const $select = $('#select-service, #select-provider').first();
        if (!$select.length || !$select.val()) {
            return;
        }
        // The parts run in wizard order: step 1 chooses the first, step 2 the second.
        const parts = $('#wizard-state').data('selection').split('│').map((part) => part.trim());
        parts[Number($('#wizard-state').data('step')) === 1 ? 0 : 1] = $select.find('option:selected').text().trim();
        $('.display-booking-selection').text(parts.join(' │ '));
    }

    // Completed header steps jump back; the previous step goes through the
    // page's own Back button so a confirmation keeps its typed details.
    function goBackToStep(number) {
        const current = Number($('#wizard-state').data('step'));
        const $back = $('.wizard-frame .button-back');
        if (number === current - 1 && $back.length) {
            $back[0].click();
            return;
        }
        const href = $('#step-' + number).attr('data-href');
        if (href) {
            window.Turbo.visit(href, {frame: 'wizard', action: 'advance'});
        }
    }

    function scrollTo(top) {
        $('html, body').animate({scrollTop: Math.max(top, 0)}, 400);
    }

    // Bring the step's Next button to the bottom of the view.
    function scrollToNext() {
        const $buttons = $('.wizard-frame .command-buttons');
        if ($buttons.length) {
            scrollTo($buttons.offset().top + $buttons.outerHeight() + 20 - window.innerHeight);
        }
    }

    function showDescription() {
        $('#service-description .selection-description').addClass('d-none');
        $('#service-description .selection-description[data-for-service="' + $('#select-service').val() + '"]').removeClass('d-none');
        $('#provider-description .selection-description').addClass('d-none');
        $('#provider-description .selection-description[data-for-provider="' + $('#select-provider').val() + '"]').removeClass('d-none');
    }

    function onSubmit(event) {
        const form = event.target;
        if (form.id === 'time-step-form' && !$('#selected-time').val()) {
            // Next needs a chosen hour.
            event.preventDefault();
            if (!$('#select-hour-prompt').length) {
                $('<div/>', {id: 'select-hour-prompt', class: 'text-danger mb-4', text: lang('appointment_hour_missing')})
                    .prependTo('#available-hours');
            }
        } else if (form.id === 'service-step-form' || form.id === 'provider-step-form') {
            // Cards mode has no visible select: block Next until a card is picked.
            const $select = $(form).find('#select-service, #select-provider');
            if ($select.hasClass('d-none') && !$select.val()) {
                event.preventDefault();
            }
        } else if (form.id === 'info-step-form') {
            if (!validateDetails(form)) {
                event.preventDefault();
                return;
            }
            rememberCustomer();
            saveDraft();
        } else if (form.id === 'book-appointment-form') {
            window.sessionStorage.removeItem(DRAFT_KEY);
        }
    }

    function initializeStep() {
        initializeTimeStep();
        initializeInfoStep();
        initializeFinalStep();
        updateHeader();
        updateSelectionText(); // a lone provider is preselected without a change event
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

            $(document).on('change', '#select-service, #select-provider', (event) => {
                showDescription();
                updateSelectionText();
                if (event.originalEvent) {
                    scrollToNext();
                }
            });

            $('#steps').on('click', '.book-step.completed-step', (event) => goBackToStep(Number($(event.currentTarget).data('stepIndex'))));
            $('#steps').on('keydown', '.book-step.completed-step', (event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    goBackToStep(Number($(event.currentTarget).data('stepIndex')));
                }
            });
            $(document).on('change', '#select-timezone', () => renderHours(timeStepFrame(), $('#selected-date').val(), true));
            $(document).on('click', '.available-hour', (event) => {
                selectHour($(event.currentTarget).data('value'));
                scrollToNext();
            });

            // Turbo swallows a form's submit before delegated jQuery handlers see
            // it, so the guards listen in the capture phase.
            document.addEventListener('submit', onSubmit, true);

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
                    const $heading = $('#select-service-heading').removeClass('d-none');
                    scrollTo($heading.offset().top - 20);
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
                scrollToNext();
            });

        });

        window.tippy('[data-tippy-content]');
        initializeStep();
    }

    App.page(initialize);

    return {};
})();
