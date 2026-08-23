/**
 * Notification templates: fold and unfold the panels, open or close them all,
 * and mirror the typed title into the panel header. The forms are Rails forms
 * in the notifications frame.
 */
(function () {
    function setFolded($panel, folded) {
        $panel.find('.notification-body').toggle(!folded);
        $panel.find('.notification-header i').attr('class', folded ? 'fas fa-chevron-down' : 'fas fa-chevron-up');
    }

    $(document).on('click', '.notification-header', (event) => {
        const $panel = $(event.currentTarget).closest('.notification-panel');
        setFolded($panel, $panel.find('.notification-body').is(':visible'));
    });

    $(document).on('click', '#toggle-all-notifications', (event) => {
        const $button = $(event.currentTarget);
        const anyFolded = $('.notification-panel').toArray().some((panel) => !$(panel).find('.notification-body').is(':visible'));
        $('.notification-panel').each((index, panel) => setFolded($(panel), !anyFolded));
        $button.text(anyFolded ? $button.data('closeText') : $button.data('openText'));
    });

    $(document).on('input', '.n-title', (event) => {
        const $panel = $(event.target).closest('.notification-panel');
        $panel.find('.notification-title-display').text(event.target.value || lang('notification_untitled'));
    });
})();
