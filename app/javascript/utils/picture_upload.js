/**
 * Picture upload utility.
 *
 * Binds the #picture-input / #picture-preview / #picture-remove controls of a
 * backend record form to the record's picture endpoint. Pages call setRecord()
 * when a record is displayed and reset() when the form is cleared.
 */
window.App.Utils.PictureUpload = (function () {
    let currentEndpoint = null;

    function setRecord(resource, id, pictureUrl) {
        currentEndpoint = App.Utils.Url.siteUrl(resource + '/' + id + '/picture');
        $('#picture-input').prop('disabled', false).val('');
        renderPreview(pictureUrl);
    }

    function reset() {
        currentEndpoint = null;
        $('#picture-input').prop('disabled', true).val('');
        renderPreview(null);
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

    function post(formData) {
        $.ajax({
            url: currentEndpoint,
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
            if (!currentEndpoint || !$input[0].files.length) {
                return;
            }

            const formData = new FormData();
            formData.append('csrf_token', vars('csrf_token'));
            formData.append('picture', $input[0].files[0]);
            post(formData);
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
