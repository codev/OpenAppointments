/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Login page.
 *
 * This module implements the functionality of the login page.
 */
App.Pages.Login = (function () {
    const $loginForm = $('#login-form');
    const $username = $('#username');
    const $password = $('#password');
    const $altchaPayload = $('#altcha-payload');
    const $altchaHint = $('#altcha-hint');
    const $turnstileHint = $('#turnstile-hint');

    function turnstileToken() {
        return $('.cf-turnstile [name="cf-turnstile-response"]').val();
    }

    /**
     * Login Button "Click"
     *
     * Make an ajax call to the server and check whether the user's credentials are right.
     *
     * If yes then redirect him to his desired page, otherwise display a message.
     */
    function onLoginFormSubmit(event) {
        event.preventDefault();

        const username = $username.val();
        const password = $password.val();

        if (!username || !password) {
            return;
        }

        if ($('.cf-turnstile').length > 0 && !turnstileToken()) {
            $turnstileHint.text(lang('turnstile_verification_failed')).fadeTo(400, 1);

            setTimeout(() => {
                $turnstileHint.fadeTo(400, 0);
            }, 3000);

            return;
        }

        if ($altchaPayload.length > 0 && $altchaPayload.val() === '') {
            $altchaHint.text(lang('altcha_verification_failed')).fadeTo(400, 1);
            
            setTimeout(() => {
                $altchaHint.fadeTo(400, 0);
            }, 3000);
            
            return;
        }

        const altchaPayloadValue = $altchaPayload.length > 0 ? $altchaPayload.val() : null;

        const $alert = $('.alert');

        $alert.addClass('d-none');

        App.Http.Login.validate(username, password, altchaPayloadValue, turnstileToken()).done((response) => {
            if (response.turnstile_verification === false) {
                $turnstileHint.text(lang('turnstile_verification_failed')).fadeTo(400, 1);

                setTimeout(() => {
                    $turnstileHint.fadeTo(400, 0);
                }, 3000);

                if (window.turnstile) {
                    window.turnstile.reset();
                }

                return;
            }

            if (response.altcha_verification === false) {
                $altchaHint.text(lang('altcha_verification_failed')).fadeTo(400, 1);
                
                setTimeout(() => {
                    $altchaHint.fadeTo(400, 0);
                }, 3000);
                
                // Reset ALTCHA widget
                if (App.Utils.Altcha) {
                    App.Utils.Altcha.reset('altcha-widget');
                }
                
                return;
            }

            if (response.success) {
                window.location.href = vars('dest_url');
            } else {
                $alert.text(lang('login_failed'));
                $alert.removeClass('d-none alert-danger alert-success').addClass('alert-danger');

                if (window.turnstile) {
                    window.turnstile.reset();
                }

                if (App.Utils.Altcha && $('#altcha-widget').length) {
                    App.Utils.Altcha.reset('altcha-widget');
                }
            }
        });
    }
    
    /**
     * Initialize ALTCHA widget if present.
     */
    function initializeAltcha() {
        if ($('#altcha-widget').length && App.Utils.Altcha) {
            App.Utils.Altcha.initialize('altcha-widget');
        }
    }

    $loginForm.on('submit', onLoginFormSubmit);

    // Initialize ALTCHA
    initializeAltcha();

    return {};
})();
