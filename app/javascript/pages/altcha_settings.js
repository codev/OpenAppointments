/**
 * Captcha settings: generate an ALTCHA key, and render the Turnstile test
 * widget for the typed site key (its token posts with the form).
 */
(function () {
    let turnstileWidgetId = null;

    function renderTurnstileTest() {
        const $container = $('#turnstile-test');

        if (!window.turnstile || !$container.length) {
            return;
        }

        if (turnstileWidgetId !== null) {
            window.turnstile.remove(turnstileWidgetId);
            turnstileWidgetId = null;
        }

        $container.empty();
        const siteKey = $('#turnstile-site-key').val().trim();

        if (siteKey) {
            turnstileWidgetId = window.turnstile.render($container[0], {sitekey: siteKey});
        }
    }

    window.onloadTurnstileCallback = renderTurnstileTest;

    $(document).on('change', '#turnstile-site-key', renderTurnstileTest);
    document.addEventListener('turbo:frame-load', renderTurnstileTest);
    App.page(renderTurnstileTest);

    $(document).on('click', '#generate-hmac-key', () => {
        $.post(App.Utils.Url.siteUrl('altcha_settings/generate_key'), {csrf_token: vars('csrf_token')}).done((response) => {
            $('#altcha-hmac-key').val(response.hmac_key);
        });
    });
})();
