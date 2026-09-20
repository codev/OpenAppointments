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
 * Appointment status options component.
 *
 * Each option is {id, name, kind}. Special kinds (booked, rescheduled, cancelled,
 * late_cancel, no_show) can be renamed but not deleted.
 */
App.Components.AppointmentStatusOptions = (function () {
    function renderListGroupItem(option = {id: '', name: '', kind: 'custom'}) {
        const special = option.kind !== 'custom';
        const $item = $(`
            <li class="appointment-status-option toolbar">
                <label class="toolbar">
                    <input class="small-field">
                    <span class="tag nowrap" ${special ? '' : 'hidden'}></span>
                </label>
                <button type="button" class="destructive small-action delete-appointment-status-option" ${special ? 'disabled' : ''}>
                    <i class="fas fa-trash"></i>
                </button>
            </li>
        `);
        $item.data('option', option);
        $item.find('input').val(option.name);
        $item.find('.tag').text(lang('status_' + option.kind));
        return $item;
    }

    function onDeleteAppointmentStatusOptionClick(event) {
        $(event.currentTarget).closest('li').remove();
    }

    function onAddAppointmentStatusOptionClick(event) {
        const $listGroup = $(event.currentTarget).closest('.appointment-status-options').find('.record-list');

        if (!$listGroup.length) {
            return;
        }

        renderListGroupItem().appendTo($listGroup);
    }

    /**
     * @param {jQuery} $target Container element.
     * @return {Object[]} [{id, name, kind}]
     */
    function getOptions($target) {
        return $target
            .find('.record-list li')
            .toArray()
            .map((el) => ({...$(el).data('option'), name: $(el).find('input').val()}));
    }

    /**
     * @param {jQuery} $target Container element.
     * @param {Object[]} options [{id, name, kind}]
     */
    function setOptions($target, options) {
        const $listGroup = $target.find('.record-list');

        if (!$listGroup.length || !options) {
            return;
        }

        $listGroup.empty();
        options.forEach((option) => renderListGroupItem(option).appendTo($listGroup));
    }

    function initialize() {
        App.once('appointment-status-options', () => {
            $(document).on('click', '.delete-appointment-status-option', onDeleteAppointmentStatusOptionClick);
            $(document).on('click', '.add-appointment-status-option', onAddAppointmentStatusOptionClick);
        });
    }

    App.page(initialize);

    return {
        getOptions,
        setOptions,
    };
})();
