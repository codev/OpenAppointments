/**
 * Repeat pattern fields (shared/_repeat_fields). One instance per prefix.
 */
App.Components.RepeatFields = (function () {
    function $root(prefix) {
        return $('.repeat-fields[data-prefix="' + prefix + '"]');
    }

    function refresh(prefix) {
        const $fields = $root(prefix);
        const frequency = $fields.find('.repeat-frequency').val();
        const ends = $fields.find('.repeat-ends').val();

        $fields.find('.repeat-detail').toggle(frequency !== 'none');
        $fields.find('.repeat-weekdays').toggle(frequency === 'weekly');
        $fields.find('.repeat-ends-on-group').toggle(ends === 'on');
        $fields.find('.repeat-count-group').toggle(ends === 'after');
    }

    function reset(prefix) {
        const $fields = $root(prefix);
        $fields.find('.repeat-frequency').val('none');
        $fields.find('.repeat-interval').val(1);
        $fields.find('.repeat-weekday').prop('checked', false);
        $fields.find('.repeat-ends').val('never');
        $fields.find('.repeat-count').val(10);
        App.Utils.UI.setDateTimePickerValue($fields.find('.repeat-ends-on'), new Date());
        refresh(prefix);
    }

    /**
     * The pattern as posted to the server, or null when not repeating.
     */
    function read(prefix) {
        const $fields = $root(prefix);
        const frequency = $fields.find('.repeat-frequency').val();

        if (frequency === 'none') {
            return null;
        }

        const endsOn = App.Utils.UI.getDateTimePickerValue($fields.find('.repeat-ends-on'));

        return {
            frequency,
            interval: $fields.find('.repeat-interval').val(),
            weekdays: $fields
                .find('.repeat-weekday:checked')
                .map((index, el) => $(el).val())
                .get(),
            ends: $fields.find('.repeat-ends').val(),
            ends_on: moment(endsOn).format('YYYY-MM-DD'),
            count: $fields.find('.repeat-count').val(),
        };
    }

    /**
     * Preselect from a stored IceCube schedule hash (series view edit).
     */
    function load(prefix, schedule, endsOn) {
        reset(prefix);
        const rule = (schedule.rrules || [])[0];
        if (!rule) {
            return;
        }
        const $fields = $root(prefix);
        const frequency = rule.rule_type.replace('IceCube::', '').replace('Rule', '').toLowerCase();
        $fields.find('.repeat-frequency').val(frequency);
        $fields.find('.repeat-interval').val(rule.interval || 1);
        if (rule.validations && rule.validations.day) {
            rule.validations.day.forEach((day) => $fields.find('.repeat-weekday[value="' + day + '"]').prop('checked', true));
        }
        if (rule.count) {
            $fields.find('.repeat-ends').val('after');
            $fields.find('.repeat-count').val(rule.count);
        } else if (endsOn) {
            $fields.find('.repeat-ends').val('on');
            App.Utils.UI.setDateTimePickerValue($fields.find('.repeat-ends-on'), moment(endsOn).toDate());
        }
        refresh(prefix);
    }

    function initialize() {
        $('.repeat-fields').each((index, fields) => {
            const prefix = $(fields).data('prefix');
            App.Utils.UI.initializeDatePicker($(fields).find('.repeat-ends-on'));
            $(fields).on('change', '.repeat-frequency, .repeat-ends', () => refresh(prefix));
            reset(prefix);
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {read, reset, load, refresh};
})();
