require "test_helper"

# The record toolbar spans the details panel: Save and Cancel on the left,
# Delete on the right, posting to its own form through the button's form
# attribute (forms cannot nest).
class CrudFormToolbarTest < ActionDispatch::IntegrationTest
  test "delete sits at the right end of the toolbar and posts a delete" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/customers/#{users(:jx).id}/edit"
    assert_response :success
    assert_select ".crud-form .actions" do
      assert_select "button[type=submit]:not(.secondary):not(.destructive)"
      assert_select "button.destructive.trailing[form=?]", "delete-customer-#{users(:jx).id}"
    end
    assert_select "form#delete-customer-#{users(:jx).id}[action=?]", "/customers/#{users(:jx).id}" do
      assert_select "input[name=_method][value=delete]"
    end
    assert_select ".crud-form form", 0, "no form nested inside the record form"
  end

  test "a new record has no delete button" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/customers/new"
    assert_response :success
    assert_select "button.btn-outline-danger", 0
  end
end
