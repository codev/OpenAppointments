/**
 * Event dialog: the appointment, unavailability and remove forms are Rails
 * views loaded into the event frame inside #event-modal. A saved form answers
 * with a [data-event-saved] marker: close, notify, reload the calendar.
 */
App.Components.EventModal = (function () {
    function frame() {
        return document.querySelector('turbo-frame#event');
    }

    function modal() {
        const dialog = document.getElementById('event-modal');
        return {show: () => App.Utils.Dialog.open(dialog), hide: () => App.Utils.Dialog.close(dialog)};
    }

    function open(url) {
        $('.popover').remove();
        frame().src = App.Utils.Url.siteUrl(url);
    }

    function reportSkipped(skipped) {
        if (!skipped || !skipped.length) {
            return;
        }

        const dates = skipped
            .map((entry) => App.Utils.Date.format(entry.date, vars('date_format'), vars('time_format'), false))
            .join(', ');

        App.Utils.Message.show(lang('repeat'), lang('repeat_dates_not_booked').replace('{count}', skipped.length) + ' ' + dates);
    }

    function onFrameLoad(event) {
        if (event.target.id !== 'event') {
            return;
        }

        const saved = frame().querySelector('[data-event-saved]');

        if (saved) {
            modal().hide();
            if (saved.dataset.message) {
                App.Layouts.Backend.displayNotification(saved.dataset.message);
            }
            reportSkipped(JSON.parse(saved.dataset.skipped || '[]'));
            $('#reload-appointments').trigger('click');
            return;
        }

        App.Utils.UI.initializeDateTimePicker($('.event-form .datetime-picker'));
        updateProviders();
        updateTimezone();
        modal().show();
        $('.event-form .dialog-body').scrollTop(0);
    }

    // The provider list follows the chosen service; the end time follows its duration.
    function updateProviders(changed = false) {
        const $service = $('#select-service');
        const $provider = $('#select-provider');

        if (!$service.length) {
            return;
        }

        const serviceId = Number($service.val());
        const current = $provider.val();
        $provider.find('option').each((index, option) => {
            const services = JSON.parse(option.dataset.services || '[]');
            const offered = services.indexOf(serviceId) !== -1;
            option.hidden = !offered;
            option.disabled = !offered;
        });

        if (!$provider.find('option:selected').length || $provider.find('option:selected').prop('disabled')) {
            $provider.val($provider.find('option:not([disabled])').first().val());
        } else {
            $provider.val(current);
        }

        if (changed) {
            const colors = JSON.parse($service.attr('data-colors') || '{}');
            if (colors[serviceId]) {
                App.Components.ColorSelection.setColor($('#appointment-color'), colors[serviceId]);
                $('#appointment-color input[type=hidden]').val(colors[serviceId]);
            }
            const durations = JSON.parse($service.attr('data-durations') || '{}');
            const start = App.Utils.UI.getDateTimePickerValue($('#start-datetime'));
            if (start) {
                const end = new Date(start.getTime() + (durations[serviceId] || 60) * 60000);
                App.Utils.UI.setDateTimePickerValue($('#end-datetime'), end);
            }
        }
    }

    function updateTimezone() {
        const option = $('#select-provider option:selected, #unavailability-provider option:selected').first();
        $('.event-form .provider-timezone').text(option.data('timezone') || '-');
    }

    function fillCustomer(customer) {
        const fields = {
            'customer-id': customer.id, 'name': customer.name, 'email': customer.email, 'phone-number': customer.phone_number,
            'address': customer.address, 'city': customer.city, 'zip-code': customer.zip_code, 'language': customer.language,
            'timezone': customer.timezone, 'customer-notes': customer.notes,
        };
        for (let i = 1; i <= 5; i++) {
            fields['custom-field-' + i] = customer['custom_field_' + i];
        }
        Object.entries(fields).forEach(([id, value]) => $('#' + id).val(value || ''));
    }

    function toggleCustomerList(show) {
        const $list = $('#existing-customers-list');
        const $filter = $('#filter-existing-customers');
        const $button = $('#select-customer span');

        if (show) {
            $list.slideDown('slow');
            $filter.fadeIn('slow').val('');
            $button.text(lang('hide'));
        } else {
            $list.slideUp('slow');
            $filter.fadeOut('slow');
            $button.text(lang('select'));
        }
    }

    let filterTimeout = null;

    function searchCustomers(keyword) {
        clearTimeout(filterTimeout);
        filterTimeout = setTimeout(() => {
            $.post(App.Utils.Url.siteUrl('customers/search'), {csrf_token: vars('csrf_token'), keyword, limit: 50}).done((rows) => {
                const $list = $('#existing-customers-list').empty();
                rows.forEach((customer) => {
                    $('<div/>', {'data-id': customer.id, text: customer.name || '[No Name]'})
                        .attr('data-customer', JSON.stringify(customer))
                        .appendTo($list);
                });
            });
        }, 500);
    }

    // The jQuery dialog asked whether to notify before saving; keep that.
    function onSubmit(event) {
        const form = event.target;

        if (!form.matches('.event-form') || !form.dataset.askNotify || form.notify_users.value !== '') {
            return;
        }

        event.preventDefault();
        event.stopImmediatePropagation();

        const answer = (value) => {
            form.notify_users.value = value;
            form.requestSubmit();
        };

        App.Utils.Message.show(form.dataset.askNotify, lang(form.dataset.askNotifyQuestion), [
            {text: lang('no'), click: (e, messageModal) => { messageModal.hide(); answer('0'); }},
            {text: lang('yes'), click: (e, messageModal) => { messageModal.hide(); answer('1'); }},
        ]);
    }

    // The repeat fields widget serialises into hidden repeat[...] inputs.
    function serialiseRepeat(event) {
        const form = event.target;

        if (!form.matches('#appointment-form') || !$('.repeat-fields').length) {
            return;
        }

        form.querySelectorAll('input[name^="repeat["]').forEach((input) => input.remove());
        const repeat = App.Components.RepeatFields.read('repeat');

        if (!repeat) {
            return;
        }

        Object.entries(repeat).forEach(([key, value]) => {
            $('<input/>', {type: 'hidden', name: 'repeat[' + key + ']', value}).appendTo(form);
        });
    }

    function initialize() {
        if (!document.getElementById('event-modal')) {
            return;
        }

        App.once('event-modal', () => {
            document.addEventListener('turbo:frame-load', onFrameLoad);
            document.addEventListener('submit', serialiseRepeat, true);
            document.addEventListener('submit', onSubmit, true);

            $(document).on('change', '#select-service', () => updateProviders(true));
            $(document).on('change', '#select-provider, #unavailability-provider', updateTimezone);
            $(document).on('click', '#select-customer', () => toggleCustomerList(!$('#existing-customers-list').is(':visible')));
            $(document).on('click', '#existing-customers-list div', (event) => {
                fillCustomer(JSON.parse(event.currentTarget.dataset.customer));
                toggleCustomerList(false);
            });
            $(document).on('keyup', '#filter-existing-customers', (event) => searchCustomers(event.target.value));
            $(document).on('click', '#new-customer', () => fillCustomer({}));

            // Toolbar: new appointment / unavailability for the filtered provider or service.
            $(document).on('click', '#insert-appointment', (event) => {
                event.preventDefault();
                const $filter = $('#select-filter-item, #filter-provider').first();
                const type = $filter.find('option:selected').attr('type') || ($filter.is('#filter-provider') ? 'provider' : '');
                const params = new URLSearchParams();
                if (type === 'provider' && $filter.val()) params.set('provider_id', $filter.val());
                if (type === 'service' && $filter.val()) params.set('service_id', $filter.val());
                open('appointments/new?' + params.toString());
            });
            $(document).on('click', '#insert-unavailability', (event) => {
                event.preventDefault();
                const $filter = $('#select-filter-item, #filter-provider').first();
                const providerId = $filter.find('option:selected').attr('type') === 'provider' || $filter.is('#filter-provider') ? $filter.val() : '';
                open('unavailabilities/new' + (providerId ? '?provider_id=' + providerId : ''));
            });
        });
    }

    App.page(initialize);

    return {open, reportSkipped};
})();
