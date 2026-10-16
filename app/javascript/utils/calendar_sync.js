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
 * Calendar sync utility.
 *
 * This module implements the functionality of calendar sync: the Sync button
 * group on the calendar toolbar, and the Enable Sync tab of the Feed dialog,
 * which shows one section at a time (method choice, CalDAV form, Google
 * calendar choice, or the disable option once sync is on).
 *
 * Old Name: BackendCalendarSync
 */
App.Utils.CalendarSync = (function () {
    const $selectFilterItem = () => $('#select-filter-item');
    const $syncPane = () => $('#calendar-sync-pane');
    const feedModal = () => bootstrap.Modal.getOrCreateInstance(document.getElementById('calendar-feed-modal'));
    const $disableSync = () => $('#disable-sync');
    const $triggerSync = () => $('#trigger-sync');
    const $syncButtonGroup = () => $('#sync-button-group');
    const $reloadAppointments = () => $('#reload-appointments');

    const FILTER_TYPE_PROVIDER = 'provider';
    let isSyncing = false;
    let choosingGoogleCalendar = false;

    function hasSync(type) {
        const $selectedOption = $selectFilterItem().find('option:selected');

        return Boolean(Number($selectedOption.attr(`${type}-sync`)));
    }

    function updateSyncButtons() {
        const $selectedOption = $selectFilterItem().find('option:selected');
        const type = $selectedOption.attr('type');
        const isProvider = type === FILTER_TYPE_PROVIDER;
        const hasGoogleSync = Boolean(Number($selectedOption.attr('google-sync')));
        const hasCaldavSync = Boolean(Number($selectedOption.attr('caldav-sync')));
        const hasSync = hasGoogleSync || hasCaldavSync;

        // Check if the logged-in user is a provider viewing their own data
        const isLoggedInProvider = vars('role_slug') === App.Layouts.Backend.DB_SLUG_PROVIDER;
        const selectedProviderId = isProvider ? Number($selectedOption.val()) : null;
        const canManageSync =
            isProvider &&
            (!isLoggedInProvider || // Admins and assistants can manage any provider
                Number(vars('user_id')) === selectedProviderId); // Providers can only manage their own sync

        $syncButtonGroup().prop('hidden', !canManageSync || !hasSync);
    }

    function showSyncSection(id) {
        $syncPane().find('.sync-section').each((index, section) => {
            section.hidden = section.id !== id;
        });
    }

    // The Enable Sync tab's starting section for the stylist in focus. A Google
    // calendar choice in progress is kept, the dialog may have closed during OAuth.
    function resetSyncPane() {
        if (choosingGoogleCalendar) {
            showSyncSection('sync-google-calendar');
        } else if (hasSync('google') || hasSync('caldav')) {
            showSyncSection('sync-disable');
        } else if (vars('google_sync_feature')) {
            showSyncSection('sync-method');
        } else {
            enableCaldavSync();
        }
    }

    function enableGoogleSync() {
        // Enable synchronization for selected provider.

        const authUrl = App.Utils.Url.siteUrl('google/oauth/' + $('#select-filter-item').val());

        const windowHandle = window.open(authUrl, 'Easy!Appointments', 'width=800, height=600');

        // Listen for the postMessage that oauth_callback emits after the token is saved server-side.
        // This avoids the race condition of URL-polling, which fires as soon as the browser starts
        // navigating to oauth_callback — before the server has finished processing the request.
        function onOauthMessage(event) {
            if (event.origin !== window.location.origin || event.data !== 'oauth_success') {
                return;
            }

            window.removeEventListener('message', onOauthMessage);

            if (windowHandle && !windowHandle.closed) {
                windowHandle.close();
            }

            const $selectedOption = $selectFilterItem().find('option:selected');

            $selectedOption.attr('google-sync', '1');

            updateSyncButtons();

            choosingGoogleCalendar = true;
            selectGoogleCalendar();
            if (!$('#calendar-feed-modal').hasClass('show')) {
                bootstrap.Tab.getOrCreateInstance(document.getElementById('calendar-sync-tab')).show();
                feedModal().show();
            }
        }

        window.addEventListener('message', onOauthMessage);
    }

    function selectedProvider() {
        const providerId = $selectFilterItem().val();
        const provider = App.Utils.CalendarEvents.findProvider(providerId);

        if (!provider) {
            throw new Error('Provider not found: ' + providerId);
        }

        return provider;
    }

    function disableGoogleSync() {
        const provider = selectedProvider();

        provider.settings.google_sync = '0';
        provider.settings.google_token = null;

        App.Http.Google.disableProviderSync(provider.id);

        $selectFilterItem().find('option:selected').attr('google-sync', '0');

        updateSyncButtons();
    }

    function selectGoogleCalendar() {
        const providerId = $selectFilterItem().val();

        App.Http.Google.getGoogleCalendars(providerId).done((googleCalendars) => {
            const $selectGoogleCalendar = $('#google-calendar').empty();

            googleCalendars.forEach((googleCalendar) => {
                $selectGoogleCalendar.append(new Option(googleCalendar.summary, googleCalendar.id));
            });

            showSyncSection('sync-google-calendar');
        });
    }

    function onGoogleSelectClick() {
        const providerId = $selectFilterItem().val();
        const googleCalendarId = $('#google-calendar').val();

        App.Http.Google.selectGoogleCalendar(providerId, googleCalendarId).done(() => {
            App.Layouts.Backend.displayNotification(lang('sync_calendar_selected'));
        });

        choosingGoogleCalendar = false;
        feedModal().hide();
    }

    function triggerGoogleSync() {
        const providerId = $selectFilterItem().val();

        App.Http.Google.syncWithGoogle(providerId)
            .done(() => {
                App.Layouts.Backend.displayNotification(lang('calendar_sync_completed'));
                $reloadAppointments().trigger('click');
            })
            .fail((jqXHR) => {
                const serverMessage = jqXHR.responseJSON && jqXHR.responseJSON.message;

                let message = lang('calendar_sync_failed');

                if (jqXHR.status === 401) {
                    message = lang('invalid_credentials_provided');
                } else if (serverMessage) {
                    message += ' ' + serverMessage;
                }

                App.Layouts.Backend.displayNotification(message);
            })
            .always(() => {
                isSyncing = false;
            });
    }

    function enableCaldavSync() {
        const $section = $('#sync-caldav');

        $section.find('input').val('').removeClass('is-invalid');
        $section.find('.alert').text('').prop('hidden', true);

        showSyncSection('sync-caldav');
    }

    function onCaldavConnectClick() {
        const $section = $('#sync-caldav');
        const providerId = $selectFilterItem().val();

        $section.find('.is-invalid').removeClass('is-invalid');

        const $alert = $section.find('.alert');
        $alert.text('').prop('hidden', true);

        const $caldavUrl = $('#caldav-url');
        const caldavUrl = $caldavUrl.val();

        if (!caldavUrl) {
            $caldavUrl.addClass('is-invalid');
            return;
        }

        const $caldavUsername = $('#caldav-username');
        const caldavUsername = $caldavUsername.val();

        if (!caldavUsername) {
            $caldavUsername.addClass('is-invalid');
            return;
        }

        const $caldavPassword = $('#caldav-password');
        const caldavPassword = $caldavPassword.val();

        if (!caldavPassword) {
            $caldavPassword.addClass('is-invalid');
            return;
        }

        App.Http.Caldav.connectToServer(providerId, caldavUrl, caldavUsername, caldavPassword).done((response) => {
            if (!response.success) {
                $caldavUrl.addClass('is-invalid');
                $caldavUsername.addClass('is-invalid');
                $caldavPassword.addClass('is-invalid');

                $alert.text(lang('login_failed') + ' ' + response.message).prop('hidden', false);

                return;
            }

            $selectFilterItem().find('option:selected').attr('caldav-sync', '1');

            updateSyncButtons();

            App.Layouts.Backend.displayNotification(lang('sync_calendar_selected'));

            feedModal().hide();
        });
    }

    function disableCaldavSync() {
        const provider = selectedProvider();

        provider.settings.caldav_sync = '0';
        provider.settings.caldav_url = null;
        provider.settings.caldav_username = null;
        provider.settings.caldav_password = null;

        App.Http.Caldav.disableProviderSync(provider.id);

        $selectFilterItem().find('option:selected').attr('caldav-sync', '0');

        updateSyncButtons();
    }

    function triggerCaldavSync() {
        const providerId = $selectFilterItem().val();

        App.Http.Caldav.syncWithCaldav(providerId)
            .done(() => {
                App.Layouts.Backend.displayNotification(lang('calendar_sync_completed'));
                $reloadAppointments().trigger('click');
            })
            .fail((jqXHR) => {
                const serverMessage = jqXHR.responseJSON && jqXHR.responseJSON.message;

                let message = lang('calendar_sync_failed');

                if (jqXHR.status === 401) {
                    message = lang('invalid_credentials_provided');
                } else if (serverMessage) {
                    message += ' ' + serverMessage;
                }

                App.Layouts.Backend.displayNotification(message);
            })
            .always(() => {
                isSyncing = false;
            });
    }

    function onSelectFilterItemChange() {
        updateSyncButtons();
    }

    function disableSync() {
        choosingGoogleCalendar = false;
        if (hasSync('google')) {
            disableGoogleSync();
            return;
        }

        if (hasSync('caldav')) {
            disableCaldavSync();
        }
    }

    // The toolbar menu item asks first; the Enable Sync tab already shows the prompt.
    function onDisableSyncClick() {
        App.Utils.Message.show(lang('disable_sync'), lang('disable_sync_prompt'), [
            {
                text: lang('cancel'),
                click: (event, messageModal) => {
                    messageModal.hide();
                },
            },
            {
                text: lang('confirm'),
                click: (event, messageModal) => {
                    disableSync();
                    messageModal.hide();
                },
            },
        ]);
    }

    function onDisableConfirmClick() {
        disableSync();
        feedModal().hide();
    }

    function onTriggerSyncClick() {
        const hasGoogleSync = hasSync('google');
        isSyncing = true;

        if (hasGoogleSync) {
            triggerGoogleSync();
            return;
        }

        const hasCalSync = hasSync('caldav');

        if (hasCalSync) {
            triggerCaldavSync();
        }
    }

    function isCurrentlySyncing() {
        return isSyncing;
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        if (!$selectFilterItem().length) {
            return;
        }

        $selectFilterItem().on('change', onSelectFilterItemChange);
        $disableSync().on('click', onDisableSyncClick);
        $('#calendar-feed-modal').on('show.bs.modal', resetSyncPane);
        $('#sync-method-caldav').on('click', enableCaldavSync);
        $('#sync-method-google').on('click', enableGoogleSync);
        $('#sync-caldav-connect').on('click', onCaldavConnectClick);
        $('#sync-google-select').on('click', onGoogleSelectClick);
        $('#sync-disable-confirm').on('click', onDisableConfirmClick);
        $triggerSync().on('click', onTriggerSyncClick);
        updateSyncButtons();
    }

    App.page(initialize);

    return {
        initialize,
        isCurrentlySyncing,
    };
})();
