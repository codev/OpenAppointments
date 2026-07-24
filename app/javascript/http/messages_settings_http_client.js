/**
 * Messages settings HTTP client (shared by the Messages settings pages).
 */
App.Http.MessagesSettings = (function () {
    /**
     * Save a settings row list to the given endpoint.
     *
     * @param {String} path Endpoint path, e.g. "messages_settings/save".
     * @param {String} key Payload key the controller reads the rows from.
     * @param {Array} rows [{name, value}, ...]
     *
     * @return {Object}
     */
    function save(path, key, rows) {
        const url = App.Utils.Url.siteUrl(path);

        const data = {
            csrf_token: vars('csrf_token'),
        };

        data[key] = rows;

        return $.post(url, data);
    }

    return {
        save,
    };
})();
