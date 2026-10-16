/**
 * Appointments page (List): the days are a Turbo Frame driven by the filter
 * form; this script reloads it after a dialog saves, and handles the
 * repeating appointments panel (list frame plus the pattern dialog).
 */
(function () {
    // The frame renders inline (no src) until a filter or day link navigates it,
    // and Turbo's reload() is a no-op without a src: point it at the current URL.
    function reloadDay() {
        const frame = document.querySelector('turbo-frame#day_view');

        if (!frame) {
            return; // the reload button is shared with the calendar page
        }

        if (frame.src) {
            frame.reload();
        } else {
            frame.src = window.location.href;
        }
    }

    let openFilterId = null; // the toolbar dropdown open when the filter form was submitted

    function reopenFilter() {
        const toggle = openFilterId && document.querySelector('#' + openFilterId + ' .dropdown-toggle');
        openFilterId = null;
        if (toggle) {
            bootstrap.Dropdown.getOrCreateInstance(toggle).show();
        }
    }

    function loadSeries() {
        document.querySelector('turbo-frame#series').reload();
    }

    // A reloaded day view arrives unhidden; while the series list is shown it stays alone.
    function keepSeriesView() {
        if ($('#series-view').length && !$('#series-view').hasClass('d-none')) {
            $('#calendar .calendar-view, #not-working-notes').addClass('d-none');
        }
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
            $(document).on('click', '#calendar-page button.day-entry[data-event]', (event) =>
                App.Utils.CalendarEvents.openEntryPopover(event.currentTarget),
            );
            // A filter tick submits the form and the frame render replaces the
            // toolbar, so the dropdown that was open is opened again.
            document.addEventListener('turbo:submit-start', (event) => {
                if (event.target.id === 'day-filter') {
                    openFilterId = $('#day-filter .dropdown-menu.show').closest('.dropdown').attr('id') || null;
                }
            });
            document.addEventListener('turbo:frame-load', (event) => {
                if (event.target.id === 'day_view') {
                    App.Utils.CalendarEvents.closePopover();
                    tippy('[data-tippy-content]');
                    reopenFilter();
                    keepSeriesView();
                }
            });
        });

        // The popover's buttons (Close, Cancel, Delete, Edit) act on this page's entries.
        App.Utils.CalendarEvents.configure(reloadDay);

        if (vars('edit_appointment')) {
            App.Components.EventModal.open('appointments/' + vars('edit_appointment').id + '/edit');
        }

        if ($('#series-view').length && window.localStorage.getItem('OpenAppointments.SeriesView') === '1') {
            showSeriesView(true);
        }
    }

    App.page(initialize);
})();
