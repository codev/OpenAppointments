/**
 * Business settings: the working plan editor and the status option list are
 * JS widgets; their JSON is written into hidden settings fields on submit.
 */
(function () {
    let workingPlanManager = null;

    function load() {
        const $json = $('#working-plan-json');

        if (!$json.length) {
            return;
        }

        $('.breaks tbody').empty();
        workingPlanManager.setup(JSON.parse($json.val() || '{}'));
        workingPlanManager.timepickers(false);
        App.Components.AppointmentStatusOptions.setOptions(
            $('#appointment-status-options'),
            JSON.parse($('#status-options-json').val() || '[]'),
        );
    }

    function serialise(event) {
        if (!$(event.target).is('#settings-form') || !$('#working-plan-json').length) {
            return;
        }

        const workingPlan = workingPlanManager.get();

        if (workingPlan === null) {
            event.preventDefault();
            event.stopImmediatePropagation();
            return;
        }

        $('#working-plan-json').val(JSON.stringify(workingPlan));
        $('#status-options-json').val(
            JSON.stringify(App.Components.AppointmentStatusOptions.getOptions($('#appointment-status-options'))),
        );
    }

    function onApplyGlobalWorkingPlan() {
        const buttons = [
            {text: lang('cancel'), click: (event, messageModal) => messageModal.hide()},
            {
                text: 'OK',
                click: (event, messageModal) => {
                    const workingPlan = workingPlanManager.get();

                    if (workingPlan === null) {
                        messageModal.hide();
                        return;
                    }

                    $.post(App.Utils.Url.siteUrl('business_settings/apply_global_working_plan'), {
                        csrf_token: vars('csrf_token'),
                        working_plan: JSON.stringify(workingPlan),
                    })
                        .done(() => App.Layouts.Backend.displayNotification(lang('working_plans_got_updated')))
                        .always(() => messageModal.hide());
                },
            },
        ];

        App.Utils.Message.show(lang('working_plan'), lang('overwrite_existing_working_plans'), buttons);
    }

    function initialize() {
        if (!$('#business-logic-page').length) {
            return;
        }

        workingPlanManager = new App.Utils.WorkingPlan();
        workingPlanManager.addEventListeners();
        document.addEventListener('submit', serialise, true);
        document.addEventListener('turbo:frame-load', load);
        load();
        $(document).on('click', '#apply-global-working-plan', onApplyGlobalWorkingPlan);
    }

    document.addEventListener('DOMContentLoaded', initialize);
})();
