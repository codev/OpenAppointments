require "test_helper"

# The record's action row ends the form: Delete at the far left, Cancel and Save
# at the right. Delete posts its own form through the button's form attribute
# (forms cannot nest).
class CrudFormToolbarTest < ActionDispatch::IntegrationTest
  test "delete sits at the far left of the action row and posts a delete" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/customers/#{users(:jx).id}/edit"
    assert_response :success
    assert_select ".crud-form .form-actions" do
      assert_select "button[type=submit].btn-primary[data-save]"
      assert_select "button.btn-outline-danger.me-auto[form=?]", "delete-customer-#{users(:jx).id}"
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
