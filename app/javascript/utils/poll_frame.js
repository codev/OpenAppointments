/**
 * turbo-frame[data-poll-every][data-poll-src] reloads itself from the poll
 * address every N ms while the attributes are present in the newly loaded
 * content (server side progress: imports, backups). The frame carries no src
 * of its own: a frame whose src is the page it sits in is refused by Turbo.
 */
(function () {
    const timers = new WeakMap();

    function poll(frame) {
        const url = frame.dataset.pollSrc;
        if (frame.getAttribute('src') === url) {
            frame.reload();
        } else {
            frame.src = url;
        }
    }

    function schedule(frame) {
        clearTimeout(timers.get(frame));
        const every = Number(frame.dataset.pollEvery);
        if (every > 0 && frame.dataset.pollSrc) {
            timers.set(frame, setTimeout(() => poll(frame), every));
        }
    }

    document.addEventListener('turbo:frame-load', (event) => schedule(event.target));
    document.addEventListener('turbo:load', () => {
        document.querySelectorAll('turbo-frame[data-poll-every]').forEach(schedule);
    });
})();
