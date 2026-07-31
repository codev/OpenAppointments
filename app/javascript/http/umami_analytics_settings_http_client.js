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
 * Umami Analytics Settings HTTP client.
 *
 * This module implements the Umami Analytics settings related HTTP requests.
 */
App.Http.UmamiAnalyticsSettings = (function () {
    /**
     * Save Umami Analytics settings.
     *
     * @param {Object} umamiAnalyticsSettings
     *
     * @return {Object}
     */
    function save(umamiAnalyticsSettings) {
        const url = App.Utils.Url.siteUrl('umami_analytics_settings/save');

        const data = {
            csrf_token: vars('csrf_token'),
            umami_analytics_settings: umamiAnalyticsSettings,
        };

        return $.post(url, data);
    }

    return {
        save,
    };
})();
