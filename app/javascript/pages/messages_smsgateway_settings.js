/**
 * SMS gateway settings: the mobile API URL hint follows the typed server URL,
 * the test SMS block appears once the credentials are complete.
 */
(function () {
    function update() {
        const url = $('#messages-smsgateway-url').val();
        const $target = $('#smsgateway-mobile-api-url');

        if (!$target.length) {
            return;
        }

        $target.text((url || 'https://<server>').replace(/\/+$/, '') + $target.data('suffix'));
        const ready = Boolean(url && $('#messages-smsgateway-login').val() && $('#messages-smsgateway-password').val());
        $('#smsgateway-test').prop('hidden', !ready);
    }

    $(document).on('input change', '#messages-smsgateway-url, #messages-smsgateway-login, #messages-smsgateway-password', update);
    document.addEventListener('turbo:frame-load', update);
    App.page(update);

    $(document).on('click', '#smsgateway-send-test', () => {
        $.post(App.Utils.Url.siteUrl('messages_smsgateway_settings/test_sms'), {
            csrf_token: vars('csrf_token'),
            number: $('#smsgateway-test-number').val(),
        }).done((response) => {
            if (response && response.success === false) {
                App.Layouts.Backend.displayNotification(response.message || lang('settings_are_invalid'));
                return;
            }
            App.Layouts.Backend.displayNotification(lang('messages_test_sms_sent'));
        });
    });
})();
