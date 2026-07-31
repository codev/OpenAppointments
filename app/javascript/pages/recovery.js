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
 * Recovery page.
 *
 * This module implements the functionality of the recovery page.
 */
App.Pages.Recovery = (function () {
    const $form = $('form');
    const $username = $('#username');
    const $email = $('#email');
    const $getNewPassword = $('#get-new-password');
    const $altchaPayload = $('#altcha-payload');
    const $altchaHint = $('#altcha-hint');
    const $turnstileHint = $('#turnstile-hint');

    function turnstileToken() {
        return $('.cf-turnstile [name="cf-turnstile-response"]').val();
    }

    /**
     * Event: Form "Submit"
     *
     * Make an HTTP request to the server to request a password reset link.
     */
    function onFormSubmit(event) {
        event.preventDefault();

        const $alert = $('.alert');

        $alert.addClass('d-none');

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

        $getNewPassword.prop('disabled', true);

        const username = $username.val();
        const email = $email.val();
        const altchaPayloadValue = $altchaPayload.length > 0 ? $altchaPayload.val() : null;

        App.Http.Recovery.perform(username, email, altchaPayloadValue, turnstileToken())
            .done((response) => {
                $alert.removeClass('d-none alert-danger alert-success');

                if (response.altcha_verification === false) {
                    $altchaHint.text(lang('altcha_verification_failed')).fadeTo(400, 1);
                    
                    setTimeout(() => {
                        $altchaHint.fadeTo(400, 0);
                    }, 3000);
                    
                    if (App.Utils.Altcha) {
                        App.Utils.Altcha.reset('altcha-widget');
                    }
                    
                    return;
                }

                if (response.success) {
                    $alert.addClass('alert-success');
                    $alert.text(lang('reset_link_sent_with_email'));
                } else {
                    $alert.addClass('alert-danger');
                    $alert.text(
                        'The operation failed! Please enter a valid username ' +
                            'and email address in order to receive a password reset link.',
                    );
                }
            })
            .always(() => {
                $getNewPassword.prop('disabled', false);
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

    $form.on('submit', onFormSubmit);

    // Initialize ALTCHA
    initializeAltcha();

    return {};
})();
