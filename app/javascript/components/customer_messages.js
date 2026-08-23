/**
 * Customer conversation panel on the customers page: loads the messages of the
 * displayed customer (#customer-messages[data-customer-id]) after each frame
 * load, sends manual messages and marks them read. Extracted from the old
 * pages/customers.js.
 */
App.Components.CustomerMessages = (function () {
    const $document = $(document);

    function panel() {
        return $('#customer-messages');
    }

    function customerId() {
        return panel().data('customerId');
    }

    function appendMessage(message) {
        const incoming = message.direction === 'incoming';
        const unread = incoming && !message.read;

        $('<div/>', {
            'class': 'message-row mb-2 pb-2 border-bottom' + (unread ? ' message-unread fw-bold' : ''),
            'html': [
                $('<i/>', {
                    'class': incoming ? 'fas fa-arrow-down text-success me-1' : 'fas fa-arrow-up text-primary me-1',
                }),
                $('<span/>', {'class': 'badge bg-secondary me-1', 'text': message.channel_label}),
                $('<small/>', {
                    'class': 'text-muted',
                    'text': message.created_at + (message.status === 'failed' ? ' - ' + lang('messages_status_failed') : ''),
                }),
                unread
                    ? $('<button/>', {
                          'type': 'button',
                          'class': 'btn btn-link btn-sm p-0 ms-2 mark-read',
                          'data-id': message.id,
                          'text': lang('mark_as_read'),
                      })
                    : null,
                $('<br/>'),
                $('<small/>', {'text': message.body}),
            ],
        }).appendTo(panel());
    }

    function load() {
        const $panel = panel();

        if (!$panel.length) {
            return;
        }

        App.Http.CustomerMessages.find(customerId()).done((messages) => {
            $panel.empty();

            if (!messages.length) {
                $('<p/>', {'text': lang('no_records_found')}).appendTo($panel);
            }

            messages.forEach(appendMessage);
            $('#mark-all-read').toggleClass('d-none', !messages.some((message) => !message.read));

            if ($panel.data('scroll') === true) {
                $panel.data('scroll', false);
                $panel[0].scrollIntoView({behavior: 'smooth', block: 'center'});
                $('#message-body').trigger('focus');
            }
        });
    }

    // Drop the unread badge of the customer in the list by the given amount (all when 0).
    function decreaseUnreadBadge(amount) {
        const $badge = $('#filter-customers .entry[data-id="' + customerId() + '"] .unread-badge');
        const remaining = Math.max((Number($badge.text()) || 0) - amount, 0);

        if (!amount || !remaining) {
            $badge.remove();
        } else {
            $badge.text(remaining);
        }
    }

    function send() {
        const channel = $('#message-channel').val();
        const body = $('#message-body').val().trim();

        if (!body) {
            return;
        }

        if (!channel) {
            App.Layouts.Backend.displayNotification(lang('select_one'));
            return;
        }

        App.Http.CustomerMessages.send(customerId(), channel, body).done((response) => {
            if (response.success === false) {
                App.Layouts.Backend.displayNotification(response.message);
                return;
            }

            $('#message-body').val('');
            App.Layouts.Backend.displayNotification(lang('message_sent'));
            load();
        });
    }

    function initialize() {
        if (!$('#customers-page').length) {
            return;
        }

        $document.on('click', '#send-message', send);
        $document.on('keydown', '#message-body', (event) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                send();
            }
        });
        $document.on('click', '#mark-all-read', () => {
            App.Http.CustomerMessages.markRead(customerId()).done((response) => {
                App.Utils.MarkRead.updateHeaderBadge(response.inbox_unread);
                decreaseUnreadBadge(0);
                panel().find('.message-unread').removeClass('message-unread fw-bold').find('.mark-read').remove();
                $('#mark-all-read').addClass('d-none');
            });
        });
        $document.on('click', '#customer-messages .mark-read', () => {
            decreaseUnreadBadge(1);
            if (panel().find('.message-unread').length <= 1) {
                $('#mark-all-read').addClass('d-none');
            }
        });

        document.addEventListener('turbo:frame-load', load);
        load();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {load};
})();
