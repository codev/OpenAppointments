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
 * Customers page.
 *
 * This module implements the functionality of the customers page.
 */
App.Pages.Customers = (function () {
    const $customers = $('#customers');
    const $filterCustomers = $('#filter-customers');
    const $id = $('#customer-id');
    const $name = $('#name');
    const $email = $('#email');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $zipCode = $('#zip-code');
    const $timezone = $('#timezone');
    const $language = $('#language');
    const $ldapDn = $('#ldap-dn');
    const $customField1 = $('#custom-field-1');
    const $customField2 = $('#custom-field-2');
    const $customField3 = $('#custom-field-3');
    const $customField4 = $('#custom-field-4');
    const $customField5 = $('#custom-field-5');
    const $notes = $('#notes');
    const $formMessage = $('#form-message');
    const $customerAppointments = $('#customer-appointments');
    const $customerMessages = $('#customer-messages');
    const $messageChannel = $('#message-channel');
    const $messageBody = $('#message-body');
    const $sendMessage = $('#send-message');

    const moment = window.moment;

    let filterResults = {};
    const filterLimit = 20;

    let filterPage = 1;

    /**
     * Add the page event listeners.
     */
    function addEventListeners() {
        /**
         * Event: Filter Customers Form "Submit"
         *
         * @param {jQuery.Event} event
         */
        $customers.on('submit', '#filter-customers form', (event) => {
            event.preventDefault();
            const key = $filterCustomers.find('.key').val();
            $filterCustomers.find('.selected').removeClass('selected');
            filterPage = 1;
            App.Pages.Customers.resetForm();
            App.Pages.Customers.filter(key);
        });

        /**
         * Event: Filter Entry "Click"
         *
         * Display the customer data of the selected row.
         *
         * @param {jQuery.Event} event
         */
        $customers.on('click', '.customer-row', (event) => {
            if ($filterCustomers.find('.filter').prop('disabled')) {
                return; // Do nothing when user edits a customer record.
            }

            const customerId = $(event.currentTarget).attr('data-id');
            const customer = filterResults.find((filterResult) => Number(filterResult.id) === Number(customerId));

            App.Pages.Customers.display(customer);
            $('#filter-customers .selected').removeClass('selected');
            $(event.currentTarget).addClass('selected');
            $('#edit-customer, #delete-customer').prop('disabled', false);

            // Automatically enter edit mode
            $('#customers-page').addClass('editing');
            $customers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $customers.find('.record-details .form-label span').prop('hidden', false);
            $customers.find('#add-edit-delete-group').hide();
            $customers.find('#save-cancel-group').show();
            $customers.find('#delete-customer').show(); // Show delete button when editing
            $filterCustomers.find('button').prop('disabled', true);
            $filterCustomers.find('.results').css('color', '#AAA');
        });

        /**
         * Event: Add Customer Button "Click"
         */
        $customers.on('click', '#add-customer', () => {
            App.Pages.Customers.resetForm();
            $('#customers-page').addClass('editing');
            $customers.find('#add-edit-delete-group').hide();
            $customers.find('#save-cancel-group').show();
            $customers.find('#delete-customer').hide(); // Hide delete button when adding
            $customers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $customers.find('.record-details .form-label span').prop('hidden', false);
            $filterCustomers.find('button').prop('disabled', true);
            $filterCustomers.find('.results').css('color', '#AAA');
        });

        /**
         * Event: Edit Customer Button "Click"
         */
        $customers.on('click', '#edit-customer', () => {
            $('#customers-page').addClass('editing');
            $customers.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $customers.find('.record-details .form-label span').prop('hidden', false);
            $customers.find('#add-edit-delete-group').hide();
            $customers.find('#save-cancel-group').show();
            $filterCustomers.find('button').prop('disabled', true);
            $filterCustomers.find('.results').css('color', '#AAA');
        });

        /**
         * Event: Cancel Customer Add/Edit Operation Button "Click"
         */
        $customers.on('click', '#cancel-customer', () => {
            const id = $id.val();

            App.Pages.Customers.resetForm();
            $('#customers-page').removeClass('editing');

            if (id) {
                select(id, true);
            }
        });

        /**
         * Event: Save Add/Edit Customer Operation "Click"
         */
        $customers.on('click', '#save-customer', () => {
            const customer = {
                name: $name.val(),
                email: $email.val(),
                phone_number: $phoneNumber.val(),
                address: $address.val(),
                city: $city.val(),
                zip_code: $zipCode.val(),
                notes: $notes.val(),
                timezone: $timezone.val(),
                language: $language.val() || 'english',
                custom_field_1: $customField1.val(),
                custom_field_2: $customField2.val(),
                custom_field_3: $customField3.val(),
                custom_field_4: $customField4.val(),
                custom_field_5: $customField5.val(),
                ldap_dn: $ldapDn.val(),
            };

            if ($id.val()) {
                customer.id = $id.val();
            }

            if (!App.Pages.Customers.validate()) {
                return;
            }

            App.Pages.Customers.save(customer);
        });

        /**
         * Event: Delete Customer Button "Click"
         */
        $customers.on('click', '#delete-customer', () => {
            const customerId = $id.val();
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
                        App.Pages.Customers.remove(customerId);
                        messageModal.hide();
                    },
                },
            ];

            App.Utils.Message.show(lang('delete_customer'), lang('delete_record_prompt'), buttons);
        });

        /**
         * Event: Send Message Button "Click"
         */
        $customers.on('click', '#send-message', onSendMessageClick);

        $customers.on('keydown', '#message-body', (event) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                onSendMessageClick();
            }
        });
    }

    /**
     * Save a customer record to the database (via ajax post).
     *
     * @param {Object} customer Contains the customer data.
     */
    function save(customer) {
        App.Http.Customers.save(customer).then((response) => {
            App.Layouts.Backend.displayNotification(lang('customer_saved'));
            App.Pages.Customers.resetForm();
            $('#customers-page').removeClass('editing');
            $('#filter-customers .key').val('');
            App.Pages.Customers.filter('', response.id, true);
        });
    }

    /**
     * Delete a customer record from database.
     *
     * @param {Number} id Record id to be deleted.
     */
    function remove(id) {
        App.Http.Customers.destroy(id).then(() => {
            App.Layouts.Backend.displayNotification(lang('customer_deleted'));
            App.Pages.Customers.resetForm();
            $('#customers-page').removeClass('editing');
            App.Pages.Customers.filter($('#filter-customers .key').val());
        });
    }

    /**
     * Validate customer data before save (insert or update).
     */
    function validate() {
        $formMessage.removeClass('alert-danger').hide();
        $('.is-invalid').removeClass('is-invalid');

        try {
            // Validate required fields.
            let missingRequired = false;

            $('.required').each((index, requiredField) => {
                if ($(requiredField).val() === '') {
                    $(requiredField).addClass('is-invalid');
                    missingRequired = true;
                }
            });

            if (missingRequired) {
                throw new Error(lang('fields_are_required'));
            }

            // Validate email address.
            const email = $email.val();

            if (email && !App.Utils.Validation.email(email)) {
                $email.addClass('is-invalid');
                throw new Error(lang('invalid_email'));
            }

            // Validate phone number.
            const phoneNumber = $phoneNumber.val();

            if (phoneNumber && !App.Utils.Validation.phone(phoneNumber)) {
                $phoneNumber.addClass('is-invalid');
                throw new Error(lang('invalid_phone'));
            }

            return true;
        } catch (error) {
            $formMessage.addClass('alert-danger').text(error.message).show();
            return false;
        }
    }

    /**
     * Bring the customer form back to its initial state.
     */
    function resetForm() {
        $customers.find('.record-details').find('input, select, textarea').val('').prop('disabled', true);
        $customers.find('.record-details .form-label span').prop('hidden', true);
        $customers.find('.record-details #timezone').val(vars('default_timezone'));
        $customers.find('.record-details #language').val(vars('default_language'));

        $customerAppointments.empty();
        $customerMessages.empty();
        $messageChannel.val('').prop('disabled', true);
        $messageBody.val('').prop('disabled', true);
        $sendMessage.prop('disabled', true);

        $customers.find('#edit-customer, #delete-customer').prop('disabled', true);
        $customers.find('#add-edit-delete-group').show();
        $customers.find('#save-cancel-group').hide();

        $customers.find('.record-details .is-invalid').removeClass('is-invalid');
        $customers.find('.record-details #form-message').hide();

        $filterCustomers.find('button').prop('disabled', false);
        $filterCustomers.find('.selected').removeClass('selected');
        $filterCustomers.find('.results').css('color', '');
    }

    /**
     * Display a customer record into the form.
     *
     * @param {Object} customer Contains the customer record data.
     */
    function display(customer) {
        $id.val(customer.id);
        $name.val(customer.name);
        $email.val(customer.email);
        $phoneNumber.val(customer.phone_number);
        $address.val(customer.address);
        $city.val(customer.city);
        $zipCode.val(customer.zip_code);
        $notes.val(customer.notes);
        $timezone.val(customer.timezone);
        $language.val(customer.language || 'english');
        $ldapDn.val(customer.ldap_dn);
        $customField1.val(customer.custom_field_1);
        $customField2.val(customer.custom_field_2);
        $customField3.val(customer.custom_field_3);
        $customField4.val(customer.custom_field_4);
        $customField5.val(customer.custom_field_5);

        loadMessages(customer.id);
        $messageChannel.prop('disabled', false);
        $messageBody.prop('disabled', false);
        $sendMessage.prop('disabled', false);

        $customerAppointments.empty();

        if (!customer.appointments.length) {
            $('<p/>', {
                'text': lang('no_records_found'),
            }).appendTo($customerAppointments);
        }

        customer.appointments.forEach((appointment) => {
            if (
                vars('role_slug') === App.Layouts.Backend.DB_SLUG_PROVIDER &&
                parseInt(appointment.id_users_provider) !== vars('user_id')
            ) {
                return;
            }

            if (
                vars('role_slug') === App.Layouts.Backend.DB_SLUG_SECRETARY &&
                vars('secretary_providers').indexOf(appointment.id_users_provider) === -1
            ) {
                return;
            }

            const start = App.Utils.Date.format(
                moment(appointment.start_datetime).toDate(),
                vars('date_format'),
                vars('time_format'),
                true,
            );

            const end = App.Utils.Date.format(
                moment(appointment.end_datetime).toDate(),
                vars('date_format'),
                vars('time_format'),
                true,
            );

            $('<div/>', {
                'class': 'appointment-row',
                'data-id': appointment.id,
                'html': [
                    // Service - Provider

                    $('<a/>', {
                        'href': App.Utils.Url.siteUrl(`calendar/reschedule/${appointment.hash}`),
                        'html': [
                            $('<i/>', {
                                'class': 'fas fa-edit me-1',
                            }),
                            $('<strong/>', {
                                'text':
                                    appointment.service.name +
                                    ' - ' +
                                    appointment.provider.name,
                            }),
                            $('<br/>'),
                        ],
                    }),

                    // Start

                    $('<small/>', {
                        'text': start,
                    }),
                    $('<br/>'),

                    // End

                    $('<small/>', {
                        'text': end,
                    }),
                    $('<br/>'),

                    // Timezone

                    $('<small/>', {
                        'text': vars('timezones')[appointment.provider.timezone],
                    }),
                ],
            }).appendTo('#customer-appointments');
        });
    }

    /**
     * Load and render the messages of a customer (also marks them read).
     *
     * @param {Number} customerId
     */
    function loadMessages(customerId) {
        if (!$customerMessages.length) {
            return;
        }

        App.Http.CustomerMessages.find(customerId).done((messages) => {
            $customerMessages.empty();

            if (!messages.length) {
                $('<p/>', {
                    'text': lang('no_records_found'),
                }).appendTo($customerMessages);
            }

            messages.forEach((message) => {
                appendMessage(message);
            });

            // Reading the messages clears the unread badge of this customer.
            const filterResult = (filterResults || []).find &&
                filterResults.find((result) => Number(result.id) === Number(customerId));

            if (filterResult) {
                filterResult.unread_messages = 0;
            }

            $('#filter-customers .entry[data-id="' + customerId + '"] .unread-badge').remove();
        });
    }

    /**
     * Append one message row to the messages panel.
     *
     * @param {Object} message
     */
    function appendMessage(message) {
        const incoming = message.direction === 'incoming';

        $('<div/>', {
            'class': 'message-row mb-2 pb-2 border-bottom',
            'html': [
                $('<i/>', {
                    'class': incoming ? 'fas fa-arrow-down text-success me-1' : 'fas fa-arrow-up text-primary me-1',
                }),
                $('<span/>', {
                    'class': 'badge bg-secondary me-1',
                    'text': message.channel_label,
                }),
                $('<small/>', {
                    'class': 'text-muted',
                    'text': message.created_at + (message.status === 'failed' ? ' - ' + lang('messages_status_failed') : ''),
                }),
                $('<br/>'),
                $('<small/>', {
                    'text': message.body,
                }),
            ],
        }).appendTo($customerMessages);
    }

    /**
     * Send a manual message to the displayed customer.
     */
    function onSendMessageClick() {
        const customerId = $id.val();
        const channel = $messageChannel.val();
        const body = $messageBody.val().trim();

        if (!customerId || !body) {
            return;
        }

        if (!channel) {
            App.Layouts.Backend.displayNotification(lang('select_one'));

            return;
        }

        App.Http.CustomerMessages.send(customerId, channel, body).done((response) => {
            if (response.success === false) {
                App.Layouts.Backend.displayNotification(response.message);

                return;
            }

            $messageBody.val('');
            App.Layouts.Backend.displayNotification(lang('message_sent'));
            loadMessages(customerId);
        });
    }

    /**
     * Filter customer records.
     *
     * @param {String} keyword This keyword string is used to filter the customer records.
     * @param {Number} selectId Optional, if set then after the filter operation the record with the given
     * ID will be selected (but not displayed).
     * @param {Boolean} show Optional (false), if true then the selected record will be displayed on the form.
     */
    function filter(keyword, selectId = null, show = false) {
        App.Http.Customers.search(keyword, filterLimit, (filterPage - 1) * filterLimit).then((response, textStatus, jqXHR) => {
            filterResults = response;

            $filterCustomers.find('.results').empty();

            response.forEach((customer) => {
                $('#filter-customers .results').append(App.Pages.Customers.getFilterHtml(customer)).append($('<hr/>'));
            });

            if (!response.length) {
                $filterCustomers.find('.results').append(
                    $('<em/>', {
                        'text': lang('no_records_found'),
                    }),
                );
            }

            App.Utils.Pagination.render(
                $('#filter-customers .results'),
                Number(jqXHR.getResponseHeader('X-Total-Count')) || response.length,
                filterPage,
                filterLimit,
                (page) => {
                    filterPage = page;
                    App.Pages.Customers.filter(keyword, selectId, show);
                },
            );

            if (selectId) {
                App.Pages.Customers.select(selectId, show);
            }
        });
    }

    /**
     * Get the filter results row HTML code.
     *
     * @param {Object} customer Contains the customer data.
     *
     * @return {String} Returns the record HTML code.
     */
    function getFilterHtml(customer) {
        const name = (customer.name || '[No Name]');

        let info = customer.email || '[No Email]';

        info = customer.phone_number ? info + ', ' + customer.phone_number : info;

        return $('<div/>', {
            'class': 'customer-row entry',
            'data-id': customer.id,
            'html': [
                $('<strong/>', {
                    'text': name,
                }),
                Number(customer.unread_messages)
                    ? $('<span/>', {
                          'class': 'badge bg-danger ms-2 unread-badge',
                          'text': customer.unread_messages,
                      })
                    : null,
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
     * Select a specific record from the current filter results.
     *
     * If the customer id does not exist in the list then no record will be selected.
     *
     * @param {Number} id The record id to be selected from the filter results.
     * @param {Boolean} show Optional (false), if true then the method will display the record on the form.
     */
    function select(id, show = false) {
        $('#filter-customers .selected').removeClass('selected');

        $('#filter-customers .entry[data-id="' + id + '"]').addClass('selected');

        if (show) {
            const customer = filterResults.find((filterResult) => Number(filterResult.id) === Number(id));

            App.Pages.Customers.display(customer);

            $('#edit-customer, #delete-customer').prop('disabled', false);
        }
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        App.Pages.Customers.resetForm();
        App.Pages.Customers.addEventListeners();

        // Deep link support (e.g. from the messages log): /customers?customer_id=N
        const customerId = new URLSearchParams(window.location.search).get('customer_id');

        App.Pages.Customers.filter('', customerId ? Number(customerId) : null, Boolean(customerId));
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
