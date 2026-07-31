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

        const $imagesFile = $('#import-images-file');

        if ($('#import-type').val() === 'ods' && $imagesFile[0].files.length) {
            data.append('images_file', $imagesFile[0].files[0]);
        }

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
                let line =
                    lang(phase) + ': ' + entry.created + ' ' + lang('created') + ', ' + entry.matched +
                    ' ' + lang('matched') + ', ' + entry.skipped + ' ' + lang('skipped');
                if (entry.failed) {
                    line += ', ' + entry.failed + ' ' + lang('failed');
                }
                return line;
            })
            .join('\n');
    }

    function describeErrors(errors) {
        if (!errors.length) {
            return '';
        }

        return (
            '\n\n' + lang('import_failures') + '\n' +
            errors.map((error) => lang(error.phase) + ': ' + error.item + ' - ' + error.message).join('\n')
        );
    }

    function poll(importId) {
        pollTimer = setTimeout(() => {
            $.getJSON(App.Utils.Url.siteUrl('import/status'), {import_id: importId}, (status) => {
                if (status.state === 'completed') {
                    const errors = status.errors || [];
                    show(
                        lang('import_complete') + '\n' + describeCounts(status.counts || {}) + describeErrors(errors),
                        errors.length ? 'warning' : 'success',
                    );
                } else if (status.state === 'failed') {
                    show(status.error || lang('unexpected_issues_occurred'), 'danger');
                } else {
                    show(lang('import_running') + (status.phase ? ' (' + lang(status.phase) + ')' : ''));
                    poll(importId);
                }
            });
        }, 2000);
    }

    /**
     * Fill the backups table from the server (newest first).
     */
    function loadBackups() {
        $.get(App.Utils.Url.siteUrl('import/backups')).done((response) => {
            const $section = $('#backups-section');
            const $tbody = $('#backups-table tbody');

            $tbody.empty();

            (response.backups || []).forEach((backup) => {
                const $row = $('<tr/>');

                $('<td/>', {'text': backup.date}).appendTo($row);

                ['ods', 'zip'].forEach((kind) => {
                    const file = backup.files[kind];
                    const $cell = $('<td/>').appendTo($row);

                    if (file) {
                        $('<a/>', {
                            'href': App.Utils.Url.siteUrl('import/download_backup?name=' + encodeURIComponent(file.name)),
                            'text': lang(kind === 'ods' ? 'ods_file' : 'zip_file') + ' (' + file.size + ')',
                        }).appendTo($cell);
                    }
                });

                $row.appendTo($tbody);
            });

            $section.toggleClass('d-none', !(response.backups || []).length);
        });
    }

    function setExportWorking(working) {
        const $button = $('#export-data');

        $button.prop('disabled', working);
        $button.find('i').toggleClass('fa-download', !working).toggleClass('fa-spinner fa-spin', working);
        $button.contents().last()[0].textContent = ' ' + lang(working ? 'backup_working' : 'export_data');
    }

    function pollExport(exportId) {
        $.get(App.Utils.Url.siteUrl('import/export_status'), {export_id: exportId}).done((status) => {
            if (status.state === 'completed') {
                setExportWorking(false);
                loadBackups();
                return;
            }

            if (status.state === 'failed' || status.state === 'unknown') {
                setExportWorking(false);
                show(lang('backup_failed'), 'danger');
                return;
            }

            setTimeout(() => pollExport(exportId), 2000);
        });
    }

    function onExportClick() {
        setExportWorking(true);
        $.post(App.Utils.Url.siteUrl('import/export'), {csrf_token: vars('csrf_token')})
            .done((response) => pollExport(response.export_id))
            .fail(() => setExportWorking(false));
    }

    function toggleImagesZip() {
        $('#images-zip-wrapper').toggleClass('d-none', $('#import-type').val() !== 'ods');
    }

    function initialize() {
        $('#export-data').on('click', onExportClick);

        $('#import-type').on('change', toggleImagesZip);
        toggleImagesZip();

        loadBackups();

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
