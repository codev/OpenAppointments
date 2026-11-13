/**
 * Provider settings pages: Test credentials and Test sending post the form as
 * it stands (unsaved edits included) to the page's test actions and show the
 * outcome under the buttons and as a notification.
 */
(function () {
    function show($block, ok, message) {
        $block.find('.test-result').text(message).toggleClass('text-danger', !ok).toggleClass('text-success', ok);
        App.Layouts.Backend.displayNotification(message);
    }

    function run(action, $block, extra) {
        const prefix = $block.data('prefix');
        const data = $('#settings-form').serialize() + '&' + $.param(Object.assign({csrf_token: vars('csrf_token')}, extra));

        $block.find('.test-result').text('...').removeClass('text-danger text-success');
        $.post(App.Utils.Url.siteUrl('messages_' + prefix + '_settings/' + action), data)
            .done((response) => show($block, response.success !== false, response.message))
            .fail((xhr) => show($block, false, (xhr.responseJSON && xhr.responseJSON.message) || lang('messages_test_failed')));
    }

    $(document).on('click', '.test-credentials', (event) => {
        run('test_credentials', $(event.currentTarget).closest('[data-prefix]'), {});
    });

    $(document).on('click', '.send-test', (event) => {
        const $block = $(event.currentTarget).closest('[data-prefix]');
        run('test_send', $block, {address: $block.find('.test-address').val()});
    });
})();
