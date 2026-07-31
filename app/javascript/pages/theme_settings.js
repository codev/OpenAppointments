/**
 * Theme settings page.
 *
 * Theme choice, brand colours, suggested palettes and the live WCAG
 * accessibility check (split out of the general settings page).
 */
App.Pages.ThemeSettings = (function () {
    const $saveSettings = $('#save-settings');
    const $companyColor = $('#company-color');
    const $secondaryColor = $('#company-secondary-color');
    const $backgroundColor = $('#company-background-color');
    const $theme = $('#theme');
    const $colorAccessibility = $('#color-accessibility');
    const $themeCards = $('#theme-cards');

    let previewRefreshTimeout;

    function previewUrl(theme) {
        const query = new URLSearchParams({
            theme: theme,
            primary: $companyColor.val() || '',
            secondary: $secondaryColor.val() || '',
            background: $backgroundColor.val() || '',
        });

        return App.Utils.Url.siteUrl('theme_settings/preview') + '?' + query.toString();
    }

    /**
     * Reload every theme card preview with the current colour picks (debounced).
     */
    function refreshThemePreviews() {
        clearTimeout(previewRefreshTimeout);
        previewRefreshTimeout = setTimeout(() => {
            $themeCards.find('.theme-preview-frame').each((index, frame) => {
                frame.src = previewUrl($(frame).data('theme'));
            });
        }, 250);
    }

    function markSelectedThemeCard() {
        $themeCards
            .find('.theme-card')
            .removeClass('selected')
            .filter('[data-theme="' + $theme.val() + '"]')
            .addClass('selected');
    }

    function onThemeCardSelect(event) {
        $theme.val($(event.currentTarget).data('theme'));
        markSelectedThemeCard();
    }

    function deserialize(themeSettings) {
        themeSettings.forEach((themeSetting) => {
            $('[data-field="' + themeSetting.name + '"]').val(themeSetting.value);
        });
    }

    function serialize() {
        const themeSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            themeSettings.push({
                name: $field.data('field'),
                value: $field.val(),
            });
        });

        return themeSettings;
    }

    /**
     * Save the theme settings.
     */
    function onSaveSettingsClick() {
        App.Http.ThemeSettings.save(serialize()).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));

            // Reload so the saved theme and colours take effect immediately.
            setTimeout(() => window.location.reload(), 700);
        });
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
        refreshThemePreviews();
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);

        deserialize(vars('theme_settings'));

        $('.apply-suggested-colors').on('click', onApplySuggestedColorsClick);

        $companyColor
            .add($secondaryColor)
            .add($backgroundColor)
            .on('input change', () => {
                evaluateColorAccessibility();
                refreshThemePreviews();
            });

        $themeCards.on('click', '.theme-card', onThemeCardSelect);
        $themeCards.on('keydown', '.theme-card', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                onThemeCardSelect(event);
            }
        });

        evaluateColorAccessibility();
        markSelectedThemeCard();
        refreshThemePreviews();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
