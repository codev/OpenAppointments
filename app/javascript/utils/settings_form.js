/**
 * Settings forms (SettingsFormHelper): blocks with data-visible-when="a=1&b=x"
 * show only while the named fields have those values; fields with
 * data-enabled-when are disabled otherwise. Re-evaluated after each change and
 * each Turbo Frame load.
 */
(function () {
    function fieldValue(name) {
        const $field = $('[data-field="' + name + '"]');
        return $field.is(':checkbox') ? String(Number($field.prop('checked'))) : String($field.val());
    }

    function matches(rules) {
        return String(rules)
            .split('&')
            .every((rule) => {
                const [name, value] = rule.split('=');
                return fieldValue(name) === value;
            });
    }

    function update() {
        $('[data-visible-when]').each((index, el) => $(el).toggle(matches($(el).data('visibleWhen'))));
        $('[data-enabled-when]').each((index, el) => $(el).prop('disabled', !matches($(el).data('enabledWhen'))));
    }

    $(document).on('change input', '[data-field]', update);
    document.addEventListener('turbo:frame-load', update);
    document.addEventListener('DOMContentLoaded', update);
})();
