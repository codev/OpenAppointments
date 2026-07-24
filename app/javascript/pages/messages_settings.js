/**
 * Messages settings page (global switch, retention, email subject).
 */
App.Pages.MessagesSettings = (function () {
    const $saveSettings = $('#save-settings');

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
        App.Http.MessagesSettings.save('messages_settings/save', 'messages_settings', serialize()).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);

        deserialize(vars('messages_settings'));
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
