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
 * ALTCHA settings page.
 *
 * This module implements the functionality of the ALTCHA settings page.
 */
App.Pages.AltchaSettings = (function () {
    const $saveSettings = $('#save-settings');
    const $generateHmacKey = $('#generate-hmac-key');
    const $altchaHmacKey = $('#altcha-hmac-key');

    /**
     * Check if the form has invalid values.
     *
     * @return {Boolean}
     */
    function isInvalid() {
        try {
            $('#altcha-settings .is-invalid').removeClass('is-invalid');

            const $altchaEnabled = $('#altcha-enabled');

            // If enabled with the ALTCHA provider, HMAC key is required
            if (
                $altchaEnabled.prop('checked') &&
                $('#captcha-provider').val() === 'altcha' &&
                !$altchaHmacKey.val().trim()
            ) {
                $altchaHmacKey.addClass('is-invalid');
                throw new Error(lang('fields_are_required'));
            }

            return false;
        } catch (error) {
            App.Layouts.Backend.displayNotification(error.message);
            return true;
        }
    }

    /**
     * Deserialize the ALTCHA settings.
     *
     * @param {Array} altchaSettings
     */
    function deserialize(altchaSettings) {
        altchaSettings.forEach((altchaSetting) => {
            const $field = $('[data-field="' + altchaSetting.name + '"]');

            $field.is(':checkbox')
                ? $field.prop('checked', Boolean(Number(altchaSetting.value)))
                : $field.val(altchaSetting.value);
        });
    }

    /**
     * Serialize the ALTCHA settings.
     *
     * @return {Array}
     */
    function serialize() {
        const altchaSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            altchaSettings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        return altchaSettings;
    }

    /**
     * Save the ALTCHA settings.
     */
    function onSaveSettingsClick() {
        if (isInvalid()) {
            App.Layouts.Backend.displayNotification(lang('settings_are_invalid'));
            return;
        }

        const altchaSettings = serialize();

        App.Http.AltchaSettings.save(altchaSettings).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    /**
     * Generate a new HMAC key.
     */
    function onGenerateHmacKeyClick() {
        App.Http.AltchaSettings.generateKey().done((response) => {
            $altchaHmacKey.val(response.hmac_key);
            App.Layouts.Backend.displayNotification(lang('altcha_key_generated'));
        });
    }

    /**
     * Show only the selected provider's settings.
     */
    function toggleProviderSections() {
        const provider = $('#captcha-provider').val();

        $('#altcha-provider-settings').toggleClass('d-none', provider !== 'altcha');
        $('#turnstile-provider-settings').toggleClass('d-none', provider !== 'turnstile');
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);
        $generateHmacKey.on('click', onGenerateHmacKeyClick);
        $('#captcha-provider').on('change', toggleProviderSections);

        const altchaSettings = vars('altcha_settings');

        deserialize(altchaSettings);

        toggleProviderSections();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
