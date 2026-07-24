/**
 * Messages notifications HTTP client.
 */
App.Http.MessagesNotifications = (function () {
    /**
     * Save (create or update) a notification template.
     *
     * @param {Object} notification
     *
     * @return {Object}
     */
    function save(notification) {
        const url = App.Utils.Url.siteUrl('messages_notifications/save');

        const data = {
            csrf_token: vars('csrf_token'),
            notification: notification,
        };

        return $.post(url, data);
    }

    /**
     * Delete a notification template.
     *
     * @param {Number} notificationId
     *
     * @return {Object}
     */
    function destroy(notificationId) {
        const url = App.Utils.Url.siteUrl('messages_notifications/destroy');

        const data = {
            csrf_token: vars('csrf_token'),
            notification_id: notificationId,
        };

        return $.post(url, data);
    }

    return {
        save,
        destroy,
    };
})();
