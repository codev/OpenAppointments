/**
 * Native dialogs and toasts. A dialog opens with App.Utils.Dialog.open(element)
 * or a [data-dialog-open="id"] trigger and closes with [data-dialog-close]
 * inside it; a click on the backdrop closes a dismissible one.
 */
App.Utils.Dialog = (function () {
    function element(target) {
        if (typeof target === 'string') {
            return document.getElementById(target);
        }
        return target instanceof jQuery ? target[0] : target;
    }

    function open(target) {
        const dialog = element(target);
        if (dialog && !dialog.open) {
            dialog.showModal();
        }
        return dialog;
    }

    function close(target) {
        const dialog = element(target);
        if (dialog && dialog.open) {
            dialog.close();
        }
        return dialog;
    }

    function isOpen(target) {
        const dialog = element(target);
        return Boolean(dialog && dialog.open);
    }

    /**
     * A short lived message in the corner with optional action buttons
     * ({label, click}); it goes when a button is used or after the delay.
     */
    function toast(message, actions = [], delay = 8000) {
        $('.toast').remove();
        const $toast = $('<div/>', {class: 'toast', role: 'status', 'aria-live': 'polite'});
        $('<span/>', {text: message}).appendTo($toast);
        actions.forEach((action) => {
            $('<button/>', {type: 'button', class: 'secondary', text: action.label})
                .on('click', (event) => {
                    action.click?.(event);
                    $toast.remove();
                })
                .appendTo($toast);
        });
        $toast.appendTo('body');
        setTimeout(() => $toast.remove(), delay);
        return $toast;
    }

    document.addEventListener('click', (event) => {
        const opener = event.target.closest('[data-dialog-open]');
        if (opener) {
            open(opener.dataset.dialogOpen);
            return;
        }
        const closer = event.target.closest('[data-dialog-close]');
        if (closer) {
            close(closer.closest('dialog'));
            return;
        }
        // A click on the backdrop lands on the dialog element itself.
        if (event.target instanceof HTMLDialogElement && event.target.open && !event.target.hasAttribute('data-static')) {
            event.target.close();
        }
    });

    return {
        open,
        close,
        isOpen,
        toast,
    };
})();
