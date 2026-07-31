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
 * Login HTTP client.
 *
 * This module implements the account login related HTTP requests.
 */
App.Http.Login = (function () {
    /**
     * Perform an account recovery.
     *
     * @param {String} username
     * @param {String} password
     * @param {String} altchaPayload
     * @param {String} turnstileToken
     *
     * @return {Object}
     */
    function validate(username, password, altchaPayload, turnstileToken) {
        const url = App.Utils.Url.siteUrl('login/validate');

        const data = {
            csrf_token: vars('csrf_token'),
            username,
            password,
        };

        if (altchaPayload) {
            data.altcha_payload = altchaPayload;
        }

        if (turnstileToken) {
            data.cf_turnstile_response = turnstileToken;
        }

        return $.post(url, data);
    }

    return {
        validate,
    };
})();
