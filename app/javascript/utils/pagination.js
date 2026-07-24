/**
 * Pagination bar utility.
 *
 * Renders a Bootstrap pagination bar for the backend filter lists. The search
 * endpoints report the unpaged total in the X-Total-Count response header.
 */
window.App.Utils.Pagination = (function () {
    const WINDOW_SIZE = 5;

    /**
     * Append a pagination bar to the container.
     *
     * @param {jQuery} $container Element the bar is appended to.
     * @param {Number} total Total number of records across all pages.
     * @param {Number} page Current page (1-based).
     * @param {Number} pageSize Records per page.
     * @param {Function} onPage Callback receiving the requested page number.
     */
    function render($container, total, page, pageSize, onPage) {
        const pageCount = Math.ceil(total / pageSize);

        if (pageCount <= 1) {
            return;
        }

        const $list = $('<ul/>', {
            'class': 'pagination pagination-sm justify-content-center mt-3 mb-0',
        });

        const addItem = (html, targetPage, {disabled = false, active = false} = {}) => {
            const $item = $('<li/>', {
                'class': 'page-item' + (disabled ? ' disabled' : '') + (active ? ' active' : ''),
            });

            $('<button/>', {
                'type': 'button',
                'class': 'page-link',
                'html': html,
                'disabled': disabled,
                'click': () => onPage(targetPage),
            }).appendTo($item);

            $item.appendTo($list);
        };

        const addEllipsis = () => {
            $('<li/>', {
                'class': 'page-item disabled',
                'html': $('<span/>', {'class': 'page-link', 'text': '…'}),
            }).appendTo($list);
        };

        addItem('&laquo;', page - 1, {disabled: page <= 1});

        let start = Math.max(1, page - Math.floor(WINDOW_SIZE / 2));
        const end = Math.min(pageCount, start + WINDOW_SIZE - 1);
        start = Math.max(1, end - WINDOW_SIZE + 1);

        if (start > 1) {
            addItem('1', 1);

            if (start > 2) {
                addEllipsis();
            }
        }

        for (let pageNumber = start; pageNumber <= end; pageNumber++) {
            addItem(String(pageNumber), pageNumber, {active: pageNumber === page});
        }

        if (end < pageCount) {
            if (end < pageCount - 1) {
                addEllipsis();
            }

            addItem(String(pageCount), pageCount);
        }

        addItem('&raquo;', page + 1, {disabled: page >= pageCount});

        $('<nav/>', {'html': $list}).appendTo($container);
    }

    return {
        render,
    };
})();
