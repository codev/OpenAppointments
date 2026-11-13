/**
 * Feed button on the calendar page: shown when a provider is selected (any
 * provider for editors, only themselves for a provider). Opens the Feed dialog
 * on its Calendar Feed tab with the subscription link from calendar/feed_link;
 * reset makes a new one. The window (days back and ahead) arrives with the link
 * and saves through calendar/feed_window.
 */
App.Utils.CalendarFeed = (function () {
    const $filter = () => $('#select-filter-item');
    const $button = () => $('#calendar-feed');
    const $link = () => $('#calendar-feed-link');
    const modal = () => bootstrap.Modal.getOrCreateInstance(document.getElementById('calendar-feed-modal'));

    function selectedProviderId() {
        const $option = $filter().find('option:selected');
        return $option.attr('type') === 'provider' ? Number($option.val()) : null;
    }

    function canManage(providerId) {
        if (!providerId) {
            return false;
        }
        const isProvider = vars('role_slug') === App.Layouts.Backend.DB_SLUG_PROVIDER;
        return !isProvider || Number(vars('user_id')) === providerId;
    }

    function updateButton() {
        $button().prop('hidden', !canManage(selectedProviderId()));
    }

    function fetchLink(reset) {
        const data = {csrf_token: vars('csrf_token'), provider_id: selectedProviderId()};
        if (reset) {
            data.reset = 1;
        }
        return $.post(App.Utils.Url.siteUrl('calendar/feed_link'), data).done((response) => {
            $link().val(response.url);
            showWindow(response);
        });
    }

    function showWindow(response) {
        $('#calendar-feed-past-days').val(response.past_days);
        $('#calendar-feed-future-days').val(response.future_days);
    }

    // Saves the window and shows the clamped values the server kept.
    function saveWindow() {
        const $save = $('#calendar-feed-window-save');
        const data = {
            csrf_token: vars('csrf_token'),
            provider_id: selectedProviderId(),
            past_days: $('#calendar-feed-past-days').val(),
            future_days: $('#calendar-feed-future-days').val(),
        };
        $.post(App.Utils.Url.siteUrl('calendar/feed_window'), data).done((response) => {
            showWindow(response);
            $save.text($save.data('saved'));
            setTimeout(() => $save.text($save.data('label')), 2000);
        });
    }

    function open() {
        fetchLink(false).done(show);
    }

    function copy() {
        const $copy = $('#calendar-feed-copy');
        $link().trigger('select');
        navigator.clipboard.writeText($link().val()).then(() => {
            $copy.text($copy.data('copied'));
            setTimeout(() => $copy.text($copy.data('label')), 2000);
        });
    }

    // Bootstrap's hide runs on after the dialog is out of sight (the backdrop
    // fades and the page state is restored last), and a show() meanwhile is
    // ignored or torn down by that tail, so a dialog that is closing is shown
    // once it has finished.
    let hiding = false;

    function show() {
        if (hiding) {
            $('#calendar-feed-modal').one('hidden.bs.modal', () => modal().show());
        } else {
            modal().show();
        }
    }

    // The confirm is its own modal, so the feed dialog steps aside and returns.
    function reset() {
        modal().hide();
        App.Utils.Message.show(lang('calendar_feed_reset'), lang('calendar_feed_reset_confirm'), [
            {
                text: lang('cancel'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    show();
                },
            },
            {
                text: lang('confirm'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    fetchLink(true).done(show);
                },
            },
        ]);
    }

    function initialize() {
        if (!$button().length) {
            return;
        }
        hiding = false;
        $filter().on('change', updateButton);
        $button().on('click', open);
        $('#calendar-feed-modal')
            .on('hide.bs.modal', () => (hiding = true))
            .on('hidden.bs.modal', () => (hiding = false));
        $('#calendar-feed-copy').on('click', copy);
        $('#calendar-feed-reset').on('click', reset);
        $('#calendar-feed-window-save').on('click', saveWindow);
        updateButton();
    }

    App.page(initialize);

    return {
        initialize,
        show,
    };
})();
