/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * App global namespace object.
 *
 * This script should be loaded before the other modules in order to define the global application namespace.
 */
window.App = (function () {
    function onAjaxError(event, jqXHR, textStatus, errorThrown) {
        console.error('Unexpected HTTP Error: ', jqXHR, textStatus, errorThrown);

        let response;

        try {
            response = JSON.parse(jqXHR.responseText); // JSON response
        } catch (error) {
            response = {message: jqXHR.responseText}; // String response
        }

        if (!response || !response.message) {
            return;
        }

        if (App.Utils.Message) {
            App.Utils.Message.show('OpenAppointments', lang('unexpected_issues_message'));

            $('<div/>', {
                'class': 'card',
                'html': [
                    $('<div/>', {
                        'class': 'card-body overflow-auto',
                        'html': response.message,
                    }),
                ],
            }).appendTo('#message-modal .modal-body');
        }
    }

    $(document).ajaxError(onAjaxError);

    // Scripts load once per session (Turbo Drive) and pages initialise on every
    // turbo:load, so the locale follows the page values each time.
    document.addEventListener('turbo:load', () => {
        if (window.moment) {
            window.moment.locale(vars('language_code'));
        }
    });

    const registered = new Set();

    // Visit counter: turbo:before-render precedes both the head merge (which
    // appends and runs a page's script on its first visit) and turbo:load.
    let visit = 0;
    document.addEventListener('turbo:before-render', () => {
        visit += 1;
    });

    /**
     * Register a page or component initialiser: it runs on every turbo:load,
     * and straight away when its script arrives during a visit, once per visit.
     */
    function page(initialize) {
        let done = -1;
        const run = () => {
            if (done === visit) {
                return;
            }
            done = visit;
            initialize();
        };
        document.addEventListener('turbo:load', run);
        if (document.readyState !== 'loading') {
            run();
        }
    }

    /**
     * Run a registration once per session: document level listeners inside a
     * page initialiser that turbo:load would otherwise add again on every visit.
     */
    function once(key, register) {
        if (registered.has(key)) {
            return;
        }

        registered.add(key);
        register();
    }

    return {
        Components: {},
        Http: {},
        Layouts: {},
        Pages: {},
        Utils: {},
        once,
        page,
    };
})();
