/**
 * Admin CRUD pages (shared/_crud_page): list/details toggle, picture preview and
 * drag-to-reorder. The markup is server rendered inside Turbo Frames, so
 * everything binds by delegation and survives frame reloads.
 */
(function () {
    function initialize() {
        const $page = $('[data-crud-page]');

        if (!$page.length) {
            return;
        }

        const resource = $page.find('turbo-frame').first().attr('id');

        // backend.scss shows the details only while the page is "editing".
        document.addEventListener('turbo:frame-load', () => {
            $page.toggleClass('editing', $page.find('.crud-form').length > 0);
        });

        $page.on('change', 'input[type=file][accept^="image/"]', (event) => {
            const file = event.target.files[0];

            if (file) {
                $page.find('.picture-preview').attr('src', URL.createObjectURL(file)).removeClass('d-none');
            }
        });

        App.Utils.DragReorder.enable(
            $page,
            '.entry[draggable]',
            () => !$page.find('.results').data('keyword'),
            (ids) => {
                $.post(App.Utils.Url.siteUrl(resource + '/reorder'), {csrf_token: vars('csrf_token'), ids: ids});
            },
        );
    }

    document.addEventListener('DOMContentLoaded', initialize);
})();
