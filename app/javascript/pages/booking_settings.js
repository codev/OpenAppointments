/**
 * Booking settings: the display switch greys its example field and the
 * require switch shows its asterisk; requiring email or phone individually
 * clears the phone-or-email rule and vice versa (with a flash). The disable
 * booking message is a rich text editor.
 */
(function () {
    function updateDisplaySwitch($switch) {
        const isChecked = $switch.prop('checked');
        const $formGroup = $switch.closest('.form-group');
        $formGroup.find('.require-switch').prop('disabled', !isChecked);
        $formGroup.find('.form-label, .form-control').toggleClass('opacity-25', !isChecked);
    }

    function updateRequireSwitch($switch) {
        $switch.closest('.form-group').find('.text-danger').toggle($switch.prop('checked'));
    }

    function uncheckWithFlash($switch) {
        if (!$switch.prop('checked')) {
            return;
        }

        $switch.prop('checked', false);
        const $formCheck = $switch.closest('.form-check');
        $formCheck.addClass('switch-flash');
        $switch.one('animationend', () => $formCheck.removeClass('switch-flash'));
    }

    function reconcileContactRequirements($origin) {
        const $phoneOrEmail = $('#require-phone-or-email');

        if ($origin.is($phoneOrEmail)) {
            if ($phoneOrEmail.prop('checked')) {
                $('#require-email, #require-phone-number').each((index, el) => {
                    uncheckWithFlash($(el));
                    updateRequireSwitch($(el));
                });
            }
        } else if ($origin.prop('checked')) {
            uncheckWithFlash($phoneOrEmail);
        }
    }

    function applyState() {
        $('.display-switch').each((index, el) => updateDisplaySwitch($(el)));
        $('.require-switch').each((index, el) => updateRequireSwitch($(el)));
        $('textarea.rich-text').trumbowyg();
    }

    $(document).on('click', '.display-switch', (event) => updateDisplaySwitch($(event.target)));
    $(document).on('click', '.require-switch', (event) => {
        updateRequireSwitch($(event.target));
        if ($(event.target).is('#require-email, #require-phone-number')) {
            reconcileContactRequirements($(event.target));
        }
    });
    $(document).on('click', '#require-phone-or-email', (event) => reconcileContactRequirements($(event.target)));
    document.addEventListener('turbo:frame-load', applyState);
    document.addEventListener('DOMContentLoaded', applyState);
})();
