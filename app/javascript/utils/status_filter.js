/**
 * Status tick boxes (shared/status_filter partial) for the calendar pages.
 * Appointments with no status are always shown.
 */
App.Utils.StatusFilter = (function () {
    const $filter = $('#status-filter');

    function selected() {
        return $filter
            .find('input:checked')
            .toArray()
            .map((el) => el.value);
    }

    function apply(appointments) {
        if (!$filter.length) {
            return appointments;
        }

        const names = selected();

        return appointments.filter((appointment) => !appointment.status || names.includes(appointment.status));
    }

    function onChange(callback) {
        $filter.on('change', 'input', callback);
    }

    return {
        apply,
        onChange,
        selected,
    };
})();
