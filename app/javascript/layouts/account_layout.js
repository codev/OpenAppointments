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
 * Account layout.
 *
 * This module implements the account layout functionality.
 */
window.App.Layouts.Account = (function () {
    const $selectLanguage = () => $('#select-language');

    /**
     * Initialize the module.
     */
    function initialize() {
        App.Utils.Lang.enableLanguageSelection($selectLanguage());

        // The auth forms' captcha widget (shared/_auth_captcha); it fills #altcha-payload.
        if ($('#altcha-widget').length && App.Utils.Altcha) {
            App.Utils.Altcha.initialize('altcha-widget');
        }
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
