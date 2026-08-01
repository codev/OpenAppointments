/**
 * SMS Gateway settings page extras on top of the shared provider module: the
 * computed mobile API URL in the instructions, and the test SMS section that
 * appears once the connection details are filled in.
 */
App.Pages.MessagesSmsgatewaySettings = (function () {
    const $url = $('#messages-smsgateway-url');
    const $login = $('#messages-smsgateway-login');
    const $password = $('#messages-smsgateway-password');

    function updateMobileApiUrl() {
        const $target = $('#smsgateway-mobile-api-url');
        const base = ($url.val() || 'https://<server>').replace(/\/+$/, '');
        $target.text(base + $target.data('suffix'));
    }

    function updateTestVisibility() {
        const ready = Boolean($url.val() && $login.val() && $password.val());
        $('#smsgateway-test').toggleClass('d-none', !ready);
    }

    function onSendTestClick() {
        const number = $('#smsgateway-test-number').val();

        $.post(App.Utils.Url.siteUrl('messages_smsgateway_settings/test_sms'), {
            csrf_token: vars('csrf_token'),
            number: number,
        }).done((response) => {
            if (response && response.success === false) {
                App.Layouts.Backend.displayNotification(response.message || lang('settings_are_invalid'));
                return;
            }

            App.Layouts.Backend.displayNotification(lang('messages_test_sms_sent'));
        });
    }

    function initialize() {
        $url.add($login).add($password).on('input change', () => {
            updateMobileApiUrl();
            updateTestVisibility();
        });
        $('#smsgateway-send-test').on('click', onSendTestClick);

        // The shared module deserializes on DOMContentLoaded too; run after it.
        setTimeout(() => {
            updateMobileApiUrl();
            updateTestVisibility();
        }, 0);
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
