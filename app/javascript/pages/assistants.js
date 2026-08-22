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
 * Assistants page.
 *
 * This module implements the functionality of the assistants page.
 */
App.Pages.Assistants = (function () {
    const $assistants = $('#assistants');
    const $id = $('#id');
    const $name = $('#name');
    const $email = $('#email');
    const $mobileNumber = $('#mobile-number');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $state = $('#state');
    const $zipCode = $('#zip-code');
    const $notes = $('#notes');
    const $language = $('#language');
    const $timezone = $('#timezone');
    const $ldapDn = $('#ldap-dn');
    const $username = $('#username');
    const $password = $('#password');
    const $passwordConfirmation = $('#password-confirm');
    const $filterAssistants = $('#filter-assistants');
    let filterResults = {};
    const filterLimit = 20;

    let filterPage = 1;

    /**
     * Add the page event listeners.
     */
    function addEventListeners() {
        /**
         * Event: Admin Username "Blur"
         *
         * When the admin leaves the username input field we will need to check if the username
         * is not taken by another record in the system.
         *
         * @param {jQuery.Event} event
         */
        $assistants.on('blur', '#username', (event) => {
            const $input = $(event.target);

            if ($input.prop('readonly') === true || $input.val() === '') {
                return;
            }

            const assistantId = $input.parents().eq(2).find('.record-id').val();

            if (!assistantId) {
                return;
            }

            const username = $input.val();

            App.Http.Account.validateUsername(assistantId, username).done((response) => {
                if (response.is_valid === 'false') {
                    $input.addClass('is-invalid');
                    $input.attr('already-exists', 'true');
                    $input.parents().eq(3).find('.form-message').text(lang('username_already_exists'));
                    $input.parents().eq(3).find('.form-message').show();
                } else {
                    $input.removeClass('is-invalid');
                    $input.attr('already-exists', 'false');
                    if ($input.parents().eq(3).find('.form-message').text() === lang('username_already_exists')) {
                        $input.parents().eq(3).find('.form-message').hide();
                    }
                }
            });
        });

        /**
         * Event: Filter Assistants Form "Submit"
         *
         * Filter the assistant records with the given key string.
         *
         * @param {jQuery.Event} event
         */
        $assistants.on('submit', '#filter-assistants form', (event) => {
            event.preventDefault();
            const key = $('#filter-assistants .key').val();
            $filterAssistants.find('.selected').removeClass('selected');
            filterPage = 1;
            App.Pages.Assistants.resetForm();
            App.Pages.Assistants.filter(key);
        });

        /**
         * Event: Filter Assistant Row "Click"
         *
         * Display the selected assistant data to the user.
         */
        $assistants.on('click', '.assistant-row', (event) => {
            if ($('#filter-assistants .filter').prop('disabled')) {
                $('#filter-assistants .results').css('color', '#AAA');
                return; // exit because we are currently on edit mode
            }

            const assistantId = $(event.currentTarget).attr('data-id');

            const assistant = filterResults.find((filterResult) => Number(filterResult.id) === Number(assistantId));

            App.Pages.Assistants.display(assistant);

            $('#filter-assistants .selected').removeClass('selected');
            $(event.currentTarget).addClass('selected');
            $('#edit-assistant, #delete-assistant').prop('disabled', false);

            // Automatically enter edit mode
            $('#assistants-page').addClass('editing');
            $filterAssistants.find('button').prop('disabled', true);
            $filterAssistants.find('.results').css('color', '#AAA');
            $assistants.find('.add-edit-delete-group').hide();
            $assistants.find('.save-cancel-group').show();
            $assistants.find('#delete-assistant').show(); // Show delete button when editing
            $assistants.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $assistants.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').removeClass('required');
            $('#assistant-providers input:checkbox').prop('disabled', false);
            $('#select-all-providers, #select-none-providers').prop('disabled', false);
        });

        /**
         * Event: Add New Assistant Button "Click"
         */
        $assistants.on('click', '#add-assistant', () => {
            App.Pages.Assistants.resetForm();
            $('#assistants-page').addClass('editing');
            $filterAssistants.find('button').prop('disabled', true);
            $filterAssistants.find('.results').css('color', '#AAA');

            $assistants.find('.add-edit-delete-group').hide();
            $assistants.find('.save-cancel-group').show();
            $assistants.find('#delete-assistant').hide(); // Hide delete button when adding
            $assistants.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $assistants.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').addClass('required');
            $('#assistant-providers input:checkbox').prop('disabled', false);
            $('#select-all-providers, #select-none-providers').prop('disabled', false);
        });

        /**
         * Event: Edit Assistant Button "Click"
         */
        $assistants.on('click', '#edit-assistant', () => {
            $('#assistants-page').addClass('editing');
            $filterAssistants.find('button').prop('disabled', true);
            $filterAssistants.find('.results').css('color', '#AAA');
            $assistants.find('.add-edit-delete-group').hide();
            $assistants.find('.save-cancel-group').show();
            $assistants.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $assistants.find('.record-details .form-label span').prop('hidden', false);
            $('#password, #password-confirm').removeClass('required');
            $('#assistant-providers input:checkbox').prop('disabled', false);
            $('#select-all-providers, #select-none-providers').prop('disabled', false);
        });

        /**
         * Event: Delete Assistant Button "Click"
         */
        $assistants.on('click', '#delete-assistant', () => {
            const assistantId = $id.val();

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
                        remove(assistantId);
                        messageModal.hide();
                    },
                },
            ];

            App.Utils.Message.show(lang('delete_assistant'), lang('delete_record_prompt'), buttons);
        });

        /**
         * Event: Save Assistant Button "Click"
         */
        $assistants.on('click', '#save-assistant', () => {
            const assistant = {
                name: $name.val(),
                email: $email.val(),
                mobile_number: $mobileNumber.val(),
                phone_number: $phoneNumber.val(),
                address: $address.val(),
                city: $city.val(),
                state: $state.val(),
                zip_code: $zipCode.val(),
                notes: $notes.val(),
                language: $language.val(),
                timezone: $timezone.val(),
                ldap_dn: $ldapDn.val(),
                settings: {
                    username: $username.val(),
                },
            };

            // Include assistant services.
            assistant.providers = [];

            $('#assistant-providers input:checkbox').each((index, checkbox) => {
                if ($(checkbox).prop('checked')) {
                    assistant.providers.push($(checkbox).attr('data-id'));
                }
            });

            // Include password if changed.
            if ($password.val() !== '') {
                assistant.settings.password = $password.val();
            }

            // Include ID if changed.
            if ($id.val() !== '') {
                assistant.id = $id.val();
            }

            if (!App.Pages.Assistants.validate()) {
                return;
            }

            App.Pages.Assistants.save(assistant);
        });

        /**
         * Event: Cancel Assistant Button "Click"
         *
         * Cancel add or edit of an assistant record.
         */
        $assistants.on('click', '#cancel-assistant', () => {
            const id = $id.val();
            resetForm();
            $('#assistants-page').removeClass('editing');
            if (id) {
                select(id, true);
            }
        });

        /**
         * Event: Select All Providers Button "Click"
         */
        $assistants.on('click', '#select-all-providers', () => {
            $('#assistant-providers input:checkbox').prop('checked', true);
        });

        /**
         * Event: Select None Providers Button "Click"
         */
        $assistants.on('click', '#select-none-providers', () => {
            $('#assistant-providers input:checkbox').prop('checked', false);
        });
    }

    /**
     * Save assistant record to database.
     *
     * @param {Object} assistant Contains the assistant record data. If an 'id' value is provided
     * then the update operation is going to be executed.
     */
    function save(assistant) {
        App.Http.Assistants.save(assistant).done((response) => {
            if (response.success === false) {
                $('#assistants .form-message').addClass('alert-danger').text(response.message).show();
                return;
            }

            App.Layouts.Backend.displayNotification(lang('assistant_saved'));
            App.Pages.Assistants.resetForm();
            $('#assistants-page').removeClass('editing');
            $('#filter-assistants .key').val('');
            App.Pages.Assistants.filter('', response.id, true);
        });
    }

    /**
     * Delete a assistant record from database.
     *
     * @param {Number} id Record id to be deleted.
     */
    function remove(id) {
        App.Http.Assistants.destroy(id).done(() => {
            App.Layouts.Backend.displayNotification(lang('assistant_deleted'));
            App.Pages.Assistants.resetForm();
            $('#assistants-page').removeClass('editing');
            App.Pages.Assistants.filter($('#filter-assistants .key').val());
        });
    }

    /**
     * Validates a assistant record.
     *
     * @return {Boolean} Returns the validation result.
     */
    function validate() {
        $('#assistants .is-invalid').removeClass('is-invalid');
        $assistants.find('.form-message').removeClass('alert-danger');

        try {
            // Validate required fields.
            let missingRequired = false;

            $assistants.find('.required').each((index, requiredField) => {
                if (!$(requiredField).val()) {
                    $(requiredField).addClass('is-invalid');
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
            $('#assistants .form-message').addClass('alert-danger').text(error.message).show();
            return false;
        }
    }

    /**
     * Resets the assistant tab form back to its initial state.
     */
    function resetForm() {
        App.Utils.PictureUpload.reset();
        $filterAssistants.find('.selected').removeClass('selected');
        $filterAssistants.find('button').prop('disabled', false);
        $filterAssistants.find('.results').css('color', '');
        $assistants.find('.record-details').find('input, select, textarea').val('').prop('disabled', true);
        $assistants.find('.record-details .form-label span').prop('hidden', true);
        $assistants.find('.record-details #timezone').val(vars('default_timezone'));
        $assistants.find('.record-details #language').val(vars('default_language'));
        $assistants.find('.add-edit-delete-group').show();
        $assistants.find('.save-cancel-group').hide();
        $assistants.find('.form-message').hide();
        $assistants.find('.is-invalid').removeClass('is-invalid');
        $('#edit-assistant, #delete-assistant').prop('disabled', true);
        $('#assistant-providers input:checkbox').prop('disabled', true).prop('checked', false);
        $('#select-all-providers, #select-none-providers').prop('disabled', true);
    }

    /**
     * Display a assistant record into the assistant form.
     *
     * @param {Object} assistant Contains the assistant record data.
     */
    function display(assistant) {
        App.Utils.PictureUpload.setRecord('assistants', assistant.id, assistant.picture_url);
        $id.val(assistant.id);
        $name.val(assistant.name);
        $email.val(assistant.email);
        $mobileNumber.val(assistant.mobile_number);
        $phoneNumber.val(assistant.phone_number);
        $address.val(assistant.address);
        $city.val(assistant.city);
        $state.val(assistant.state);
        $zipCode.val(assistant.zip_code);
        $notes.val(assistant.notes);
        $language.val(assistant.language);
        $timezone.val(assistant.timezone);
        $ldapDn.val(assistant.ldap_dn);

        $username.val(assistant.settings.username);

        $('#assistant-providers input:checkbox').prop('checked', false);

        assistant.providers.forEach((assistantProviderId) => {
            const $checkbox = $('#assistant-providers input[data-id="' + assistantProviderId + '"]');

            if (!$checkbox.length) {
                return;
            }

            $checkbox.prop('checked', true);
        });
    }

    /**
     * Filters assistant records based on a string keyword.
     *
     * @param {String} keyword This is used to filter the assistant records of the database.
     * @param {Number} selectId Optional, if provided the given ID will be selected in the filter results
     * (only selected, not displayed).
     * @param {Boolean} show Optional (false).
     */
    function filter(keyword, selectId = null, show = false) {
        App.Http.Assistants.search(keyword, filterLimit, (filterPage - 1) * filterLimit).done((response, textStatus, jqXHR) => {
            filterResults = response;

            $filterAssistants.find('.results').empty();

            response.forEach((assistant) => {
                $filterAssistants
                    .find('.results')
                    .append(App.Pages.Assistants.getFilterHtml(assistant))
                    .append($('<hr/>'));
            });

            if (!response.length) {
                $('#filter-assistants .results').append(
                    $('<em/>', {
                        'text': lang('no_records_found'),
                    }),
                );
            }

            App.Utils.Pagination.render(
                $('#filter-assistants .results'),
                Number(jqXHR.getResponseHeader('X-Total-Count')) || response.length,
                filterPage,
                filterLimit,
                (page) => {
                    filterPage = page;
                    App.Pages.Assistants.filter(keyword, selectId, show);
                },
            );

            if (selectId) {
                select(selectId, show);
            }
        });
    }

    /**
     * Get an assistant row html code that is going to be displayed on the filter results list.
     *
     * @param {Object} assistant Contains the assistant record data.
     *
     * @return {String} The html code that represents the record on the filter results list.
     */
    function getFilterHtml(assistant) {
        const name = assistant.name;

        let info = assistant.email;

        info = assistant.mobile_number ? info + ', ' + assistant.mobile_number : info;

        info = assistant.phone_number ? info + ', ' + assistant.phone_number : info;

        return $('<div/>', {
            'class': 'assistant-row entry',
            'data-id': assistant.id,
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
     * Select a specific record from the current filter results. If the assistant id does not exist
     * in the list then no record will be selected.
     *
     * @param {Number} id The record id to be selected from the filter results.
     * @param {Boolean} show Optional (false), if true the method will display the record in the form.
     */
    function select(id, show = false) {
        $filterAssistants.find('.selected').removeClass('selected');

        $('#filter-assistants .assistant-row[data-id="' + id + '"]').addClass('selected');

        if (show) {
            const assistant = filterResults.find((filterResult) => Number(filterResult.id) === Number(id));

            App.Pages.Assistants.display(assistant);

            $('#edit-assistant, #delete-assistant').prop('disabled', false);
        }
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        App.Pages.Assistants.resetForm();
        App.Pages.Assistants.filter('');
        App.Pages.Assistants.addEventListeners();

        vars('providers').forEach((provider) => {
            const checkboxId = `provider-service-${provider.id}`;

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
                                'data-id': provider.id,
                                'prop': {
                                    'disabled': true,
                                },
                            }),
                            $('<label/>', {
                                'class': 'form-check-label',
                                'text': provider.name,
                                'for': checkboxId,
                            }),
                        ],
                    }),
                ],
            }).appendTo('#assistant-providers');
        });
    }

    document.addEventListener('DOMContentLoaded', initialize);

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
