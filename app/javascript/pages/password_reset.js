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
 * Password Reset page.
 *
 * This module implements the functionality of the password reset page.
 */
App.Pages.PasswordReset = (function () {
    const $form = $('#password-reset-form');
    const $token = $('#token');
    const $password = $('#password');
    const $passwordConfirm = $('#password-confirm');
    const $resetPassword = $('#reset-password');
    const $alert = $('.alert');
    const $altchaPayload = $('#altcha-payload');
    const $altchaHint = $('#altcha-hint');
    const $turnstileHint = $('#turnstile-hint');

    function turnstileToken() {
        return $('.cf-turnstile [name="cf-turnstile-response"]').val();
    }

    /**
     * Event: Form "Submit"
     *
     * Validate the password fields and submit the reset request.
     */
    function onFormSubmit(event) {
        event.preventDefault();

        $alert.addClass('d-none');

        const token = $token.val();
        const password = $password.val();
        const passwordConfirm = $passwordConfirm.val();

        // Validate password
        if (!password) {
            $alert.removeClass('d-none alert-success').addClass('alert-danger');
            $alert.text(lang('no_password_provided'));

            return;
        }

        if (password !== passwordConfirm) {
            $alert.removeClass('d-none alert-success').addClass('alert-danger');
            $alert.text(lang('passwords_mismatch'));

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

        $resetPassword.prop('disabled', true);

        App.Http.PasswordReset.complete(token, password, passwordConfirm, altchaPayloadValue, turnstileToken())
            .done((response) => {
                $alert.removeClass('d-none alert-danger');

                if (response.altcha_verification === false) {
                    $altchaHint.text(lang('altcha_verification_failed')).fadeTo(400, 1);
                    
                    setTimeout(() => {
                        $altchaHint.fadeTo(400, 0);
                    }, 3000);
                    
                    if (App.Utils.Altcha) {
                        App.Utils.Altcha.reset('altcha-widget');
                    }
                    
                    $alert.addClass('d-none');
                    
                    return;
                }

                if (response.success) {
                    $alert.addClass('alert-success');
                    $alert.text(lang('password_reset_success'));
                    // Hide the form after successful reset
                    $form.hide();
                    // Redirect to login page after a short delay
                    setTimeout(() => {
                        window.location.href = App.Utils.Url.siteUrl('login');
                    }, 2000);
                } else {
                    $alert.addClass('alert-danger');
                    $alert.text(lang('password_reset_failed'));
                }
            })
            .fail((jqXHR) => {
                $alert.removeClass('d-none alert-success').addClass('alert-danger');

                const response = jqXHR.responseJSON;

                if (response && response.message) {
                    $alert.text(response.message);
                } else {
                    $alert.text(lang('password_reset_failed'));
                }
            })
            .always(() => {
                $resetPassword.prop('disabled', false);
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

    // Only attach event listener if the form exists (token is valid)
    if ($form.length) {
        $form.on('submit', onFormSubmit);
    }

    // Initialize ALTCHA
    initializeAltcha();

    return {};
})();
