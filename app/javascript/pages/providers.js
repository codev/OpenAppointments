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
 * Providers page.
 *
 * This module implements the functionality of the providers page.
 */
App.Pages.Providers = (function () {
    const $providers = $('#providers');
    const $id = $('#id');
    const $name = $('#name');
    const $email = $('#email');
    const $mobileNumber = $('#mobile-number');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $state = $('#state');
    const $zipCode = $('#zip-code');
    const $isPrivate = $('#is-private');
    const $notes = $('#notes');
    const $about = $('#about');
    const $servicesDescription = $('#services-description');
    const $language = $('#language');
    const $timezone = $('#timezone');
    const $ldapDn = $('#ldap-dn');
    const $username = $('#username');
    const $password = $('#password');
    const $passwordConfirmation = $('#password-confirm');
    const $filterProviders = $('#filter-providers');
    let filterResults = {};
    const filterLimit = 10000;

    let filterPage = 1;
    let workingPlanManager;

    /**
     * Add the page event listeners.
     */
    function addEventListeners() {
        /**
         * Event: Filter Providers Form "Submit"
         *
         * Filter the provider records with the given key string.
         *
         * @param {jQuery.Event} event
         */
        $providers.on('submit', '#filter-providers form', (event) => {
            event.preventDefault();
            const key = $('#filter-providers .key').val();
            $('.selected').removeClass('selected');
            filterPage = 1;
            App.Pages.Providers.resetForm();
            App.Pages.Providers.filter(key);
        });

        /**
         * Event: Filter Provider Row "Click"
         *
         * Display the selected provider data to the user.
         */
        $providers.on('click', '.provider-row', (event) => {
            if ($filterProviders.find('.filter').prop('disabled')) {
                $filterProviders.find('.results').css('color', '#AAA');
                return; // Exit because we are currently on edit mode.
            }

            const providerId = $(event.currentTarget).attr('data-id');
            const provider = filterResults.find((filterResult) => Number(filterResult.id) === Number(providerId));

            App.Pages.Providers.display(provider);
            $filterProviders.find('.selected').removeClass('selected');
            $(event.currentTarget).addClass('selected');
            $('#edit-provider, #delete-provider').prop('disabled', false);

            // Automatically enter edit mode
            $('#providers-page').addClass('editing');
            $providers.find('.add-edit-delete-group').hide();
            $providers.find('.save-cancel-group').show();
            $providers.find('#delete-provider, #regenerate-provider-link').show(); // Show delete/regenerate when editing
            $filterProviders.find('button').prop('disabled', true);
            $filterProviders.find('.results').css('color', '#AAA');
            $providers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $providers.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').removeClass('required');
            $('#provider-services input:checkbox').prop('disabled', false);
            $('#select-all-services, #select-none-services').prop('disabled', false);
            $providers
                .find(
                    '.add-break, .edit-break, .delete-break, .add-working-plan-exception, .edit-working-plan-exception, .delete-working-plan-exception, #reset-working-plan',
                )
                .prop('disabled', false);
            $('#providers input:checkbox').prop('disabled', false);
            workingPlanManager.timepickers(false);
        });

        /**
         * Event: Add New Provider Button "Click"
         */
        $providers.on('click', '#add-provider', () => {
            App.Pages.Providers.resetForm();
            $('#providers-page').addClass('editing');
            $filterProviders.find('button').prop('disabled', true);
            $filterProviders.find('.results').css('color', '#AAA');
            $providers.find('.add-edit-delete-group').hide();
            $providers.find('.save-cancel-group').show();
            $providers.find('#delete-provider, #regenerate-provider-link').hide(); // Hide delete/regenerate when adding
            $providers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $providers.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').addClass('required');
            $providers
                .find(
                    '.add-break, .edit-break, .delete-break, .add-working-plan-exception, .edit-working-plan-exception, .delete-working-plan-exception, #reset-working-plan',
                )
                .prop('disabled', false);
            $('#provider-services input:checkbox').prop('disabled', false);
            $('#select-all-services, #select-none-services').prop('disabled', false);

            // Apply default working plan
            const companyWorkingPlan = JSON.parse(vars('company_working_plan'));
            workingPlanManager.setup(companyWorkingPlan);
            workingPlanManager.timepickers(false);
        });

        /**
         * Event: Edit Provider Button "Click"
         */
        $providers.on('click', '#edit-provider', () => {
            $('#providers-page').addClass('editing');
            $providers.find('.add-edit-delete-group').hide();
            $providers.find('.save-cancel-group').show();
            $filterProviders.find('button').prop('disabled', true);
            $filterProviders.find('.results').css('color', '#AAA');
            $providers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $providers.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').removeClass('required');
            $('#provider-services input:checkbox').prop('disabled', false);
            $('#select-all-services, #select-none-services').prop('disabled', false);
            $providers
                .find(
                    '.add-break, .edit-break, .delete-break, .add-working-plan-exception, .edit-working-plan-exception, .delete-working-plan-exception, #reset-working-plan',
                )
                .prop('disabled', false);
            $('#providers input:checkbox').prop('disabled', false);
            workingPlanManager.timepickers(false);
        });

        /**
         * Event: Delete Provider Button "Click"
         */
        $providers.on('click', '#delete-provider', () => {
            const providerId = $id.val();

            const buttons = [
                {
                    text: lang('cancel'),
                    click: (event, messageModal) => {
                        messageModal.hide();
                    },
                },
                {
                    text: lang('delete'),
                    click: (event, messageModal) => {
                        App.Pages.Providers.remove(providerId);
                        messageModal.hide();
                    },
                },
            ];

            App.Utils.Message.show(lang('delete_provider'), lang('delete_record_prompt'), buttons);
        });

        /**
         * Event: Regenerate Link Button "Click"
         *
         * Issue a fresh booking slug for the provider after a confirmation.
         */
        $providers.on('click', '#regenerate-provider-link', () => {
            const providerId = $id.val();

            if (!providerId) {
                return;
            }

            const buttons = [
                {
                    text: lang('cancel'),
                    click: (event, messageModal) => {
                        messageModal.hide();
                    },
                },
                {
                    text: lang('change'),
                    className: 'btn btn-danger',
                    click: (event, messageModal) => {
                        $.post(App.Utils.Url.siteUrl('providers/regenerate_link'), {
                            csrf_token: vars('csrf_token'),
                            provider_id: providerId,
                        }).done((response) => {
                            const url = App.Utils.Url.siteUrl(
                                '?provider=' + encodeURIComponent(response.booking_slug),
                            );
                            $providers.find('.details-view h4 a').attr('href', url);
                            messageModal.hide();
                        });
                    },
                },
            ];

            App.Utils.Message.show(lang('regenerate_link'), lang('regenerate_link_warning_provider'), buttons);
        });

        /**
         * Event: Save Provider Button "Click"
         */
        $providers.on('click', '#save-provider', () => {
            const workingPlan = workingPlanManager.get();

            if (workingPlan === null) {
                return;
            }

            const provider = {
                name: $name.val(),
                email: $email.val(),
                mobile_number: $mobileNumber.val(),
                phone_number: $phoneNumber.val(),
                address: $address.val(),
                city: $city.val(),
                state: $state.val(),
                zip_code: $zipCode.val(),
                is_private: Number($isPrivate.prop('checked')),
                notes: $notes.val(),
                about: $about.val(),
                services_description: $servicesDescription.val(),
                language: $language.val(),
                timezone: $timezone.val(),
                ldap_dn: $ldapDn.val(),
                settings: {
                    username: $username.val(),
                    working_plan: JSON.stringify(workingPlan),
                    working_plan_exceptions: JSON.stringify(workingPlanManager.getWorkingPlanExceptions()),
                },
            };

            // Include provider services.
            provider.services = [];
            $('#provider-services input:checkbox').each((index, checkboxEl) => {
                if ($(checkboxEl).prop('checked')) {
                    provider.services.push($(checkboxEl).attr('data-id'));
                }
            });

            // Include password if changed.
            if ($password.val() !== '') {
                provider.settings.password = $password.val();
            }

            // Include id if changed.
            if ($id.val() !== '') {
                provider.id = $id.val();
            }

            if (!App.Pages.Providers.validate()) {
                return;
            }

            App.Pages.Providers.save(provider);
        });

        /**
         * Event: Cancel Provider Button "Click"
         *
         * Cancel add or edit of an provider record.
         */
        $providers.on('click', '#cancel-provider', () => {
            const id = $('#filter-providers .selected').attr('data-id');
            App.Pages.Providers.resetForm();
            $('#providers-page').removeClass('editing');
            if (id) {
                App.Pages.Providers.select(id, true);
            }
        });

        /**
         * Event: Reset Working Plan Button "Click".
         */
        $providers.on('click', '#reset-working-plan', () => {
            $('.breaks tbody').empty();
            $('.working-plan-exceptions tbody').empty();
            $('.work-start, .work-end').val('');
            const companyWorkingPlan = JSON.parse(vars('company_working_plan'));
            workingPlanManager.setup(companyWorkingPlan);
            workingPlanManager.timepickers(false);
        });

        /**
         * Event: Select All Services Button "Click"
         */
        $providers.on('click', '#select-all-services', () => {
            $('#provider-services input:checkbox').prop('checked', true);
        });

        /**
         * Event: Select None Services Button "Click"
         */
        $providers.on('click', '#select-none-services', () => {
            $('#provider-services input:checkbox').prop('checked', false);
        });
    }

    /**
     * Save provider record to database.
     *
     * @param {Object} provider Contains the provider record data. If an 'id' value is provided
     * then the update operation is going to be executed.
     */
    function save(provider) {
        App.Http.Providers.save(provider).then((response) => {
            if (response.success === false) {
                $('#providers .form-message').addClass('alert-danger').text(response.message).show();
                return;
            }

            App.Layouts.Backend.displayNotification(lang('provider_saved'));
            App.Pages.Providers.resetForm();
            $('#providers-page').removeClass('editing');
            $('#filter-providers .key').val('');
            App.Pages.Providers.filter('', response.id, true);
        });
    }

    /**
     * Delete a provider record from database.
     *
     * @param {Number} id Record id to be deleted.
     */
    function remove(id) {
        App.Http.Providers.destroy(id).then(() => {
            App.Layouts.Backend.displayNotification(lang('provider_deleted'));
            App.Pages.Providers.resetForm();
            $('#providers-page').removeClass('editing');
            App.Pages.Providers.filter($('#filter-providers .key').val());
        });
    }

    /**
     * Validates a provider record.
     *
     * @return {Boolean} Returns the validation result.
     */
    function validate() {
        $providers.find('.is-invalid').removeClass('is-invalid');
        $providers.find('.form-message').removeClass('alert-danger').hide();

        try {
            // Validate required fields.
            let missingRequired = false;

            $providers.find('.required').each((index, requiredFieldEl) => {
                if (!$(requiredFieldEl).val()) {
                    $(requiredFieldEl).addClass('is-invalid');
                    missingRequired = true;
                }
            });

            if (missingRequired) {
                throw new Error(lang('fields_are_required'));
            }

            // Validate passwords.
            if ($password.val() !== $passwordConfirmation.val()) {
                $('#password, #password-confirm').addClass('is-invalid');
                throw new Error(lang('passwords_mismatch'));
            }

            if ($password.val().length < vars('min_password_length') && $password.val() !== '') {
                $('#password, #password-confirm').addClass('is-invalid');
                throw new Error(lang('password_length_notice').replace('$number', vars('min_password_length')));
            }

            // Validate user email.
            if (!App.Utils.Validation.email($email.val())) {
                $email.addClass('is-invalid');
                throw new Error(lang('invalid_email'));
            }

            // Validate phone number.
            const phoneNumber = $phoneNumber.val();

            if (phoneNumber && !App.Utils.Validation.phone(phoneNumber)) {
                $phoneNumber.addClass('is-invalid');
                throw new Error(lang('invalid_phone'));
            }

            // Validate mobile number.
            const mobileNumber = $mobileNumber.val();

            if (mobileNumber && !App.Utils.Validation.phone(mobileNumber)) {
                $mobileNumber.addClass('is-invalid');
                throw new Error(lang('invalid_phone'));
            }

            // Check if username exists
            if ($username.attr('already-exists') === 'true') {
                $username.addClass('is-invalid');
                throw new Error(lang('username_already_exists'));
            }

            return true;
        } catch (error) {
            $('#providers .form-message').addClass('alert-danger').text(error.message).show();
            return false;
        }
    }

    /**
     * Resets the provider tab form back to its initial state.
     */
    function resetForm() {
        App.Utils.PictureUpload.reset();
        $filterProviders.find('.selected').removeClass('selected');
        $filterProviders.find('button').prop('disabled', false);
        $filterProviders.find('.results').css('color', '');

        $providers.find('.add-edit-delete-group').show();
        $providers.find('.save-cancel-group').hide();
        $providers.find('.record-details h4 a').remove();
        $providers.find('.record-details').find('input, select, textarea').val('').prop('disabled', true);
        $providers.find('.record-details .form-label span').prop('hidden', true);
        $providers.find('.record-details #language').val(vars('default_language'));
        $providers.find('.record-details #timezone').val(vars('default_timezone'));
        $providers.find('.record-details #is-private').prop('checked', false);
        $providers.find('.add-break, .add-working-plan-exception, #reset-working-plan').prop('disabled', true);

        workingPlanManager.timepickers(true);
        $providers.find('#providers .working-plan input:checkbox').prop('disabled', true);
        $('.breaks').find('.edit-break, .delete-break').prop('disabled', true);
        $('.working-plan-exceptions')
            .find('.edit-working-plan-exception, .delete-working-plan-exception')
            .prop('disabled', true);

        $providers.find('.record-details .is-invalid').removeClass('is-invalid');
        $providers.find('.record-details .form-message').hide();

        $('#edit-provider, #delete-provider').prop('disabled', true);
        $('#provider-services input:checkbox').prop('disabled', true).prop('checked', false);
        $('#select-all-services, #select-none-services').prop('disabled', true);
        $('#provider-services a').remove();
        $('#providers .working-plan tbody').empty();
        $('#providers .breaks tbody').empty();
        $('#providers .working-plan-exceptions tbody').empty();
    }

    /**
     * Display a provider record into the provider form.
     *
     * @param {Object} provider Contains the provider record data.
     */
    function display(provider) {
        App.Utils.PictureUpload.setRecord('providers', provider.id, provider.picture_url);
        $id.val(provider.id);
        $name.val(provider.name);
        $email.val(provider.email);
        $mobileNumber.val(provider.mobile_number);
        $phoneNumber.val(provider.phone_number);
        $address.val(provider.address);
        $city.val(provider.city);
        $state.val(provider.state);
        $zipCode.val(provider.zip_code);
        $isPrivate.prop('checked', provider.is_private);
        $notes.val(provider.notes);
        $about.val(provider.about);
        $servicesDescription.val(provider.services_description);
        $language.val(provider.language);
        $timezone.val(provider.timezone);
        $ldapDn.val(provider.ldap_dn);

        $username.val(provider.settings.username);

        // Add dedicated provider link (slugged so it cannot be guessed).
        let dedicatedUrl = App.Utils.Url.siteUrl('?provider=' + encodeURIComponent(provider.booking_slug));
        let $link = $('<a/>', {
            'href': dedicatedUrl,
            'target': '_blank',
            'data-bs-toggle': 'tooltip',
            'title': lang('booking_link'),
            'aria-label': lang('booking_link'),
            'html': [
                $('<i/>', {
                    'class': 'fas fa-link',
                }),
            ],
        });

        $providers.find('.details-view h4').find('a').remove().end().append($link);
        new bootstrap.Tooltip($link[0]);

        $('#provider-services a').remove();
        $('#provider-services input:checkbox').prop('checked', false);

        provider.services.forEach((providerServiceId) => {
            const $checkbox = $('#provider-services input[data-id="' + providerServiceId + '"]');

            if (!$checkbox.length) {
                return;
            }

            $checkbox.prop('checked', true);

            // Add dedicated service-provider link (slugged so it cannot be guessed).
            const linkedService = (vars('services') || []).find(
                (service) => Number(service.id) === Number(providerServiceId),
            );

            if (!linkedService || !linkedService.booking_slug) {
                return;
            }

            dedicatedUrl = App.Utils.Url.siteUrl(
                '?provider=' + encodeURIComponent(provider.booking_slug) +
                '&service=' + encodeURIComponent(linkedService.booking_slug),
            );

            $link = $('<a/>', {
                'href': dedicatedUrl,
                'target': '_blank',
                'class': 'ms-2',
                'data-bs-toggle': 'tooltip',
                'title': lang('booking_link'),
                'aria-label': lang('booking_link'),
                'html': [
                    $('<i/>', {
                        'class': 'fas fa-link',
                    }),
                ],
            });

            $checkbox.parent().append($link);
            new bootstrap.Tooltip($link[0]);
        });

        // Display working plan
        const workingPlan = JSON.parse(provider.settings.working_plan);
        workingPlanManager.setup(workingPlan);
        $('.working-plan').find('input').prop('disabled', true);
        $('.breaks').find('.edit-break, .delete-break').prop('disabled', true);
        $providers.find('.working-plan-exceptions tbody').empty();
        const workingPlanExceptions = JSON.parse(provider.settings.working_plan_exceptions);
        workingPlanManager.setupWorkingPlanExceptions(workingPlanExceptions);
        $('.working-plan-exceptions')
            .find('.edit-working-plan-exception, .delete-working-plan-exception')
            .prop('disabled', true);
        $providers.find('.working-plan input:checkbox').prop('disabled', true);
    }

    /**
     * Filters provider records depending a string keyword.
     *
     * @param {string} keyword This is used to filter the provider records of the database.
     * @param {numeric} selectId Optional, if set, when the function is complete a result row can be set as selected.
     * @param {bool} show Optional (false), if true the selected record will be also displayed.
     */
    function filter(keyword, selectId = null, show = false) {
        App.Http.Providers.search(keyword, filterLimit, (filterPage - 1) * filterLimit).then((response, textStatus, jqXHR) => {
            filterResults = response;

            $filterProviders.find('.results').empty();
            response.forEach((provider) => {
                $('#filter-providers .results').append(App.Pages.Providers.getFilterHtml(provider)).append($('<hr/>'));
            });

            if (!response.length) {
                $filterProviders.find('.results').append(
                    $('<em/>', {
                        'text': lang('no_records_found'),
                    }),
                );
            }

            App.Utils.Pagination.render(
                $('#filter-providers .results'),
                Number(jqXHR.getResponseHeader('X-Total-Count')) || response.length,
                filterPage,
                filterLimit,
                (page) => {
                    filterPage = page;
                    App.Pages.Providers.filter(keyword, selectId, show);
                },
            );

            if (selectId) {
                App.Pages.Providers.select(selectId, show);
            }
        });
    }

    /**
     * Get an provider row html code that is going to be displayed on the filter results list.
     *
     * @param {Object} provider Contains the provider record data.
     *
     * @return {String} The html code that represents the record on the filter results list.
     */
    function getFilterHtml(provider) {
        const name = provider.name;

        let info = provider.email;

        info = provider.mobile_number ? info + ', ' + provider.mobile_number : info;

        info = provider.phone_number ? info + ', ' + provider.phone_number : info;

        return $('<div/>', {
            'class': 'provider-row entry',
            'draggable': true,
            'data-id': provider.id,
            'html': [
                $('<strong/>', {
                    'text': name,
                }),
                $('<br/>'),
                $('<small/>', {
                    'class': 'text-muted',
                    'text': info,
                }),
                $('<br/>'),
            ],
        });
    }

    /**
     * Select and display a providers filter result on the form.
     *
     * @param {Number} id Record id to be selected.
     * @param {Boolean} show Optional (false), if true the record will be displayed on the form.
     */
    function select(id, show = false) {
        // Select record in filter results.
        $filterProviders.find('.provider-row[data-id="' + id + '"]').addClass('selected');

        // Display record in form (if display = true).
        if (show) {
            const provider = filterResults.find((filterResult) => Number(filterResult.id) === Number(id));

            App.Pages.Providers.display(provider);

            $('#edit-provider, #delete-provider').prop('disabled', false);
        }
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        workingPlanManager = new App.Utils.WorkingPlan();
        workingPlanManager.addEventListeners();

        App.Pages.Providers.resetForm();
        App.Pages.Providers.filter('');
        App.Pages.Providers.addEventListeners();

        vars('services').forEach((service) => {
            const checkboxId = `provider-service-${service.id}`;

            $('<div/>', {
                'class': 'checkbox',
                'html': [
                    $('<div/>', {
                        'class': 'checkbox form-check',
                        'html': [
                            $('<input/>', {
                                'id': checkboxId,
                                'class': 'form-check-input',
                                'type': 'checkbox',
                                'data-id': service.id,
                                'prop': {
                                    'disabled': true,
                                },
                            }),
                            $('<label/>', {
                                'class': 'form-check-label',
                                'text': service.name,
                                'for': checkboxId,
                            }),
                        ],
                    }),
                ],
            }).appendTo('#provider-services');
        });
    }


    /**
     * Drag-to-reorder: persist the dragged order, blocked while filtering.
     */
    function initializeReorder() {
        App.Utils.DragReorder.enable(
            $('#filter-providers .results'),
            '.provider-row',
            () => !$('#filter-providers .key').val(),
            (ids) => {
                $.post(App.Utils.Url.siteUrl('providers/reorder'), {csrf_token: vars('csrf_token'), ids: ids});
            },
        );

        $('.sort-alphabetically').on('click', () => {
            const buttons = [
                {
                    text: lang('cancel'),
                    click: (event, messageModal) => {
                        messageModal.hide();
                    },
                },
                {
                    text: lang('sort_alphabetically'),
                    click: (event, messageModal) => {
                        $.post(App.Utils.Url.siteUrl('providers/sort_alphabetically'), {csrf_token: vars('csrf_token')}).done(() => {
                            $('#filter-providers .key').val('');
                            $('#filter-providers .key').parents('form').trigger('submit');
                        });
                        messageModal.hide();
                    },
                },
            ];

            App.Utils.Message.show(lang('sort_alphabetically'), lang('sort_alphabetically_confirm'), buttons);
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);
    document.addEventListener('DOMContentLoaded', initializeReorder);

    return {
        filter,
        save,
        remove,
        validate,
        getFilterHtml,
        resetForm,
        display,
        select,
        addEventListeners,
    };
})();
