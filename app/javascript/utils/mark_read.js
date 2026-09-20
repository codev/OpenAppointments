/**
 * Mark as read buttons (.mark-read with data-id) on the inbox pages and the
 * customer conversation. Updates the header unread badge from the response.
 */
App.Utils.MarkRead = (function () {
    function updateHeaderBadge(count) {
        const $badge = $('#inbox-unread');
        $badge.text(count).prop('hidden', !count);
    }

    function markRead(messageId) {
        return $.post(App.Utils.Url.siteUrl('messages/' + messageId + '/mark_read'), {
            csrf_token: vars('csrf_token'),
        }).done((response) => updateHeaderBadge(response.inbox_unread));
    }

    function onMarkReadClick(event) {
        const $button = $(event.currentTarget);
        const $row = $button.closest('.message-unread');

        $button.prop('disabled', true);
        markRead($button.data('id')).done(() => {
            $row.removeClass('message-unread fw-bold');
            $button.replaceWith($('<i/>', {class: 'fas fa-check text-success', title: lang('read')}));
        });
    }

    $(document).on('click', '.mark-read', onMarkReadClick);

    return {
        markRead,
        updateHeaderBadge,
    };
})();
