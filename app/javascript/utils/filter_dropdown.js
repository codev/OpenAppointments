/**
 * Dropdown button in front of a hidden select (data-filter-for names the select).
 * Picking an item selects the matching option, by value and type since a provider
 * and a service can share an id, and fires the select's change event, so the
 * scripts reading the select are unchanged. The button shows the selected name.
 */
(function () {
    function selectFor($dropdown) {
        return $('#' + $dropdown.data('filterFor'));
    }

    function showSelection($dropdown) {
        const $option = selectFor($dropdown).find('option:selected');
        const value = $option.val();
        const type = $option.attr('type') || '';

        $dropdown.find('.dropdown-toggle').text($option.text().trim());
        $dropdown.find('.dropdown-item').each((index, item) => {
            const $item = $(item);
            const active = String($item.data('value')) === value && ($item.data('type') || '') === type;
            $item.toggleClass('active', active).attr('aria-current', active ? 'true' : null);
        });
    }

    $(document).on('click', '[data-filter-for] .dropdown-item[data-value]', (event) => {
        const $item = $(event.currentTarget);
        const $select = selectFor($item.closest('[data-filter-for]'));
        const type = $item.data('type');
        const typeRule = type ? '[type="' + type + '"]' : ':not([type])';

        $select.find('option[value="' + $item.data('value') + '"]' + typeRule).prop('selected', true);
        $select.trigger('change');
    });

    $(document).on('change', 'select', (event) => {
        $('[data-filter-for="' + event.target.id + '"]').each((index, dropdown) => showSelection($(dropdown)));
    });
})();
