require "application_system_test_case"

# Admins and assistants share one shape. Written against the jQuery pages before
# the Rails views conversion: labels, visible text and row selectors only.
class UserPagesTest < ApplicationSystemTestCase
  def fill_user(name, username)
    fill_in "Name", with: name
    fill_in "Email", with: "#{username}@example.org"
    fill_in "Phone Number", with: "020 7946 0000"
    fill_in "Mobile Number", with: "07700 900111"
    fill_in "Address", with: "1 High St"
    fill_in "City", with: "London"
    fill_in "Username", with: username
    fill_in "Password", with: "password1", match: :prefer_exact
    fill_in "Retype Password", with: "password1"
  end

  def crud_walk(page:, row:, role:, saved:, deleted:, delete_title:)
    visit url_for(controller: page, only_path: false)
    assert_selector "h4", text: /./, wait: 5

    click_on "Add"
    assert_selector "##{page}-page.editing", wait: 5
    fill_user "Pat Person", "patperson"
    select "English", from: "Language"
    select "London (+0:00)", from: "Timezone"
    fill_in "Retype Password", with: "different"
    click_on "Save"
    assert_selector "##{page}-page.editing .alert", wait: 5
    assert_nil User.find_by(email: "patperson@example.org")

    fill_in "Retype Password", with: "password1"
    yield :before_save if block_given?
    click_on "Save"
    assert_text saved, wait: 5
    assert_no_selector "##{page}-page.editing"
    assert_selector ".#{row}.selected", text: "Pat Person"
    assert_selector ".#{row}.selected", text: "patperson@example.org"
    pat = User.find_by!(email: "patperson@example.org")
    assert_equal role, pat.role.slug
    assert_equal "patperson", pat.settings.username
    assert Passwords.verify(nil, "password1", pat.settings.password)
    assert_equal "+447700900111", pat.mobile_number
    assert_equal "london", pat.city.downcase
    assert_equal "english", pat.language
    assert_equal "Europe/London", pat.timezone

    find(".#{row}", text: "Pat Person").click
    assert_selector "##{page}-page.editing", wait: 5
    assert_field "Username", with: "patperson"
    assert_field "Password", with: "", match: :prefer_exact
    fill_in "Name", with: "Pat Persona"
    yield :edit, pat if block_given?
    click_on "Save"
    assert_text saved, wait: 5
    assert_equal "Pat Persona", pat.reload.name
    assert Passwords.verify(nil, "password1", pat.settings.reload.password), "password must survive an edit"

    find("#filter-#{page} .key").set("persona")
    find("#filter-#{page} button.filter").click
    assert_selector ".#{row}", count: 1, wait: 5

    find(".#{row}", text: "Pat Persona").click
    assert_selector "##{page}-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "##{page}-page.editing", wait: 5

    find(".#{row}", text: "Pat Persona").click
    assert_selector "##{page}-page.editing", wait: 5
    click_on "Delete"
    confirm_modal delete_title, "Delete"
    assert_text deleted, wait: 5
    assert_no_selector ".#{row}", text: "Pat Persona"
    assert_not User.exists?(pat.id)
  end

  setup { login_as_admin }

  test "admins: add, mismatch, edit, filter, cancel, delete" do
    crud_walk(page: "admins", row: "admin-row", role: "admin", saved: "Admin saved",
              deleted: "Admin deleted", delete_title: "Delete Admin")
  end

  test "assistants: add with providers, edit, filter, cancel, delete" do
    crud_walk(page: "assistants", row: "assistant-row", role: "assistant", saved: "Assistant saved",
              deleted: "Assistant deleted", delete_title: "Delete Assistant") do |step, pat|
      case step
      when :before_save
        click_on "Select None"
        check "Zane"
      when :edit
        assert_checked_field "Zane"
        assert_equal [ users(:zane).id ], pat.providers.map(&:id)
        click_on "Select None"
        assert_unchecked_field "Zane"
      end
    end
    assert_equal [], User.assistants.where(email: "patperson@example.org").flat_map(&:providers)
  end

  test "an admin cannot delete their own account" do
    visit admins_url
    find(".admin-row", text: "Edson Mori").click
    assert_selector "#admins-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Admin", "Delete"
    assert_selector ".admin-row", text: "Edson Mori", wait: 5
    assert User.exists?(users(:admin).id)
  end

  test "a stylist edits their About and Services on the Account page" do
    visit logout_url
    visit login_url
    assert_selector "#login", wait: 15
    fill_in "username", with: "janedoe"
    fill_in "password", with: "janedoe1"
    find("#login").click
    assert_current_path %r{/appointments}, wait: 10

    visit "/account"
    assert_field "Name", with: "Zane"
    click_on "About & Services"
    fill_in "About", with: "Cuts since 1999"
    fill_in "Description of services", with: "Dry cuts"
    assert_selector ".account-services li", text: "Trim Cut"
    click_on "Save"
    assert_text "Settings saved", wait: 5
    assert_equal "Cuts since 1999", users(:zane).reload.about
    assert_equal "Dry cuts", users(:zane).services_description
  end

  test "saving with a required field empty on a hidden tab shows that tab" do
    visit logout_url
    visit login_url
    assert_selector "#login", wait: 15
    fill_in "username", with: "janedoe"
    fill_in "password", with: "janedoe1"
    find("#login").click
    assert_current_path %r{/appointments}, wait: 10

    visit "/account"
    fill_in "Email", with: ""
    # The tab is switched through Bootstrap rather than a click: the click itself
    # is covered above, and here only the reveal on Save is under test.
    page.execute_script("bootstrap.Tab.getOrCreateInstance(document.querySelector(\"a[href='#about-services']\")).show()")
    assert_selector "a.nav-link.active[href='#about-services']", wait: 5
    assert_selector "#about-services.active.show", wait: 5
    # requestSubmit runs the browser's validation as a Save click would; the
    # click itself is unreliable on CI.
    page.execute_script("document.getElementById('account-form').requestSubmit()")
    assert_selector "a.nav-link.active[href='#details']", wait: 5
    assert_current_path "/account"
    assert_no_text "Settings saved"
  end
end
