/**
 * Notification templates: fold and unfold the panels, open or close them all,
 * mirror the typed title into the panel header, mark unsaved panels, and insert
 * tokens. The forms are Rails forms in the notifications frame.
 */
(function () {
    function setFolded($panel, folded) {
        $panel.find('.notification-body').toggle(!folded);
        $panel.find('.notification-chevron').attr('class', `fas fa-chevron-${folded ? 'down' : 'up'} notification-chevron`);
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

    // A token button inserts at the cursor of the panel's last used text field;
    // before any field was used it copies the token instead.
    const TEXT_FIELDS = "input[name='notification[short_text]'], textarea[name='notification[long_text]']";

    $(document).on('focusin', TEXT_FIELDS, (event) => {
        $(event.target).closest('.notification-panel').data('lastField', event.target);
    });

    // The Clipboard API needs a secure context; plain http (dev) copies through
    // a hidden textarea instead.
    function copyText(text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
            return;
        }
        const $area = $('<textarea>').val(text).css({position: 'fixed', opacity: 0}).appendTo('body');
        $area.trigger('select');
        document.execCommand('copy');
        $area.remove();
    }

    $(document).on('click', '.notification-token', (event) => {
        const token = $(event.currentTarget).data('token');
        const field = $(event.currentTarget).closest('.notification-panel').data('lastField');
        if (!field) {
            copyText(token);
            App.Layouts.Backend.displayNotification(lang('token_copied').replace('{token}', token));
            return;
        }
        const start = field.selectionStart;
        field.value = field.value.slice(0, start) + token + field.value.slice(field.selectionEnd);
        field.focus();
        field.setSelectionRange(start + token.length, start + token.length);
        $(field).trigger('input');
    });

    // The Unsaved marker shows from the first edit; a save re-renders the panel without it.
    $(document).on('input change', '.notification-form :input', (event) => {
        $(event.target).closest('.notification-panel').find('.notification-unsaved').show();
    });

    $(document).on('input', '.n-title', (event) => {
        const $panel = $(event.target).closest('.notification-panel');
        $panel.find('.notification-title-display').text(event.target.value || lang('notification_untitled'));
    });
})();
