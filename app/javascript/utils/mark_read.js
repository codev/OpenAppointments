/**
 * Mark as read links (.mark-read with data-id) on the customer conversation.
 * Also keeps the header Inbox count (messages not yet done) in step with
 * responses that carry it.
 */
App.Utils.MarkRead = (function () {
    // The count stands in for the Inbox icon while there is anything to do.
    function updateHeaderBadge(count) {
        $('#inbox-count').text(count).toggleClass('d-none', !count);
        $('#inbox-icon').toggleClass('d-none', !!count);
    }

    function markRead(messageId) {
        return $.post(App.Utils.Url.siteUrl('messages/' + messageId + '/mark_read'), {
            csrf_token: vars('csrf_token'),
        }).done((response) => updateHeaderBadge(response.inbox_count));
    }

    function onMarkReadClick(event) {
        const $button = $(event.currentTarget);
        const $row = $button.closest('.message-unread');

        event.preventDefault();
        $button.addClass('pe-none');
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
