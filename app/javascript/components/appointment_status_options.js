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
            <li class="list-group-item d-flex justify-content-between align-items-center p-0 border-0 mb-3 appointment-status-option">
                <label class="w-100 me-2 d-flex align-items-center gap-2">
                    <input class="form-control">
                    <span class="badge text-bg-secondary text-nowrap ${special ? '' : 'd-none'}"></span>
                </label>
                <button type="button" class="btn btn-outline-danger delete-appointment-status-option" ${special ? 'disabled' : ''}>
                    <i class="fas fa-trash"></i>
                </button>
            </li>
        `);
        $item.data('option', option);
        $item.find('input').val(option.name);
        $item.find('.badge').text(lang('status_' + option.kind));
        return $item;
    }

    function onDeleteAppointmentStatusOptionClick(event) {
        $(event.currentTarget).closest('li').remove();
    }

    function onAddAppointmentStatusOptionClick(event) {
        const $listGroup = $(event.currentTarget).closest('.appointment-status-options').find('.list-group');

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
            .find('.list-group li')
            .toArray()
            .map((el) => ({...$(el).data('option'), name: $(el).find('input').val()}));
    }

    /**
     * @param {jQuery} $target Container element.
     * @param {Object[]} options [{id, name, kind}]
     */
    function setOptions($target, options) {
        const $listGroup = $target.find('.list-group');

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
