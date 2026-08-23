/**
 * Settings forms (SettingsFormHelper): blocks with data-visible-when="a=1&b=x"
 * show only while the named fields have those values; fields with
 * data-enabled-when are disabled otherwise; textarea.rich-text gets the
 * Trumbowyg editor. Re-evaluated after each change and each Turbo Frame load.
 */
(function () {
    // Fields are looked up within the element's form, so a page can hold several.
    function fieldValue(name, $scope) {
        const $field = $scope.find('[data-field="' + name + '"]').first();
        return $field.is(':checkbox') ? String(Number($field.prop('checked'))) : String($field.val());
    }

    function matches(el, rules) {
        const $scope = $(el).closest('form').length ? $(el).closest('form') : $(document);
        return String(rules)
            .split('&')
            .every((rule) => {
                const [name, value] = rule.split('=');
                return fieldValue(name, $scope) === value;
            });
    }

    function update() {
        $('[data-visible-when]').each((index, el) => $(el).toggle(matches(el, $(el).data('visibleWhen'))));
        $('[data-enabled-when]').each((index, el) => $(el).prop('disabled', !matches(el, $(el).data('enabledWhen'))));
        $('textarea.rich-text:not(.trumbowyg-textarea)').trumbowyg();
    }

    $(document).on('change input', '[data-field]', update);
    document.addEventListener('turbo:frame-load', update);
    document.addEventListener('DOMContentLoaded', update);
})();
