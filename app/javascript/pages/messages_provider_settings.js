/**
 * Shared page module of the per-provider messages settings pages.
 *
 * Fields carry data-field attributes; blocks with data-visible-when
 * ("field=value" pairs joined by "&") show only while every rule matches.
 */
App.Pages.MessagesProviderSettings = (function () {
    const $saveSettings = $('#save-settings');

    function fieldValue($field) {
        return $field.is(':checkbox') ? String(Number($field.prop('checked'))) : String($field.val());
    }

    function updateVisibility() {
        $('[data-visible-when]').each((index, el) => {
            const $el = $(el);

            const visible = String($el.data('visible-when'))
                .split('&')
                .every((rule) => {
                    const parts = rule.split('=');

                    return fieldValue($('[data-field="' + parts[0] + '"]')) === parts[1];
                });

            $el.toggle(visible);
        });
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
        App.Http.MessagesSettings.save(vars('provider_save_url'), 'provider_settings', serialize()).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    function initialize() {
        $saveSettings.on('click', onSaveSettingsClick);
        $(document).on('change', '[data-field]', updateVisibility);

        deserialize(vars('provider_settings'));
        updateVisibility();
    }

    /**
     * Register the inbound webhook with the provider's server (SMS Gateway).
     */
    function initializeRegisterWebhook() {
        $('#register-webhook').on('click', (event) => {
            const url = $(event.currentTarget).data('url');

            $.post(App.Utils.Url.siteUrl(url), {csrf_token: vars('csrf_token')}).done(() => {
                App.Layouts.Backend.displayNotification(lang('messages_webhook_registered'));
            });
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);
    document.addEventListener('DOMContentLoaded', initializeRegisterWebhook);


    return {};
})();
