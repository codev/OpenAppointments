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
 * Booking settings page.
 *
 * This module implements the functionality of the booking settings page.
 */
App.Pages.BookingSettings = (function () {
    const $bookingSettings = $('#booking-settings');
    const $saveSettings = $('#save-settings');
    const $disableBooking = $('#disable-booking');
    const $disableBookingMessage = $('#disable-booking-message');
    const $requirePhoneOrEmail = $('#require-phone-or-email');

    /**
     * Check if the form has invalid values.
     *
     * @return {Boolean}
     */
    function isInvalid() {
        try {
            $('#booking-settings .is-invalid').removeClass('is-invalid');

            // Validate required fields.

            let missingRequiredFields = false;

            $('#booking-settings .required').each((index, requiredField) => {
                const $requiredField = $(requiredField);

                if (!$requiredField.val()) {
                    $requiredField.addClass('is-invalid');
                    missingRequiredFields = true;
                }
            });

            if (missingRequiredFields) {
                throw new Error(lang('fields_are_required'));
            }

            // Ensure there is at least one field displayed.

            if (!$('.display-switch:checked').length) {
                throw new Error(lang('at_least_one_field'));
            }

            // Ensure there is at least one field required (the phone-or-email rule counts).

            if (!$('.require-switch:checked').length && !$requirePhoneOrEmail.prop('checked')) {
                throw new Error(lang('at_least_one_field_required'));
            }

            return false;
        } catch (error) {
            App.Layouts.Backend.displayNotification(error.message);
            return true;
        }
    }

    /**
     * Apply the booking settings into the page.
     *
     * @param {Object} bookingSettings
     */
    function deserialize(bookingSettings) {
        bookingSettings.forEach((bookingSetting) => {
            if (bookingSetting.name === 'disable_booking_message') {
                $disableBookingMessage.trumbowyg('html', bookingSetting.value);
                return;
            }

            const $field = $('[data-field="' + bookingSetting.name + '"]');

            if ($field.is(':checkbox')) {
                $field.prop('checked', Boolean(Number(bookingSetting.value)));
            } else {
                $field.val(bookingSetting.value);
            }
        });
    }

    /**
     * Serialize the page values into an array.
     *
     * @returns {Array}
     */
    function serialize() {
        const bookingSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            bookingSettings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        bookingSettings.push({
            name: 'disable_booking_message',
            value: $disableBookingMessage.trumbowyg('html'),
        });

        return bookingSettings;
    }

    /**
     * Update the UI based on the display switch state.
     *
     * @param {jQuery} $displaySwitch
     */
    function updateDisplaySwitch($displaySwitch) {
        const isChecked = $displaySwitch.prop('checked');

        const $formGroup = $displaySwitch.closest('.form-group');

        $formGroup.find('.require-switch').prop('disabled', !isChecked);

        $formGroup.find('.form-label, .form-control').toggleClass('opacity-25', !isChecked);

        if (!isChecked) {
            $formGroup.find('.require-switch').prop('checked', false);
            $formGroup.find('.text-danger').hide();
        }
    }

    /**
     * Update the UI based on the require switch state.
     *
     * @param {jQuery} $requireSwitch
     */
    function updateRequireSwitch($requireSwitch) {
        const isChecked = $requireSwitch.prop('checked');

        const $formGroup = $requireSwitch.closest('.form-group');

        $formGroup.find('.text-danger').toggle(isChecked);
    }

    /**
     * Uncheck a switch with a flash animation, so the automatic change is visible.
     *
     * @param {jQuery} $switch
     */
    function uncheckWithFlash($switch) {
        if (!$switch.prop('checked')) {
            return;
        }

        $switch.prop('checked', false);

        const $formCheck = $switch.closest('.form-check');

        $formCheck.addClass('switch-flash');

        $switch.one('animationend', () => $formCheck.removeClass('switch-flash'));
    }

    /**
     * Requiring email or phone individually is mutually exclusive with the
     * phone-or-email rule: turning one side on turns the other off.
     */
    function reconcileContactRequirements($origin) {
        if ($origin.is($requirePhoneOrEmail)) {
            if ($requirePhoneOrEmail.prop('checked')) {
                $('#require-email, #require-phone-number').each((index, el) => {
                    uncheckWithFlash($(el));
                    updateRequireSwitch($(el));
                });
            }
        } else if ($origin.prop('checked')) {
            uncheckWithFlash($requirePhoneOrEmail);
        }
    }

    /**
     * Update the UI based on the initial values.
     */
    function applyInitialState() {
        $bookingSettings.find('.display-switch').each((index, displaySwitchEl) => {
            const $displaySwitch = $(displaySwitchEl);

            updateDisplaySwitch($displaySwitch);
        });

        $bookingSettings.find('.require-switch').each((index, requireSwitchEl) => {
            const $requireSwitch = $(requireSwitchEl);

            updateRequireSwitch($requireSwitch);
        });

        $disableBookingMessage.closest('.form-group').prop('hidden', !$disableBooking.prop('checked'));
    }

    /**
     * Save the account information.
     */
    function onSaveSettingsClick() {
        if (isInvalid()) {
            return;
        }

        const bookingSettings = serialize();

        App.Http.BookingSettings.save(bookingSettings).done(() => {
            App.Layouts.Backend.displayNotification(lang('settings_saved'));
        });
    }

    /**
     * Update the UI.
     *
     * @param {jQuery} event
     */
    function onDisplaySwitchClick(event) {
        const $displaySwitch = $(event.target);

        updateDisplaySwitch($displaySwitch);
    }

    /**
     * Update the UI.
     *
     * @param {Event} event
     */
    function onRequireSwitchClick(event) {
        const $requireSwitch = $(event.target);

        updateRequireSwitch($requireSwitch);

        if ($requireSwitch.is('#require-email, #require-phone-number')) {
            reconcileContactRequirements($requireSwitch);
        }
    }

    /**
     * Toggle the message container.
     */
    function onDisableBookingClick() {
        $disableBookingMessage.closest('.form-group').prop('hidden', !$disableBooking.prop('checked'));
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        const bookingSettings = vars('booking_settings');

        $saveSettings.on('click', onSaveSettingsClick);

        $disableBooking.on('click', onDisableBookingClick);

        $bookingSettings
            .on('click', '.display-switch', onDisplaySwitchClick)
            .on('click', '.require-switch', onRequireSwitchClick);

        $requirePhoneOrEmail.on('click', () => reconcileContactRequirements($requirePhoneOrEmail));

        $disableBookingMessage.trumbowyg();

        deserialize(bookingSettings);

        applyInitialState();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
