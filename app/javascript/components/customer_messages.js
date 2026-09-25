/**
 * Customer conversation panel on the customers page: loads the messages of the
 * displayed customer (#customer-messages[data-customer-id]) after each frame
 * load, sends manual messages and marks them read; admins can delete a
 * message. The message box grows with its content; Enter sends, Shift-Enter
 * adds a line.
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
                    panel().find('.message-unread').removeClass('message-unread fw-bold').find('.mark-read').remove();
                    $('#mark-all-read').addClass('d-none');
                });
            });
            $document.on('click', '#customer-messages .delete-message', confirmDelete);
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
