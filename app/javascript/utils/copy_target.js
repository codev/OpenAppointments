/**
 * Copy buttons: .copy-embed-target with data-target copies that field's text.
 */
$(document).on('click', '.copy-embed-target', (event) => {
    const $code = $($(event.currentTarget).data('target'));
    $code.trigger('select');
    navigator.clipboard.writeText($code.val());
});
