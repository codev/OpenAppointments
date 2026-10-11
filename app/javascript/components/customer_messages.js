/**
 * Customer conversation panel on the customers page: loads the messages of the
 * displayed customer (#customer-messages[data-customer-id]) after each frame
 * load as chat bubbles, pages older ones in with Load more, sends manual
 * messages over the provider picked in the dropup and marks them read;
 * admins can delete a message. The message box grows with its content; Enter
 * sends, Shift-Enter adds a line.
 */
App.Components.CustomerMessages = (function () {
    const $document = $(document);

    function panel() {
        return $('#customer-messages');
    }

    function customerId() {
        return panel().data('customerId');
    }

    // One message as a chat bubble: incoming on the left, outgoing on the
    // right, coloured by provider (bubble-<channel>), with the time, failure,
    // Mark as read and the admin delete inside at the bottom right.
    function bubbleRow(message) {
        const incoming = message.direction === 'incoming';
        const unread = incoming && !message.read;
        const failed = message.status === 'failed';

        const $when = $('<span/>', {
            'class': 'bubble-when',
            'html': [
                $('<span/>', {
                    'text':
                        message.created_at +
                        (failed ? ' ' + lang('messages_status_failed') + ' - ' + message.channel_label : ''),
                }),
                unread
                    ? $('<a/>', {
                          'href': '#',
                          'class': 'mark-read ms-2',
                          'data-id': message.id,
                          'text': lang('mark_as_read'),
                      })
                    : null,
                vars('role_slug') === App.Layouts.Backend.DB_SLUG_ADMIN
                    ? $('<button/>', {
                          'type': 'button',
                          'class': 'btn btn-link btn-sm p-0 ms-2 text-danger delete-message',
                          'data-id': message.id,
                          'data-unread': unread,
                          'title': lang('delete'),
                          'html': $('<i/>', {'class': 'fas fa-trash-alt'}),
                      })
                    : null,
            ],
        });

        const $bubble = $('<div/>', {
            'class': 'bubble bubble-' + message.channel,
            'title': message.channel_label,
            'html': [
                message.subject ? $('<div/>', {'class': 'bubble-subject', 'text': message.subject}) : null,
                $('<div/>', {'class': 'bubble-body', 'text': message.body}),
                $('<div/>', {'class': 'bubble-meta', 'html': $when}),
            ],
        });

        return $('<div/>', {
            'class': 'bubble-row ' + (incoming ? 'in' : 'out') + (unread ? ' message-unread' : '') + (failed ? ' failed' : ''),
            'data-id': message.id,
            'html': $bubble,
        });
    }

    function loadMoreButton() {
        return $('<button/>', {
            'type': 'button',
            'id': 'load-more-messages',
            'class': 'btn btn-sm btn-light rounded-pill align-self-center',
            'text': lang('load_more_messages'),
        });
    }

    function syncMarkAllRead() {
        $('#mark-all-read').toggleClass('d-none', !panel().find('.message-unread').length);
    }

    function scrollToBottom($panel) {
        $panel.scrollTop($panel[0].scrollHeight);
    }

    // The thread opens on the latest window, scrolled to the newest message.
    function load() {
        const $panel = panel();

        if (!$panel.length) {
            return;
        }

        App.Http.CustomerMessages.find(customerId()).done((response) => {
            $panel.empty();

            if (!response.messages.length) {
                $('<p/>', {'text': lang('no_records_found')}).appendTo($panel);
            }

            if (response.more) {
                loadMoreButton().appendTo($panel);
            }

            $panel.append(response.messages.map(bubbleRow));
            syncMarkAllRead();
            scrollToBottom($panel);

            if ($panel.data('scroll') === true) {
                $panel.data('scroll', false);
                $panel[0].scrollIntoView({behavior: 'smooth', block: 'center'});
                $('#message-body').trigger('focus');
            }
        });
    }

    // Older messages go in above the oldest shown; the scroll offset grows by
    // the added height so what was on screen stays where it is.
    function loadMore() {
        const $panel = panel();
        const $button = $('#load-more-messages');
        const oldestId = $panel.find('.bubble-row').first().data('id');
        const heightBefore = $panel[0].scrollHeight;

        App.Http.CustomerMessages.find(customerId(), oldestId).done((response) => {
            $button.after(response.messages.map(bubbleRow));
            if (!response.more) {
                $button.remove();
            }
            $panel.scrollTop($panel.scrollTop() + $panel[0].scrollHeight - heightBefore);
            syncMarkAllRead();
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

    function confirmDelete(event) {
        const $button = $(event.currentTarget);

        App.Utils.Message.show(lang('delete'), lang('message_delete_confirm'), [
            {text: lang('cancel'), click: (e, modal) => modal.hide()},
            {
                text: lang('delete'),
                click: (e, modal) => {
                    modal.hide();
                    App.Http.CustomerMessages.destroy($button.data('id')).done((response) => {
                        App.Utils.MarkRead.updateHeaderBadge(response.inbox_unread);
                        if ($button.data('unread')) {
                            decreaseUnreadBadge(1);
                        }
                        App.Layouts.Backend.displayNotification(lang('message_deleted'));
                        load();
                    });
                },
            },
        ]);
    }

    // The picker button takes the label and colour of the chosen provider.
    function chooseChannel(event) {
        const $option = $(event.currentTarget);
        const $button = $('#message-channel-button');

        $('#message-channel').val($option.data('value'));
        $button.text($option.text());
        $button.attr('class', 'btn dropdown-toggle h-100 ' + $option.attr('class').replace(/\bdropdown-item\b|\bchannel-option\b/g, '').trim());
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
            fitMessageBox();
            App.Layouts.Backend.displayNotification(lang('message_sent'));
            load();
        });
    }

    // Height follows the text, never below the rows attribute.
    function fitMessageBox() {
        const box = $('#message-body')[0];

        if (!box) {
            return;
        }

        box.style.height = '';
        if (box.scrollHeight > box.clientHeight) {
            box.style.height = box.scrollHeight + box.offsetHeight - box.clientHeight + 'px';
        }
    }

    function initialize() {
        if (!$('#customers-page').length) {
            return;
        }

        App.once('customer-messages', () => {
            $document.on('click', '#send-message', send);
            $document.on('keydown', '#message-body', (event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                    event.preventDefault();
                    send();
                }
            });
            $document.on('input', '#message-body', fitMessageBox);
            $document.on('click', '#mark-all-read', () => {
                App.Http.CustomerMessages.markRead(customerId()).done((response) => {
                    App.Utils.MarkRead.updateHeaderBadge(response.inbox_unread);
                    decreaseUnreadBadge(0);
                    panel().find('.message-unread').removeClass('message-unread').find('.mark-read').remove();
                    $('#mark-all-read').addClass('d-none');
                });
            });
            $document.on('click', '#customer-messages .delete-message', confirmDelete);
            $document.on('click', '#load-more-messages', loadMore);
            $document.on('click', '#customer-message-composer .channel-option', chooseChannel);
            $document.on('click', '#customer-messages .mark-read', () => {
                decreaseUnreadBadge(1);
                if (panel().find('.message-unread').length <= 1) {
                    $('#mark-all-read').addClass('d-none');
                }
            });

            document.addEventListener('turbo:frame-load', load);
        });
        load();
    }

    App.page(initialize);

    return {load};
})();
