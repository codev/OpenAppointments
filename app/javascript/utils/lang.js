/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Lang utility.
 *
 * This module implements the functionality of translations.
 */
window.App.Utils.Lang = (function () {
    /**
     * Enable Language Selection
     *
     * Enables the language selection functionality. Must be called on every page has a language selection button.
     * This method requires the global variable "vars('available_variables')" to be initialized before the execution.
     *
     * @param {Object} $target Selected element button for the language selection.
     */
    function enableLanguageSelection($target) {
        // The languages open in a dialog; choosing one changes the language and reloads.
        const $list = $('<ul/>', {
            id: 'language-list',
            class: 'language-list',
            html: vars('available_languages').map((availableLanguage) =>
                $('<li/>', {
                    class: 'language',
                    'data-language': availableLanguage,
                    text: App.Utils.String.upperCaseFirstLetter(availableLanguage),
                }),
            ),
        });
        const $dialog = $(`
            <dialog id="language-dialog">
                <article>
                    <header>
                        <h4>Select Language</h4>
                        <button type="button" class="dialog-close" aria-label="Close" data-dialog-close>&times;</button>
                    </header>
                </article>
            </dialog>
        `).appendTo('body');
        $dialog.find('article').append($list);

        $target.on('click', () => App.Utils.Dialog.open($dialog[0]));
        $target.on('keydown', (event) => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                App.Utils.Dialog.open($dialog[0]);
            }
        });

        $(document).on('click', 'li.language', (event) => {
            // Change language with HTTP request and refresh page.
            const language = $(event.target).data('language');
            App.Http.Localization.changeLanguage(language).done(() => {
                document.location.reload();
            });
            App.Utils.Dialog.close($dialog[0]);
        });
    }

    return {
        enableLanguageSelection,
    };
})();
