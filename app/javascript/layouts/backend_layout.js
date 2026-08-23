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
 * Backend layout.
 *
 * This module implements the backend layout functionality.
 */
window.App.Layouts.Backend = (function () {
    const $selectLanguage = () => $('#select-language');
    const $notification = () => $('#notification');
    const $loading = () => $('#loading');
    const $footer = () => $('#footer');

    const DB_SLUG_ADMIN = 'admin';
    const DB_SLUG_PROVIDER = 'provider';
    const DB_SLUG_ASSISTANT = 'assistant';
    const DB_SLUG_CUSTOMER = 'customer';

    const PRIV_VIEW = 1;
    const PRIV_ADD = 2;
    const PRIV_EDIT = 4;
    const PRIV_DELETE = 8;

    const PRIV_APPOINTMENTS = 'appointments';
    const PRIV_CUSTOMERS = 'customers';
    const PRIV_SERVICES = 'services';
    const PRIV_USERS = 'users';
    const PRIV_SYSTEM_SETTINGS = 'system_settings';
    const PRIV_USER_SETTINGS = 'user_settings';

    /**
     * Display backend notifications to user.
     *
     * Using this method you can display notifications to the use with custom messages. If the 'actions' array is
     * provided then an action link will be displayed too.
     *
     * @param {String} message Notification message
     * @param {Array} [actions] An array with custom actions that will be available to the user. Every array item is an
     * object that contains the 'label' and 'function' key values.
     */
    function displayNotification(message, actions = []) {
        if (!message) {
            return;
        }

        const $toast = $(`
            <div class="toast bg-dark d-flex align-items-center fade show position-fixed p-1 m-4 bottom-0 end-0 backend-notification" role="alert" aria-live="assertive" aria-atomic="true">
                <div class="toast-body w-100 text-white">
                    ${message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2" data-bs-dismiss="toast" aria-label="Close"></button>
            </div>
        `).appendTo('body');

        actions.forEach(function (action) {
            $('<button/>', {
                class: 'btn btn-light btn-sm ms-2',
                text: action.label,
                on: {
                    click: action.function,
                },
            }).prependTo($toast);
        });

        const toast = new bootstrap.Toast($toast[0]);

        toast.show();

        setTimeout(() => {
            toast.dispose();
            $toast.remove();
        }, 5000);
    }

    /**
     * Warn before leaving a form edited since its last save (settings, account,
     * a record form). Turbo visits ask through the app dialog; a full navigation
     * gets the browser's own (its text cannot be customised).
     */
    let settingsDirty = false;

    function unsaved() {
        return settingsDirty;
    }

    function guardUnsavedChanges() {
        $(document).on('input change', '#settings-form :input, #account-form :input, .crud-form :input', () => {
            settingsDirty = true;
        });

        $(document).on('submit', '#settings-form, #account-form, .crud-form', () => {
            settingsDirty = false;
        });

        document.addEventListener('turbo:load', () => {
            settingsDirty = false;
        });

        document.addEventListener('turbo:before-visit', (event) => {
            if (!unsaved()) {
                return;
            }

            event.preventDefault();
            App.Utils.Message.show(lang('settings'), lang('unsaved_changes_prompt'), [
                {text: lang('cancel'), click: (e, modal) => modal.hide()},
                {
                    text: lang('leave_page'),
                    click: (e, modal) => {
                        modal.hide();
                        settingsDirty = false;
                        Turbo.visit(event.detail.url);
                    },
                },
            ]);
        });

        window.addEventListener('beforeunload', (event) => {
            if (unsaved()) {
                event.preventDefault();
                event.returnValue = '';
            }
        });
    }

    /**
     * Session wide listeners once; per page: tooltips and the language menu.
     */
    function initialize() {
        App.once('backend-layout', () => {
            guardUnsavedChanges();
            $(document).ajaxStart(() => $loading().show());
            $(document).ajaxStop(() => $loading().hide());
        });

        tippy('[data-tippy-content]');
        App.Utils.Lang.enableLanguageSelection($selectLanguage());
    }

    document.addEventListener('turbo:load', initialize);

    return {
        DB_SLUG_ADMIN,
        DB_SLUG_PROVIDER,
        DB_SLUG_ASSISTANT,
        DB_SLUG_CUSTOMER,
        PRIV_VIEW,
        PRIV_ADD,
        PRIV_EDIT,
        PRIV_DELETE,
        PRIV_APPOINTMENTS,
        PRIV_CUSTOMERS,
        PRIV_SERVICES,
        PRIV_USERS,
        PRIV_SYSTEM_SETTINGS,
        PRIV_USER_SETTINGS,
        displayNotification,
    };
})();
