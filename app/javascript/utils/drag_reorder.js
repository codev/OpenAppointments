/**
 * Drag-to-reorder for the admin filter lists.
 *
 * Entries (each followed by an <hr> separator) become draggable; dropping in a
 * new position reports the full id order. Reordering is blocked while a
 * keyword filter narrows the list, since a partial order would push the
 * missing records to the end.
 */
App.Utils.DragReorder = (function () {
    /**
     * @param {jQuery} $container The results container.
     * @param {String} entrySelector Selector of the draggable entries.
     * @param {Function} canReorder Returns whether dragging is currently allowed.
     * @param {Function} onReorder Receives the ordered id array after a move.
     */
    function enable($container, entrySelector, canReorder, onReorder) {
        let $dragged = null;
        let startOrder = '';

        const unit = ($entry) => $entry.add($entry.next('hr'));

        const currentOrder = () =>
            $container
                .find(entrySelector)
                .map((index, el) => $(el).attr('data-id'))
                .get();

        $container.on('dragstart', entrySelector, (event) => {
            if (!canReorder()) {
                event.preventDefault();
                return;
            }

            $dragged = $(event.currentTarget);
            startOrder = currentOrder().join(',');
            event.originalEvent.dataTransfer.effectAllowed = 'move';
            event.originalEvent.dataTransfer.setData('text/plain', '');
        });

        $container.on('dragover', entrySelector, (event) => {
            if (!$dragged) {
                return;
            }

            event.preventDefault();

            const $target = $(event.currentTarget);

            if ($target.is($dragged)) {
                return;
            }

            const midpoint = $target.offset().top + $target.outerHeight() / 2;

            if (event.originalEvent.clientY + window.scrollY < midpoint) {
                unit($dragged).insertBefore($target);
            } else {
                unit($dragged).insertAfter($target.next('hr').length ? $target.next('hr') : $target);
            }
        });

        $container.on('dragover', (event) => {
            if ($dragged) {
                event.preventDefault(); // Allow dropping anywhere in the container.
            }
        });

        $container.on('drop', (event) => {
            if ($dragged) {
                event.preventDefault();
            }
        });

        $container.on('dragend', entrySelector, () => {
            if (!$dragged) {
                return;
            }

            $dragged = null;
            const order = currentOrder();

            if (order.join(',') !== startOrder) {
                onReorder(order);
            }
        });
    }

    return {
        enable,
    };
})();
