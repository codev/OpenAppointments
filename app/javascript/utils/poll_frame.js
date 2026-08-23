/**
 * turbo-frame[data-poll-every] reloads itself every N ms while the attribute
 * is present in the newly loaded content (server side progress: imports, backups).
 */
(function () {
    const timers = new WeakMap();

    function schedule(frame) {
        clearTimeout(timers.get(frame));
        const every = Number(frame.dataset.pollEvery);
        if (every > 0 && frame.src) {
            timers.set(frame, setTimeout(() => frame.reload(), every));
        }
    }

    document.addEventListener('turbo:frame-load', (event) => schedule(event.target));
    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('turbo-frame[data-poll-every]').forEach(schedule);
    });
})();
