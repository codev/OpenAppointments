/**
 * SMS gateway settings: the mobile API URL hint follows the typed server URL.
 */
(function () {
    function update() {
        const url = $('#messages-smsgateway-url').val();
        const $target = $('#smsgateway-mobile-api-url');

        if (!$target.length) {
            return;
        }

        $target.text((url || 'https://<server>').replace(/\/+$/, '') + $target.data('suffix'));
    }

    $(document).on('input change', '#messages-smsgateway-url', update);
    document.addEventListener('turbo:frame-load', update);
    App.page(update);
})();
