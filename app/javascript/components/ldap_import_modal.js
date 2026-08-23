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
 * LDAP import modal component.
 *
 * The LDAP import dialog: a Rails form (ldap_settings/import) prefilled from
 * the chosen directory entry.
 */
App.Components.LdapImportModal = (function () {
    const $modal = $('#ldap-import-modal');

    // Prefill the import form from an LDAP entry through the field mapping.
    function open(entry, ldapFieldMapping) {
        $modal.find('input').val('');
        $modal.find('#ldap-import-role-slug').val(App.Layouts.Backend.DB_SLUG_PROVIDER);
        $modal.find('#ldap-import-ldap-dn').val(entry.dn);
        $modal.find('#ldap-import-name').val(entry?.[ldapFieldMapping?.name] ?? '');
        $modal.find('#ldap-import-email').val(entry?.[ldapFieldMapping?.email] ?? '');
        $modal.find('#ldap-import-phone-number').val(entry?.[ldapFieldMapping?.phone_number] ?? '');
        $modal.find('#ldap-import-username').val(entry?.[ldapFieldMapping?.username] ?? '');
        $modal.modal('show');
    }

    return {open};
})();
