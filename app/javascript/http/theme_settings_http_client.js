/**
 * Theme Settings HTTP client.
 *
 * This module implements the theme settings related HTTP requests.
 */
App.Http.ThemeSettings = (function () {
    /**
     * Save theme settings.
     *
     * @param {Object} themeSettings
     *
     * @return {Object}
     */
    function save(themeSettings) {
        const url = App.Utils.Url.siteUrl('theme_settings/save');

        const data = {
            csrf_token: vars('csrf_token'),
            theme_settings: themeSettings,
        };

        return $.post(url, data);
    }

    return {
        save,
    };
})();
