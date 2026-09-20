/**
 * Tabs: buttons with role=tab inside a tablist show the panel named by their
 * aria-controls and hide the tablist's other panels.
 */
App.Utils.Tabs = (function () {
    function select(tab) {
        const list = tab.closest('[role="tablist"]');
        list.querySelectorAll('[role="tab"]').forEach((other) => {
            const selected = other === tab;
            other.setAttribute('aria-selected', String(selected));
            const panel = document.getElementById(other.getAttribute('aria-controls'));
            if (panel) {
                panel.hidden = !selected;
            }
        });
        tab.dispatchEvent(new CustomEvent('tab:shown', {bubbles: true}));
    }

    document.addEventListener('click', (event) => {
        const tab = event.target.closest('[role="tablist"] [role="tab"]');
        if (tab) {
            event.preventDefault();
            select(tab);
        }
    });

    return {
        select,
    };
})();
