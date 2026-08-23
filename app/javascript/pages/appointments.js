/**
 * Appointments page: the day columns are a Turbo Frame driven by the filter
 * form; this script reloads it after a dialog saves, and handles the
 * repeating appointments panel (list frame plus the pattern dialog).
 */
(function () {
    function reloadDay() {
        document.querySelector('turbo-frame#day_view').reload();
    }

    function loadSeries() {
        document.querySelector('turbo-frame#series').reload();
    }

    function showSeriesView(show) {
        $('#series-view').toggleClass('d-none', !show);
        $('#calendar .calendar-view, #not-working-notes').toggleClass('d-none', show);
        $('#toggle-series span').text(lang(show ? 'back_to_appointments' : 'repeating_appointments'));
        window.localStorage.setItem('OpenAppointments.SeriesView', show ? '1' : '0');
        if (show) {
            loadSeries();
        }
    }

    function openPattern(id) {
        const row = $('#series-table tr[data-id="' + id + '"]');
        App.Components.RepeatFields.load('series-repeat', row.data('rule'), row.data('description'), row.data('endsOn') || null);
        $('#series-pattern-save').data('id', id);
        $('#series-pattern-modal').modal('show');
    }

    function savePattern() {
        const id = $('#series-pattern-save').data('id');
        const repeat = App.Components.RepeatFields.read('series-repeat');

        if (!repeat) {
            return;
        }

        $.post(App.Utils.Url.siteUrl('appointment_series/' + id + '/reschedule'), {csrf_token: vars('csrf_token'), repeat}).done(
            (response) => {
                if (!response.success) {
                    App.Layouts.Backend.displayNotification(response.message || lang('unexpected_issues_occurred'));
                    return;
                }
                $('#series-pattern-modal').modal('hide');
                App.Layouts.Backend.displayNotification(lang('series_saved'));
                App.Components.EventModal.reportSkipped(response.skipped);
                loadSeries();
            },
        );
    }

    function initialize() {
        if (!$('#calendar-page').length || !$('#day-filter').length) {
            return;
        }

        App.once('appointments-page', () => {
            $(document).on('click', '#reload-appointments', reloadDay);
            $(document).on('click', '#toggle-series', () => showSeriesView($('#series-view').hasClass('d-none')));
            $(document).on('click', '#series-table .series-edit', (event) => openPattern($(event.currentTarget).data('id')));
            $(document).on('click', '#series-pattern-save', savePattern);
            document.addEventListener('turbo:frame-load', (event) => {
                if (event.target.id === 'day_view') {
                    tippy('[data-tippy-content]');
                }
            });
        });

        if (vars('edit_appointment')) {
            App.Components.EventModal.open('appointments/' + vars('edit_appointment').id + '/edit');
        }

        if (window.localStorage.getItem('OpenAppointments.SeriesView') === '1') {
            showSeriesView(true);
        }
    }

    App.page(initialize);
})();
