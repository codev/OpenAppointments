/**
 * Tick-box dropdowns (shared/tick_filter partial) for Stylists and Services.
 * All ticks every item, Clear unticks everything, Working (List only) and the
 * items exclude each other. Each change relabels the button, fires
 * "tick-filter:change" on the dropdown and submits the enclosing form, if any.
 */
App.Utils.TickFilter = (function () {
    const ITEMS = 'input[type=checkbox]:not([data-tick])';
    const WORKING = 'input[data-tick=working]';

    function changed($dropdown) {
        const $items = $dropdown.find(ITEMS);
        const ticked = $items.filter(':checked').length;
        const everything = $dropdown.find(WORKING).is(':checked') || ticked === $items.length;
        const label = $dropdown.data('label');

        $dropdown.find('.dropdown-toggle').text(everything ? label : label + ' (' + ticked + ')');
        $dropdown.trigger('tick-filter:change');
        $dropdown.closest('form')[0]?.requestSubmit();
    }

    $(document).on('click', '.tick-filter [data-tick=all]', (event) => {
        const $dropdown = $(event.currentTarget).closest('.tick-filter');
        $dropdown.find(ITEMS).prop('checked', true);
        $dropdown.find(WORKING).prop('checked', false);
        changed($dropdown);
    });

    $(document).on('click', '.tick-filter [data-tick=clear]', (event) => {
        const $dropdown = $(event.currentTarget).closest('.tick-filter');
        $dropdown.find('input[type=checkbox]').prop('checked', false);
        changed($dropdown);
    });

    $(document).on('change', '.tick-filter input[type=checkbox]', (event) => {
        const $input = $(event.currentTarget);
        const $dropdown = $input.closest('.tick-filter');

        if ($input.is(':checked')) {
            $dropdown.find($input.is(WORKING) ? ITEMS : WORKING).prop('checked', false);
        }
        changed($dropdown);
    });

    // The ticked ids of the dropdown with this element id, as numbers.
    function selected(id) {
        return $('#' + id)
            .find(ITEMS + ':checked')
            .toArray()
            .map((input) => Number(input.value));
    }

    // The one ticked id, or undefined when none or several are ticked.
    function single(id) {
        const ids = selected(id);
        return ids.length === 1 ? ids[0] : undefined;
    }

    return {
        selected,
        single,
    };
})();
