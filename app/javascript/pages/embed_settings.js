/**
 * Embed settings page.
 *
 * Saves the embedding toggle/origin and copies the embed code.
 */
App.Pages.EmbedSettings = (function () {
    function deserialize(settings) {
        settings.forEach((setting) => {
            const $field = $('[data-field="' + setting.name + '"]');

            if ($field.is(':checkbox')) {
                $field.prop('checked', Boolean(Number(setting.value)));
            } else {
                $field.val(setting.value);
            }
        });
    }

    function serialize() {
        const settings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            settings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        return settings;
    }

    function initialize() {
        deserialize(vars('embed_settings'));

        $('#save-embed-settings').on('click', () => {
            $.post(App.Utils.Url.siteUrl('embed_settings/save'), {
                csrf_token: vars('csrf_token'),
                embed_settings: serialize(),
            }).done(() => {
                App.Layouts.Backend.displayNotification(lang('settings_saved'));
            });
        });

        $('#copy-embed-code').on('click', () => {
            const $code = $('#embed-code');
            $code.trigger('select');
            navigator.clipboard.writeText($code.val());
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
