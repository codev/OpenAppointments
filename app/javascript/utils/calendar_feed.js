/**
 * Calendar feed button on the calendar page: shown when a provider is selected
 * (any provider for editors, only themselves for a provider). Opens the dialog
 * with the subscription link from calendar/feed_link; reset makes a new one.
 */
App.Utils.CalendarFeed = (function () {
    const $filter = () => $('#select-filter-item');
    const $button = () => $('#calendar-feed');
    const $link = () => $('#calendar-feed-link');
    const modal = () => {
        const dialog = document.getElementById('calendar-feed-modal');
        return {show: () => App.Utils.Dialog.open(dialog), hide: () => App.Utils.Dialog.close(dialog)};
    };

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
        return $.post(App.Utils.Url.siteUrl('calendar/feed_link'), data).done((response) => $link().val(response.url));
    }

    function open() {
        fetchLink(false).done(() => modal().show());
    }

    function copy() {
        const $copy = $('#calendar-feed-copy');
        $link().trigger('select');
        navigator.clipboard.writeText($link().val()).then(() => {
            $copy.text($copy.data('copied'));
            setTimeout(() => $copy.text($copy.data('label')), 2000);
        });
    }

    // The confirm is its own modal, so the feed dialog steps aside and returns.
    function reset() {
        modal().hide();
        App.Utils.Message.show(lang('calendar_feed_reset'), lang('calendar_feed_reset_confirm'), [
            {
                text: lang('cancel'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    modal().show();
                },
            },
            {
                text: lang('confirm'),
                click: (event, messageModal) => {
                    messageModal.hide();
                    fetchLink(true).done(() => modal().show());
                },
            },
        ]);
    }

    function initialize() {
        if (!$button().length) {
            return;
        }
        $filter().on('change', updateButton);
        $button().on('click', open);
        $('#calendar-feed-copy').on('click', copy);
        $('#calendar-feed-reset').on('click', reset);
        updateButton();
    }

    App.page(initialize);

    return {
        initialize,
    };
})();
