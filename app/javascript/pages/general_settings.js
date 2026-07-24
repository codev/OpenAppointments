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
 * General settings page.
 *
 * This module implements the functionality of the general settings page.
 */
App.Pages.GeneralSettings = (function () {
    const $saveSettings = $('#save-settings');
    const $companyLogo = $('#company-logo');
    const $companyLogoPreview = $('#company-logo-preview');
    const $removeCompanyLogo = $('#remove-company-logo');
    const $companyColor = $('#company-color');
    const $resetCompanyColor = $('#reset-company-color');
    const $secondaryColor = $('#company-secondary-color');
    const $backgroundColor = $('#company-background-color');
    const $theme = $('#theme');
    const $colorAccessibility = $('#color-accessibility');
    let companyLogoBase64 = '';

    /**
     * Check if the form has invalid values.
     *
     * @return {Boolean}
     */
    function isInvalid() {
        try {
            $('#general-settings .is-invalid').removeClass('is-invalid');

            // Validate required fields.

            let missingRequiredFields = false;

            $('#general-settings .required').each((index, requiredField) => {
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

    function deserialize(generalSettings) {
        generalSettings.forEach((generalSetting) => {
            if (generalSetting.name === 'company_logo' && generalSetting.value) {
                companyLogoBase64 = generalSetting.value;
                $companyLogoPreview.attr('src', generalSetting.value);
                $companyLogoPreview.prop('hidden', false);
                $removeCompanyLogo.prop('hidden', false);
                return;
            }

            if (generalSetting.name === 'company_color' && generalSetting.value !== '#ffffff') {
                $resetCompanyColor.prop('hidden', false);
            }

            const $field = $('[data-field="' + generalSetting.name + '"]');

            $field.is(':checkbox')
                ? $field.prop('checked', Boolean(Number(generalSetting.value)))
                : $field.val(generalSetting.value);
        });
    }

    function serialize() {
        const generalSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            generalSettings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        generalSettings.push({
            name: 'company_logo',
            value: companyLogoBase64,
        });

        return generalSettings;
    }

    /**
     * Save the account information.
     */
    function onSaveSettingsClick() {
        if (isInvalid()) {
            App.Layouts.Backend.displayNotification(lang('settings_are_invalid'));
            return;
        }

        const generalSettings = serialize();

        App.Http.GeneralSettings.save(generalSettings).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));

            // Reload so the saved theme and colours take effect immediately.
            setTimeout(() => window.location.reload(), 700);
        });
    }

    /**
     * Convert the selected image to a base64 encoded string.
     */
    function onCompanyLogoChange() {
        const file = $companyLogo[0].files[0];

        if (!file) {
            $removeCompanyLogo.trigger('click');
            return;
        }

        App.Utils.File.toBase64(file).then((base64) => {
            companyLogoBase64 = base64;
            $companyLogoPreview.attr('src', base64);
            $companyLogoPreview.prop('hidden', false);
            $removeCompanyLogo.prop('hidden', false);
        });
    }

    /**
     * Remove the company logo data.
     */
    function onRemoveCompanyLogoClick() {
        companyLogoBase64 = '';
        $companyLogo.val('');
        $companyLogoPreview.attr('src', '#');
        $companyLogoPreview.prop('hidden', true);
        $removeCompanyLogo.prop('hidden', true);
    }

    /**
     * Toggle the reset company color button.
     */
    function onCompanyColorChange() {
        $resetCompanyColor.prop('hidden', $companyColor.val() === '#ffffff');
    }

    /**
     * Set the company color value to "#ffffff" which is the default one.
     */
    function onResetCompanyColorClick() {
        $companyColor.val('#ffffff');
    }

    /**
     * Evaluate the brand colours against WCAG AA and show warnings with
     * suggestions when a pairing is hard to read.
     */
    function evaluateColorAccessibility() {
        if (!$colorAccessibility.length) {
            return;
        }

        const contrast = App.Utils.Contrast;
        const primary = $companyColor.val() || '#39824f';
        const secondary = $secondaryColor.val() || '#dd2a5c';
        const background = $backgroundColor.val() || '#f2f6fa';
        const bodyText = '#212529';

        const checks = [
            {ratio: contrast.ratio('#ffffff', primary), message: lang('contrast_warning_button_text')},
            {ratio: contrast.ratio(primary, background), message: lang('contrast_warning_primary_background')},
            {ratio: contrast.ratio('#ffffff', secondary), message: lang('contrast_warning_secondary')},
            {ratio: contrast.ratio(bodyText, background), message: lang('contrast_warning_body_background')},
        ];

        const warnings = checks.filter((check) => check.ratio < contrast.AA_NORMAL);

        $colorAccessibility.empty();

        if (!warnings.length) {
            $colorAccessibility.append(
                $('<div/>', {'class': 'alert alert-success py-2 small mb-0', 'text': lang('color_contrast_ok')}),
            );
            return;
        }

        const $alert = $('<div/>', {'class': 'alert alert-warning py-2 small mb-0'});

        warnings.forEach((warning) => {
            $alert.append($('<div/>', {'text': warning.message + ' (' + warning.ratio.toFixed(1) + ':1)'}));
        });

        $colorAccessibility.append($alert);
    }

    /**
     * Fill the three colour fields from one of the selected theme's two
     * suggested palettes (buttons carry data-palette 0/1).
     */
    function onApplySuggestedColorsClick(event) {
        const suggestions = vars('theme_suggestions') || {};
        const palettes = suggestions[$theme.val()] || [];
        const suggestion = palettes[Number($(event.currentTarget).data('palette')) || 0];

        if (!suggestion) {
            return;
        }

        $companyColor.val(suggestion.primary);
        $secondaryColor.val(suggestion.secondary);
        $backgroundColor.val(suggestion.background);

        evaluateColorAccessibility();
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);

        $companyLogo.on('change', onCompanyLogoChange);

        $removeCompanyLogo.on('click', onRemoveCompanyLogoClick);

        $companyColor.on('change', onCompanyColorChange);

        $resetCompanyColor.on('click', onResetCompanyColorClick);

        const generalSettings = vars('general_settings');

        deserialize(generalSettings);

        $('.apply-suggested-colors').on('click', onApplySuggestedColorsClick);

        $companyColor.add($secondaryColor).add($backgroundColor).on('input change', evaluateColorAccessibility);

        evaluateColorAccessibility();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
