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

            const active = $('#altcha-enabled').prop('checked') || $('#captcha-login-enabled').prop('checked');
            const provider = $('#captcha-provider').val();

            // An active provider must be fully configured.
            if (active && provider === 'altcha' && !$altchaHmacKey.val().trim()) {
                $altchaHmacKey.addClass('is-invalid');
                throw new Error(lang('altcha_hmac_key_missing'));
            }

            if (active && provider === 'turnstile') {
                const $siteKey = $('#turnstile-site-key');
                const $secretKey = $('#turnstile-secret-key');

                if (!$siteKey.val().trim() || !$secretKey.val().trim()) {
                    $siteKey.toggleClass('is-invalid', !$siteKey.val().trim());
                    $secretKey.toggleClass('is-invalid', !$secretKey.val().trim());
                    throw new Error(lang('turnstile_keys_missing'));
                }
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
            return;
        }

        const altchaSettings = serialize();

        App.Http.AltchaSettings.save(altchaSettings).done((response) => {
            if (response.success === false) {
                App.Layouts.Backend.displayNotification(response.message || lang('settings_are_invalid'));
                return;
            }

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
