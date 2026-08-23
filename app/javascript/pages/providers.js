/**
 * Providers page: drives the working plan editor (utils/working_plan.js) from
 * the hidden settings fields of the server rendered form. One editor instance
 * serves every form the frame loads; it is (re)populated on turbo:frame-load.
 */
(function () {
    let workingPlanManager = null;

    function load() {
        const $json = $('#working-plan-json');

        if (!$json.length) {
            return;
        }

        $('.breaks tbody, .working-plan-exceptions tbody').empty();
        workingPlanManager.setup(JSON.parse($json.val()));
        workingPlanManager.setupWorkingPlanExceptions(JSON.parse($('#working-plan-exceptions-json').val()));
        workingPlanManager.timepickers(false);
    }

    // Serialise the editor into the hidden fields before Turbo reads the form;
    // an invalid plan blocks the submit (get() has shown the message).
    function serialise(event) {
        const $form = $(event.target);

        if (!$form.is('.crud-form') || !$('#working-plan-json').length) {
            return;
        }

        const workingPlan = workingPlanManager.get();

        if (workingPlan === null) {
            event.preventDefault();
            event.stopImmediatePropagation();
            return;
        }

        $('#working-plan-json').val(JSON.stringify(workingPlan));
        $('#working-plan-exceptions-json').val(JSON.stringify(workingPlanManager.getWorkingPlanExceptions()));
    }

    function initialize() {
        if (!$('#providers-page').length) {
            return;
        }

        workingPlanManager = new App.Utils.WorkingPlan();
        workingPlanManager.addEventListeners();
        document.addEventListener('submit', serialise, true);
        document.addEventListener('turbo:frame-load', load);
        load();

        $(document).on('click', '#reset-working-plan', (event) => {
            $('.breaks tbody, .working-plan-exceptions tbody').empty();
            $('.work-start, .work-end').val('');
            workingPlanManager.setup(JSON.parse($(event.currentTarget).attr('data-company-working-plan')));
            workingPlanManager.timepickers(false);
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);
})();
