/**
 * Messages notifications page.
 *
 * Renders one foldable panel per notification template from the
 * #notification-panel-template markup.
 */
App.Pages.MessagesNotifications = (function () {
    const $list = $('#notifications-list');
    const $addNotification = $('#add-notification');
    const $toggleAll = $('#toggle-all-notifications');

    let panelCounter = 0;

    function untitled() {
        return lang('notification_untitled');
    }

    function createPanel(notification) {
        const html = $('#notification-panel-template').html().replace(/__INDEX__/g, String(panelCounter));

        panelCounter += 1;

        const $panel = $(html);

        $panel.data('id', notification.id || null);

        $panel.find('.n-field').each((index, field) => {
            const $field = $(field);
            const value = notification[$field.data('name')];

            if (value !== undefined && value !== null) {
                $field.val(String(value));
            }
        });

        // The day_at days selector shares the lead_days value with the before mode.
        $panel.find('.day-at-days').val(String(notification.lead_days || 0));

        (notification.audiences || []).forEach((audience) => {
            $panel.find('.n-audience[value="' + audience + '"]').prop('checked', true);
        });

        (notification.channels || []).forEach((channel) => {
            $panel.find('.n-channel[value="' + channel + '"]').prop('checked', true);
        });

        updateTitleDisplay($panel);
        updateComingUpBlocks($panel);

        $list.append($panel);

        return $panel;
    }

    function updateTitleDisplay($panel) {
        const title = $panel.find('[data-name="title"]').val();

        $panel.find('.notification-title-display').text(title || untitled());
    }

    function updateComingUpBlocks($panel) {
        const comingUp = $panel.find('[data-name="event"]').val() === 'coming_up';

        $panel.find('.coming-up-block').toggle(comingUp);

        const dayAt = $panel.find('[data-name="lead_mode"]').val() === 'day_at';

        $panel.find('.lead-before-block').toggle(!dayAt);
        $panel.find('.lead-day-at-block').toggle(dayAt);
    }

    function setFolded($panel, folded) {
        $panel.find('.notification-body').toggle(!folded);
        $panel.find('.notification-header i').attr('class', folded ? 'fas fa-chevron-down' : 'fas fa-chevron-up');
    }

    function isFolded($panel) {
        return !$panel.find('.notification-body').is(':visible');
    }

    function serialize($panel) {
        const notification = {
            id: $panel.data('id') || '',
            audiences: [],
            channels: [],
        };

        $panel.find('.n-field').each((index, field) => {
            const $field = $(field);

            notification[$field.data('name')] = $field.val();
        });

        if (notification.lead_mode === 'day_at') {
            notification.lead_days = $panel.find('.day-at-days').val();
            notification.lead_hours = '0';
        }

        $panel.find('.n-audience:checked').each((index, box) => {
            notification.audiences.push($(box).val());
        });

        $panel.find('.n-channel:checked').each((index, box) => {
            notification.channels.push($(box).val());
        });

        return notification;
    }

    function onSaveClick(event) {
        const $panel = $(event.target).closest('.notification-panel');
        const notification = serialize($panel);

        if (!notification.title) {
            App.Layouts.Backend.displayNotification(lang('fields_are_required'));

            return;
        }

        App.Http.MessagesNotifications.save(notification).done((response) => {
            if (response.success === false) {
                App.Layouts.Backend.displayNotification(response.message);

                return;
            }

            $panel.data('id', response.id);
            updateTitleDisplay($panel);
            App.Layouts.Backend.displayNotification(lang('notification_saved'));
        });
    }

    function onDeleteClick(event) {
        const $panel = $(event.target).closest('.notification-panel');
        const id = $panel.data('id');

        if (!id) {
            $panel.remove();

            return;
        }

        const buttons = [
            {
                text: lang('cancel'),
                click: (clickEvent, messageModal) => {
                    messageModal.hide();
                },
            },
            {
                text: lang('delete'),
                className: 'btn btn-danger',
                click: (clickEvent, messageModal) => {
                    App.Http.MessagesNotifications.destroy(id).done(() => {
                        $panel.remove();
                        messageModal.hide();
                    });
                },
            },
        ];

        App.Utils.Message.show(lang('delete_notification'), lang('delete_record_prompt'), buttons);
    }

    function onToggleAllClick() {
        const $panels = $list.find('.notification-panel');
        const opening = $toggleAll.text().trim() === $toggleAll.data('open-text');

        $panels.each((index, panel) => {
            setFolded($(panel), !opening);
        });

        $toggleAll.text(opening ? $toggleAll.data('close-text') : $toggleAll.data('open-text'));
    }

    function initialize() {
        vars('notifications').forEach((notification) => {
            const $panel = createPanel(notification);

            setFolded($panel, true);
        });

        $addNotification.on('click', () => {
            const $panel = createPanel({
                event: 'created_or_updated',
                lead_mode: 'before',
                lead_days: 0,
                lead_hours: 1,
                send_time: '08:00',
                audiences: ['customer'],
                channels: [],
            });

            setFolded($panel, false);
            $panel.find('[data-name="title"]').trigger('focus');
        });

        $toggleAll.on('click', onToggleAllClick);

        $list.on('click', '.notification-header', (event) => {
            const $panel = $(event.target).closest('.notification-panel');

            setFolded($panel, !isFolded($panel));
        });

        $list.on('input', '[data-name="title"]', (event) => {
            updateTitleDisplay($(event.target).closest('.notification-panel'));
        });

        $list.on('change', '[data-name="event"], [data-name="lead_mode"]', (event) => {
            updateComingUpBlocks($(event.target).closest('.notification-panel'));
        });

        $list.on('click', '.save-notification', onSaveClick);
        $list.on('click', '.delete-notification', onDeleteClick);
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
