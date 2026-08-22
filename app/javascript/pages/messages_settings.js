/**
 * Messages settings page (global switch, retention, email subject).
 */
App.Pages.MessagesSettings = (function () {
    const $saveSettings = $('#save-settings');
    const $failureAlert = $('#messages-failure-alert');
    const $failureEmails = $('#messages-failure-alert-emails');

    function toggleFailureEmails() {
        $failureEmails.prop('disabled', !$failureAlert.prop('checked'));
    }

    /**
     * The report list must be valid addresses when reports are on.
     */
    function validate() {
        $failureEmails.removeClass('is-invalid');

        if (!$failureAlert.prop('checked')) {
            return true;
        }

        const emails = $failureEmails
            .val()
            .split(/[\s,;]+/)
            .filter((email) => email.length);

        if (emails.length && emails.every((email) => App.Utils.Validation.email(email))) {
            return true;
        }

        $failureEmails.addClass('is-invalid');
        App.Layouts.Backend.displayNotification(lang('invalid_email'));
        return false;
    }

    function deserialize(rows) {
        rows.forEach((row) => {
            const $field = $('[data-field="' + row.name + '"]');

            $field.is(':checkbox') ? $field.prop('checked', Boolean(Number(row.value))) : $field.val(row.value);
        });
    }

    function serialize() {
        const rows = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            rows.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        return rows;
    }

    function onSaveSettingsClick() {
        if (!validate()) {
            return;
        }

        App.Http.MessagesSettings.save('messages_settings/save', 'messages_settings', serialize()).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);

        deserialize(vars('messages_settings'));
        toggleFailureEmails();
        $failureAlert.on('change', toggleFailureEmails);
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
