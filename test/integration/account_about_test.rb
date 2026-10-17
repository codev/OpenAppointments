require "test_helper"

class AccountAboutTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  def png = fixture_file_upload("picture.png", "image/png")

  def account_params(user, extra = {})
    { name: user.name, email: user.email, timezone: "UTC", settings: { username: user.settings.username } }.merge(extra)
  end

  test "a stylist's account page has the About & Services tab with a read-only services list" do
    login_provider
    get "/account"
    assert_select "form#account-form[enctype='multipart/form-data']"
    assert_select "ul.nav.nav-pills.switch-view a[href='#details']", text: "Details"
    assert_select "ul.nav.nav-pills.switch-view a[href='#about-services']", text: "About & Services"
    assert_select "#about-services input[type=file][name='account[picture]']"
    assert_select "#about-services textarea[name='account[about]']"
    assert_select "#about-services textarea[name='account[services_description]']"
    assert_select "#about-services .account-services li", text: services(:haircut).name
    assert_select "#about-services input[type=checkbox][name*='services']", false
  end

  test "admins and assistants see no About & Services tab" do
    login_admin
    get "/account"
    assert_select "ul.switch-view", false
    assert_select "textarea[name='account[about]']", false
  end

  test "a stylist saves about text, services description and a picture" do
    login_provider
    zane = users(:zane)
    post "/account/save", params: { account: account_params(zane, about: "Cuts since 1999", services_description: "Dry cuts", picture: png) }
    assert_response :success
    zane.reload
    assert_equal "Cuts since 1999", zane.about
    assert_equal "Dry cuts", zane.services_description
    assert zane.picture.attached?
    assert zane.picture_padded.attached?
  end

  test "an unsupported picture is rejected with a flash" do
    login_provider
    file = Rack::Test::UploadedFile.new(StringIO.new("plain"), "text/plain", original_filename: "x.txt")
    post "/account/save", params: { form: "1", account: account_params(users(:zane), picture: file) }
    assert_redirected_to "/account"
    assert_match(/Unsupported picture type/, flash[:alert])
    assert_not users(:zane).reload.picture.attached?
  end

  test "an admin posting about text has it ignored" do
    login_admin
    post "/account/save", params: { account: account_params(users(:admin), about: "Sneaky", services_description: "Sneaky") }
    assert_response :success
    assert_nil users(:admin).reload.about
    assert_nil users(:admin).services_description
  end
end
