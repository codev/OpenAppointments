/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Assistants HTTP client.
 *
 * This module implements the assistants related HTTP requests.
 */
App.Http.Assistants = (function () {
    /**
     * Save (create or update) a assistant.
     *
     * @param {Object} assistant
     *
     * @return {Object}
     */
    function save(assistant) {
        return assistant.id ? update(assistant) : store(assistant);
    }

    /**
     * Create a assistant.
     *
     * @param {Object} assistant
     *
     * @return {Object}
     */
    function store(assistant) {
        const url = App.Utils.Url.siteUrl('assistants/store');

        const data = {
            csrf_token: vars('csrf_token'),
            assistant: assistant,
        };

        return $.post(url, data);
    }

    /**
     * Update a assistant.
     *
     * @param {Object} assistant
     *
     * @return {Object}
     */
    function update(assistant) {
        const url = App.Utils.Url.siteUrl('assistants/update');

        const data = {
            csrf_token: vars('csrf_token'),
            assistant: assistant,
        };

        return $.post(url, data);
    }

    /**
     * Delete a assistant.
     *
     * @param {Number} assistantId
     *
     * @return {Object}
     */
    function destroy(assistantId) {
        const url = App.Utils.Url.siteUrl('assistants/destroy');

        const data = {
            csrf_token: vars('csrf_token'),
            assistant_id: assistantId,
        };

        return $.post(url, data);
    }

    /**
     * Search assistants by keyword.
     *
     * @param {String} keyword
     * @param {Number} [limit]
     * @param {Number} [offset]
     * @param {String} [orderBy]
     *
     * @return {Object}
     */
    function search(keyword, limit = null, offset = null, orderBy = null) {
        const url = App.Utils.Url.siteUrl('assistants/search');

        const data = {
            csrf_token: vars('csrf_token'),
            keyword,
            limit,
            offset,
            order_by: orderBy || undefined,
        };

        return $.post(url, data);
    }

    /**
     * Find a assistant.
     *
     * @param {Number} assistantId
     *
     * @return {Object}
     */
    function find(assistantId) {
        const url = App.Utils.Url.siteUrl('assistants/find');

        const data = {
            csrf_token: vars('csrf_token'),
            assistant_id: assistantId,
        };

        return $.post(url, data);
    }

    return {
        save,
        store,
        update,
        destroy,
        search,
        find,
    };
})();
