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
 * Umami Analytics settings page.
 *
 * This module implements the functionality of the Umami Analytics settings page.
 */
App.Pages.UmamiAnalyticsSettings = (function () {
    const $saveSettings = $('#save-settings');

    /**
     * Check if the form has invalid values.
     *
     * @return {Boolean}
     */
    function isInvalid() {
        try {
            $('#umami-analytics-settings .is-invalid').removeClass('is-invalid');

            // Validate required fields.

            let missingRequiredFields = false;

            $('#umami-analytics-settings .required').each((index, requiredField) => {
                const $requiredField = $(requiredField);

                if (!$requiredField.val()) {
                    $requiredField.addClass('is-invalid');
                    missingRequiredFields = true;
                }
            });

            if (missingRequiredFields) {
                throw new Error(lang('fields_are_required'));
            }

            return false;
        } catch (error) {
            App.Layouts.Backend.displayNotification(error.message);
            return true;
        }
    }

    function deserialize(umamiAnalyticsSettings) {
        umamiAnalyticsSettings.forEach((umamiAnalyticsSetting) => {
            const $field = $('[data-field="' + umamiAnalyticsSetting.name + '"]');

            $field.is(':checkbox')
                ? $field.prop('checked', Boolean(Number(umamiAnalyticsSetting.value)))
                : $field.val(umamiAnalyticsSetting.value);
        });
    }

    function serialize() {
        const umamiAnalyticsSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            umamiAnalyticsSettings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        return umamiAnalyticsSettings;
    }

    /**
     * Save the account information.
     */
    function onSaveSettingsClick() {
        if (isInvalid()) {
            App.Layouts.Backend.displayNotification(lang('settings_are_invalid'));

            return;
        }

        const umamiAnalyticsSettings = serialize();

        App.Http.UmamiAnalyticsSettings.save(umamiAnalyticsSettings).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);

        const umamiAnalyticsSettings = vars('umami_analytics_settings');

        deserialize(umamiAnalyticsSettings);
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
