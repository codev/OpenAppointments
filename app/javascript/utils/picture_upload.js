/**
 * Picture upload utility.
 *
 * Binds the #picture-input / #picture-preview / #picture-remove controls of a
 * backend record form to the record's picture endpoint. Pages call setRecord()
 * when a record is displayed and reset() when the form is cleared. A picture chosen
 * while adding a record is held and uploaded once the record's store call succeeds.
 */
window.App.Utils.PictureUpload = (function () {
    let currentEndpoint = null;
    let pendingFile = null;
    let storing = null;

    function setRecord(resource, id, pictureUrl) {
        currentEndpoint = App.Utils.Url.siteUrl(resource + '/' + id + '/picture');
        $('#picture-input').prop('disabled', false).val('');
        renderPreview(pictureUrl);
    }

    function reset() {
        currentEndpoint = null;
        pendingFile = null;
        $('#picture-input').prop('disabled', true).val('');
        renderPreview(null);
    }

    function upload(endpoint, file) {
        const formData = new FormData();
        formData.append('csrf_token', vars('csrf_token'));
        formData.append('picture', file);
        post(formData, endpoint);
    }

    function renderPreview(pictureUrl) {
        if (pictureUrl) {
            $('#picture-preview').attr('src', pictureUrl).removeClass('d-none');
            $('#picture-remove').removeClass('d-none');
        } else {
            $('#picture-preview').attr('src', '').addClass('d-none');
            $('#picture-remove').addClass('d-none');
        }
    }

    function post(formData, endpoint = currentEndpoint) {
        $.ajax({
            url: endpoint,
            method: 'POST',
            data: formData,
            processData: false,
            contentType: false,
        })
            .done((response) => renderPreview(response.picture_url))
            .fail((jqXHR) => {
                const message = jqXHR.responseJSON && jqXHR.responseJSON.message;
                App.Layouts.Backend.displayNotification(message || lang('unexpected_issues_occurred'));
            });
    }

    function initialize() {
        const $input = $('#picture-input');

        if (!$input.length) {
            return;
        }

        $input.on('change', () => {
            if (!$input[0].files.length) {
                return;
            }

            const file = $input[0].files[0];

            if (currentEndpoint) {
                upload(currentEndpoint, file);
                return;
            }

            // New record: preview now, upload after the store call below.
            pendingFile = file;
            renderPreview(URL.createObjectURL(file));
        });

        // The page's store call: remember the pending picture before the page resets the
        // form, then send it to the new record's endpoint.
        $(document).ajaxSend((event, jqXHR, settings) => {
            const match = /\/([a-z_]+)\/store$/.exec(settings.url || '');
            if (match && pendingFile) {
                storing = {resource: match[1], file: pendingFile, jqXHR};
            }
        });

        $(document).ajaxSuccess((event, jqXHR, settings, response) => {
            if (!storing || storing.jqXHR !== jqXHR) {
                return;
            }
            const {resource, file} = storing;
            storing = null;
            if (response && response.success && response.id) {
                upload(App.Utils.Url.siteUrl(resource + '/' + response.id + '/picture'), file);
            }
        });

        $('#picture-remove').on('click', () => {
            if (!currentEndpoint) {
                return;
            }

            const formData = new FormData();
            formData.append('csrf_token', vars('csrf_token'));
            formData.append('remove', '1');
            post(formData);
        });

        reset();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {
        setRecord,
        reset,
    };
})();
