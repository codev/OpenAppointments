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
    assert_selector "##{page}-page.editing .notice", wait: 5
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
    assert_equal "07700 900111", pat.mobile_number
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
end
