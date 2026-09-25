require "test_helper"

# Admins and assistants on the shared user form.
class UserPagesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def png = fixture_file_upload("picture.png", "image/png")

  def admin_params(**overrides)
    { name: "Pat", email: "pat@example.org", language: "english", timezone: "Europe/London",
      settings: { username: "pat", password: "password1", password_confirmation: "password1" } }.deep_merge(overrides)
  end

  test "index rows show contact details and the form has the user fields in two columns" do
    login_admin
    users(:admin).update!(mobile_number: "07700 900222")
    get "/admins"
    assert_select ".admin-row[data-id=?] small", users(:admin).id.to_s, text: "edson.mori@example.org, +447700900222"

    get "/admins/new"
    assert_select "turbo-frame#admins_record form[action='/admins'][enctype='multipart/form-data']" do
      assert_select ".details input[name='admin[name]'][required]"
      assert_select ".details input[type=email][name='admin[email]'][required]"
      assert_select ".details input[type=file][name='admin[picture]']"
      assert_select ".settings input[name='admin[settings][username]'][required]"
      assert_select ".settings input[type=password][name='admin[settings][password]'][required]"
      assert_select ".settings input[type=password][name='admin[settings][password_confirmation]'][required]"
      assert_select ".settings select[name='admin[language]'] option[value=english]"
      assert_select ".settings select[name='admin[timezone]'] optgroup[label=Europe] option[value='Europe/London']"
      assert_select "input[name='admin[ldap_dn]']", count: 0
    end
  end

  test "edit does not require a password and keeps it when left blank" do
    login_admin
    get "/admins/#{users(:admin).id}/edit"
    assert_select "input[type=password][name='admin[settings][password]']:not([required])"
    assert_select "input[name='admin[settings][username]'][value=administrator]"

    old_hash = users(:admin).settings.password
    patch "/admins/#{users(:admin).id}", params: { admin: { name: "Edson M", settings: { username: "administrator", password: "", password_confirmation: "" } } }
    assert_redirected_to "/admins?selected=#{users(:admin).id}"
    assert_equal old_hash, users(:admin).settings.reload.password
    assert_equal "Edson M", users(:admin).reload.name
  end

  test "create hashes the password, attaches the picture and fires the webhook" do
    login_admin
    Webhook.create!(name: "Hook", url: "https://hooks.example.org/ea", actions: "admin_save")
    post "/admins", params: { admin: admin_params(picture: png) }
    pat = User.admins.find_by!(email: "pat@example.org")
    assert_redirected_to "/admins?selected=#{pat.id}"
    assert Passwords.verify(nil, "password1", pat.settings.password)
    assert pat.picture.attached?
    assert_enqueued_with(job: WebhookDeliveryJob)
  end

  test "password rules, duplicate email and duplicate username are refused with a message" do
    login_admin
    post "/admins", params: { admin: admin_params(settings: { password: "short", password_confirmation: "short" }) }
    assert_response :unprocessable_entity
    assert_select ".form-message", text: /at least #{Passwords::MIN_LENGTH} characters/

    post "/admins", params: { admin: admin_params(email: users(:admin).email) }
    assert_response :unprocessable_entity
    assert_select ".form-message", text: /already in use/

    post "/admins", params: { admin: admin_params(settings: { username: "administrator" }) }
    assert_response :unprocessable_entity
    assert_select ".form-message", text: I18n.t("ea.username_already_exists")
    assert_select "input.is-invalid[name='admin[settings][username]'][value=administrator]"

    post "/admins", params: { admin: admin_params(settings: { password: "", password_confirmation: "" }) }
    assert_response :unprocessable_entity
    assert_select ".form-message", text: /cannot be empty/
    assert_nil User.find_by(email: "pat@example.org")
  end

  test "the signed in admin cannot delete themselves" do
    login_admin
    delete "/admins/#{users(:admin).id}"
    assert_redirected_to "/admins?selected=#{users(:admin).id}"
    follow_redirect!
    assert_select ".alert-danger", text: /cannot delete your own account/
    assert User.exists?(users(:admin).id)
  end

  test "assistants carry their providers and the form lists them with select all/none" do
    login_admin
    get "/assistants/#{users(:sam).id}/edit"
    assert_select "[data-check-all='#assistant-providers']"
    assert_select "#assistant-providers input[type=checkbox][name='assistant[providers][]'][value=?]",
                  users(:zane).id.to_s

    patch "/assistants/#{users(:sam).id}", params: { assistant: { providers: [ "", users(:zane).id ] } }
    assert_equal [ users(:zane).id ], users(:sam).reload.providers.map(&:id)
    patch "/assistants/#{users(:sam).id}", params: { assistant: { providers: [ "" ] } }
    assert_equal [], users(:sam).reload.providers.map(&:id)
    patch "/assistants/#{users(:sam).id}", params: { assistant: { name: "Sam" } }
    assert_equal [], users(:sam).reload.providers.map(&:id), "omitting providers leaves them alone"
  end

  test "create answers JSON for the LDAP import modal" do
    login_admin
    post "/assistants", params: { assistant: admin_params }, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert User.assistants.exists?(response.parsed_body["id"])

    post "/assistants", params: { assistant: admin_params(email: "") }, as: :json
    assert_response :unprocessable_entity
    assert_equal false, response.parsed_body["success"]
    assert_match(/Email/, response.parsed_body["message"])
  end

  test "the old JSON endpoints are gone" do
    login_admin
    %w[admins assistants].each do |page|
      post "/#{page}/search", params: { keyword: "" }
      assert_response :not_found
      post "/#{page}/#{users(:admin).id}/picture", params: { picture: png }
      assert_response :not_found
    end
  end
end
