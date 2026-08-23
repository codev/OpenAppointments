/**
 * Service categories page: list/details toggle, drag-to-reorder and picture
 * preview. The markup is server rendered inside Turbo Frames, so everything
 * binds by delegation and survives frame reloads.
 */
(function () {
    function initialize() {
        const $page = $('#service-categories-page');
        const $frame = $('turbo-frame#service_categories');

        if (!$frame.length) {
            return;
        }

        // backend.scss shows the details only while the page is "editing".
        document.addEventListener('turbo:frame-load', () => {
            $page.toggleClass('editing', $('#service-category-form').length > 0);
        });

        App.Utils.DragReorder.enable(
            $frame,
            '.service-category-row',
            () => !$frame.find('.results').data('keyword'),
            (ids) => {
                $.post(App.Utils.Url.siteUrl('service_categories/reorder'), {csrf_token: vars('csrf_token'), ids: ids});
            },
        );

        $(document).on('change', '#service_category_picture', (event) => {
            const file = event.target.files[0];

            if (file) {
                $('#picture-preview').attr('src', URL.createObjectURL(file)).removeClass('d-none');
            }
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);
})();
