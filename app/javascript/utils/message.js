/**
 * Message dialog: a title, a message and buttons. Used for confirmations
 * (Turbo confirm), errors and prompts. Each button's click handler gets the
 * event and a handle with hide(); the last button is the primary one.
 */
App.Utils.Message = (function () {
    function show(title, message, buttons = null, isDismissible = true) {
        if (!title || !message) {
            return null;
        }

        if (!buttons) {
            buttons = [
                {
                    text: lang('close'),
                    click: (event, dialog) => dialog.hide(),
                },
            ];
        }

        $('#message-modal').remove();

        const $dialog = $(`
            <dialog id="message-modal" ${isDismissible ? '' : 'data-static'}>
                <article>
                    <header>
                        <h3></h3>
                        ${isDismissible ? '<button type="button" class="dialog-close" aria-label="Close" data-dialog-close>&times;</button>' : ''}
                    </header>
                    <p></p>
                    <footer></footer>
                </article>
            </dialog>
        `).appendTo('body');
        $dialog.find('h3').text(title);
        $dialog.find('p').html(message);

        const dialog = $dialog[0];
        const handle = {
            hide: () => App.Utils.Dialog.close(dialog),
            element: dialog,
        };

        buttons.forEach((button, index) => {
            if (!button) {
                return;
            }
            const primary = index === buttons.length - 1;
            const $button = $('<button/>', {type: 'button', class: primary ? '' : 'secondary', text: button.text})
                .appendTo($dialog.find('footer'));
            if (button.click) {
                $button.on('click', (event) => button.click(event, handle));
            }
        });

        dialog.addEventListener('close', () => $dialog.remove(), {once: true});
        if (!isDismissible) {
            dialog.addEventListener('cancel', (event) => event.preventDefault());
        }

        App.Utils.Dialog.open(dialog);
        $dialog.find('footer button:last').trigger('focus');

        return $dialog;
    }

    return {
        show,
    };
})();
