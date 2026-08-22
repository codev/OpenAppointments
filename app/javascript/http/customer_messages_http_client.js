/**
 * Customer messages HTTP client.
 */
App.Http.CustomerMessages = (function () {
    /**
     * Fetch the messages of a customer.
     *
     * @param {Number} customerId
     *
     * @return {Object}
     */
    function find(customerId) {
        const url = App.Utils.Url.siteUrl('customer_messages/find');

        const data = {
            csrf_token: vars('csrf_token'),
            customer_id: customerId,
        };

        return $.post(url, data);
    }

    /**
     * Send a manual message to a customer.
     *
     * @param {Number} customerId
     * @param {String} channel Channel key or "all".
     * @param {String} body
     *
     * @return {Object}
     */
    function send(customerId, channel, body) {
        const url = App.Utils.Url.siteUrl('customer_messages/send');

        const data = {
            csrf_token: vars('csrf_token'),
            customer_id: customerId,
            channel: channel,
            body: body,
        };

        return $.post(url, data);
    }

    /**
     * Mark every incoming message of a customer read.
     *
     * @param {Number} customerId
     *
     * @return {Object}
     */
    function markRead(customerId) {
        const url = App.Utils.Url.siteUrl('customer_messages/mark_read');

        return $.post(url, {csrf_token: vars('csrf_token'), customer_id: customerId});
    }

    return {
        find,
        send,
        markRead,
    };
})();
