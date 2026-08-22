/**
 * Repeat pattern fields (shared/_repeat_fields): the recurring_select dropdown for the
 * IceCube rule plus end controls. One instance per prefix.
 */
App.Components.RepeatFields = (function () {
    function $root(prefix) {
        return $('.repeat-fields[data-prefix="' + prefix + '"]');
    }

    function ruleValue($fields) {
        const value = $fields.find('.repeat-rule').val();
        return value && value !== 'null' && value !== 'custom' ? value : null;
    }

    function refresh(prefix) {
        const $fields = $root(prefix);
        const ends = $fields.find('.repeat-ends').val();

        $fields.find('.repeat-detail').toggle(Boolean(ruleValue($fields)));
        $fields.find('.repeat-ends-on-group').toggle(ends === 'on');
        $fields.find('.repeat-count-group').toggle(ends === 'after');
    }

    function reset(prefix) {
        const $fields = $root(prefix);
        $fields.find('.repeat-rule option[data-custom]').remove();
        $fields.find('.repeat-rule').val('null');
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
        const rule = ruleValue($fields);

        if (!rule) {
            return null;
        }

        const endsOn = App.Utils.UI.getDateTimePickerValue($fields.find('.repeat-ends-on'));

        return {
            rule,
            ends: $fields.find('.repeat-ends').val(),
            ends_on: moment(endsOn).format('YYYY-MM-DD'),
            count: $fields.find('.repeat-count').val(),
        };
    }

    /**
     * Preselect a stored rule (series view edit). ruleHash is the IceCube rule hash,
     * description its text, endsOn the series end date if any.
     */
    function load(prefix, ruleHash, description, endsOn) {
        reset(prefix);
        const $fields = $root(prefix);
        const $select = $fields.find('.repeat-rule');
        const json = JSON.stringify(ruleHash);
        $('<option/>', {value: json, text: description, 'data-custom': true}).insertBefore($select.find('option').last());
        $select.val(json);
        $select.recurring_select('set_initial_values');
        if (ruleHash.count) {
            $fields.find('.repeat-ends').val('after');
            $fields.find('.repeat-count').val(ruleHash.count);
        } else if (endsOn) {
            $fields.find('.repeat-ends').val('on');
            App.Utils.UI.setDateTimePickerValue($fields.find('.repeat-ends-on'), moment(endsOn).toDate());
        }
        refresh(prefix);
    }

    function initialize() {
        // Dialog texts from the app translations.
        const list = (key) => lang(key).split(',').map((part) => part.trim());
        $.extend($.fn.recurring_select.texts, {
            locale_iso_code: vars('language_code') || 'en',
            repeat: lang('repeat'),
            last_day: lang('rs_last_day'),
            frequency: lang('rs_frequency'),
            daily: lang('daily'),
            weekly: lang('weekly'),
            monthly: lang('monthly'),
            yearly: lang('rs_yearly'),
            every: lang('repeat_every'),
            days: lang('rs_days'),
            weeks_on: lang('rs_weeks_on'),
            months: lang('rs_months'),
            years: lang('rs_years'),
            day_of_month: lang('rs_day_of_month'),
            day_of_week: lang('rs_day_of_week'),
            cancel: lang('cancel'),
            ok: lang('rs_ok'),
            summary: lang('rs_summary'),
            first_day_of_week: App.Utils.Date.getWeekdayId(vars('first_weekday') || 'sunday'),
            days_first_letter: list('rs_days_first_letter'),
            order: list('rs_order'),
        });

        $('.repeat-fields').each((index, fields) => {
            const prefix = $(fields).data('prefix');
            App.Utils.UI.initializeDatePicker($(fields).find('.repeat-ends-on'));
            $(fields).on('change', '.repeat-ends', () => refresh(prefix));
            $(fields).on('recurring_select:save recurring_select:cancel', '.repeat-rule', () => refresh(prefix));
            $(fields).on('change', '.repeat-rule', () => refresh(prefix));
            reset(prefix);
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {read, reset, load, refresh};
})();
