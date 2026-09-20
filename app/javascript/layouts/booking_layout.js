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
 * Booking layout.
 *
 * This module implements the booking layout functionality.
 */
window.App.Layouts.Booking = (function () {
    const $selectLanguage = $('#select-language');

    /**
     * Initialize the module.
     */
    // The consent banner, whose link opens the cookie notice modal (rendered
    // by the layout only when the notice is on).
    function initializeCookieNotice() {
        if (!$('#cookie-notice-modal').length || !window.cookieconsent) {
            return;
        }

        cookieconsent.initialise({
            palette: {
                popup: {background: '#ffffffbd', text: '#666666'},
                button: {background: '#429a82', text: '#ffffff'},
            },
            content: {
                message: lang('website_using_cookies_to_ensure_best_experience'),
                dismiss: 'OK',
            },
        });

        const $link = $('.cc-link');
        $link.replaceWith(
            $('<a/>', {
                'data-dialog-open': 'cookie-notice-modal',
                'href': '#',
                'class': 'cc-link',
                'text': $link.text(),
            }),
        );
    }

    function initialize() {
        App.Utils.Lang.enableLanguageSelection($selectLanguage);
        initializeCookieNotice();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
