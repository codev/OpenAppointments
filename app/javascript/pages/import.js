/**
 * Manage data page.
 *
 * ODS export, imports (OpenAppointments ODS or 10to8 CSV; analyze dry run,
 * background import with polling) and the database reset.
 */
App.Pages.Import = (function () {
    const $file = $('#import-file');
    const $results = $('#import-results');
    let pollTimer = null;

    function formData() {
        const data = new FormData();
        data.append('csrf_token', vars('csrf_token'));
        data.append('file', $file[0].files[0]);
        data.append('import_type', $('#import-type').val());
        data.append('days_back', $('#days-back').val());
        data.append('days_forward', $('#days-forward').val());
        $('.import-phase:checked').each((index, el) => data.append('phases[]', $(el).val()));
        data.append('create_providers', $('#phase-providers').prop('checked') ? '1' : '0');
        return data;
    }

    function show(message, type) {
        $results
            .removeClass('d-none alert-info alert-danger alert-success')
            .addClass('alert-' + (type || 'info'))
            .text(message);
    }

    function post(url, data) {
        return $.ajax({url: url, method: 'POST', data: data, processData: false, contentType: false});
    }

    function requireFile() {
        if (!$file[0].files.length) {
            show(lang('no_file_selected'), 'danger');
            return false;
        }
        return true;
    }

    function describeCounts(counts) {
        return Object.keys(counts)
            .map((phase) => {
                const entry = counts[phase];
                return (
                    lang(phase) + ': ' + entry.created + ' ' + lang('created') + ', ' + entry.matched +
                    ' ' + lang('matched') + ', ' + entry.skipped + ' ' + lang('skipped')
                );
            })
            .join('\n');
    }

    function poll(importId) {
        pollTimer = setTimeout(() => {
            $.getJSON(App.Utils.Url.siteUrl('import/status'), {import_id: importId}, (status) => {
                if (status.state === 'completed') {
                    show(lang('import_complete') + '\n' + describeCounts(status.counts || {}), 'success');
                } else if (status.state === 'failed') {
                    show(status.error || lang('unexpected_issues_occurred'), 'danger');
                } else {
                    show(lang('import_running') + (status.phase ? ' (' + lang(status.phase) + ')' : ''));
                    poll(importId);
                }
            });
        }, 2000);
    }

    function initialize() {
        $('#analyze-import').on('click', () => {
            if (!requireFile()) return;
            show(lang('import_running'));
            post(App.Utils.Url.siteUrl('import/analyze'), formData())
                .done((response) => {
                    const summary = response.summary;
                    show(
                        Object.keys(summary)
                            .map((key) => key + ': ' + summary[key])
                            .join('\n'),
                    );
                })
                .fail((jqXHR) => show((jqXHR.responseJSON || {}).message || 'Error', 'danger'));
        });

        $('#start-import').on('click', () => {
            if (!requireFile()) return;
            show(lang('import_running'));
            post(App.Utils.Url.siteUrl('import/start'), formData())
                .done((response) => poll(response.import_id))
                .fail((jqXHR) => show((jqXHR.responseJSON || {}).message || 'Error', 'danger'));
        });

        $('#reset-confirmation').on('input', (event) => {
            $('#reset-database').prop('disabled', $(event.target).val() !== 'I KNOW WHAT I AM DOING');
        });

        $('#reset-database').on('click', () => {
            $.post(App.Utils.Url.siteUrl('import/reset'), {
                csrf_token: vars('csrf_token'),
                confirmation: $('#reset-confirmation').val(),
                full: $('#full-reset').prop('checked') ? '1' : '0',
            })
                .done((response) => {
                    show(lang('reset_database_done'), 'success');
                    $('#reset-confirmation').val('').trigger('input');

                    if (response.full) {
                        // The session admin is gone; show the logged-out page.
                        setTimeout(() => (window.location.href = App.Utils.Url.siteUrl('logout')), 2000);
                    }
                })
                .fail((jqXHR) => show((jqXHR.responseJSON || {}).message || 'Error', 'danger'));
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
