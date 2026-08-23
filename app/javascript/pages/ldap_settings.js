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
 * LDAP settings page.
 *
 * This module implements the functionality of the LDAP settings page.
 */
App.Pages.LdapSettings = (function () {
    const $searchForm = $('#ldap-search-form');
    const $searchKeyword = $('#ldap-search-keyword');
    const $searchResults = $('#ldap-search-results');
    const $ldapFilter = $('#ldap-filter');
    const $ldapFieldMapping = $('#ldap-field-mapping');
    const $resetFilter = $('#ldap-reset-filter');
    const $resetFieldMapping = $('#ldap-reset-field-mapping');

    /**
     * Prepare an array of setting values based on the UI form.
     *
     * @return {Array}
     */
    function serialize() {
        const ldapSettings = [];

        $('[data-field]').each((index, field) => {
            const $field = $(field);

            ldapSettings.push({
                name: $field.data('field'),
                value: $field.is(':checkbox') ? Number($field.prop('checked')) : $field.val(),
            });
        });

        return ldapSettings;
    }

    function getLdapFieldMapping() {
        const jsonLdapFieldMapping = $ldapFieldMapping.val();
        return JSON.parse(jsonLdapFieldMapping);
    }

    /**
     * Save the current server settings.
     */
    // The search runs against the stored settings, so save the form first (JSON rows path).
    function saveSettings() {
        return $.post(App.Utils.Url.siteUrl('ldap_settings/save'), {
            csrf_token: vars('csrf_token'),
            ldap_settings: serialize(),
        });
    }

    /**
     * Search the LDAP server based on a keyword.
     */
    function searchServer() {
        $searchResults.empty();

        const keyword = $searchKeyword.val();

        if (!keyword) {
            return;
        }

        $.post(App.Utils.Url.siteUrl('ldap_settings/search'), {csrf_token: vars('csrf_token'), keyword}).done((entries) => {
            $searchResults.empty();

            if (!entries?.length) {
                renderNoRecordsFound().appendTo($searchResults);
                return;
            }

            entries.forEach((entry) => {
                renderEntry(entry).appendTo($searchResults);
            });
        });
    }

    /**
     * Set the field value back to the original state.
     */
    function onResetFilterClick() {
        $ldapFilter.val(vars('ldap_default_filter'));
    }

    /**
     * Set the field value back to the original state.
     */
    function onResetFieldMappingClick() {
        const defaultFieldMapping = vars('ldap_default_field_mapping');
        const jsonDefaultFieldMapping = JSON.stringify(defaultFieldMapping, null, 2);
        $ldapFieldMapping.val(jsonDefaultFieldMapping);
    }

    /**
     * Handle the LDAP import button click
     */
    function onLdapImportClick(event) {
        const $target = $(event.target);
        const $card = $target.closest('.card');
        const entry = $card.data('entry');
        const ldapFieldMapping = getLdapFieldMapping();

        App.Components.LdapImportModal.open(entry, ldapFieldMapping).done(() => {
            App.Layouts.Backend.displayNotification(lang('user_imported'));
        });
    }

    /**
     * Render the no-records-found message
     */
    function renderNoRecordsFound() {
        return $(`
            <div class="text-muted fst-italic">
                ${lang('no_records_found')}
            </div>
        `);
    }

    /**
     * Render the LDAP entry data on screen
     *
     * @param {Object} entry
     */
    function renderEntry(entry) {
        if (!entry?.dn) {
            return;
        }

        const $entry = $(`
            <div class="card small mb-2">
                <div class="card-header p-2 fw-bold">
                    ${entry.dn}
                </div>
                <div class="card-body p-2">
                    <p class="d-block mb-2">${lang('content')}</p>
                    
                    <pre class="overflow-y-auto bg-light rounded p-2" style="max-height: 200px">${JSON.stringify(entry, null, 2)}</pre>
                    
                    <div class="d-lg-flex">
                        <button class="btn btn-outline-primary btn-sm px-4 ldap-import ms-lg-auto">
                            ${lang('import')}
                        </button>
                    </div>
                </div>
            </div>
        `);

        $entry.data('entry', entry);

        return $entry;
    }

    /**
     * Save the current connection settings and then search the directory based on the provided keyword.
     *
     * @param {Object} event
     */
    function onSearchFormSubmit(event) {
        event.preventDefault();

        saveSettings().done(() => {
            searchServer();
        });
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        $resetFilter.on('click', onResetFilterClick);
        $resetFieldMapping.on('click', onResetFieldMappingClick);
        $searchForm.on('submit', onSearchFormSubmit);
        $searchResults.on('click', '.ldap-import', onLdapImportClick);

    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {};
})();
