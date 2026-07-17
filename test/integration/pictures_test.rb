require "test_helper"

class PicturesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def png = fixture_file_upload("picture.png", "image/png")

  test "provider picture upload, payload url and removal" do
    login_admin
    jane = users(:jane)

    post "/providers/#{jane.id}/picture", params: { picture: png }
    assert_response :success
    assert response.parsed_body["picture_url"].present?
    assert jane.reload.picture.attached?

    post "/providers/#{jane.id}/picture", params: { remove: "1" }
    assert_response :success
    assert_nil response.parsed_body["picture_url"]
    assert_not jane.reload.picture.attached?
  end

  test "service and category picture upload" do
    login_admin
    post "/services/#{services(:haircut).id}/picture", params: { picture: png }
    assert_response :success
    assert services(:haircut).reload.picture.attached?

    post "/service_categories/#{service_categories(:hair).id}/picture", params: { picture: png }
    assert_response :success
    assert service_categories(:hair).reload.picture.attached?
  end

  test "non-image uploads are rejected" do
    login_admin
    file = Rack::Test::UploadedFile.new(StringIO.new("plain"), "text/plain", original_filename: "x.txt")
    post "/providers/#{users(:jane).id}/picture", params: { picture: file }
    assert_response :internal_server_error
    assert_equal false, response.parsed_body["success"]
    assert_not users(:jane).reload.picture.attached?
  end

  test "picture upload requires a permitted session" do
    post "/providers/#{users(:jane).id}/picture", params: { picture: png }
    assert_response :redirect
  end

  test "backend row payloads carry picture_url" do
    users(:jane).picture.attach(png)
    row = EaRows.user_row(users(:jane))
    assert row["picture_url"].present?

    services(:haircut).picture.attach(png)
    assert EaRows.service_row(services(:haircut))["picture_url"].present?
  end

  test "booking payloads carry picture urls" do
    users(:jane).picture.attach(png)
    services(:haircut).picture.attach(png)
    service_categories(:hair).picture.attach(png)

    provider = BookingPayloads.available_providers.find { |p| p["id"] == users(:jane).id }
    assert provider["picture_url"].present?

    service = BookingPayloads.available_services.find { |s| s["id"] == services(:haircut).id }
    assert service["picture_url"].present?

    category = BookingPayloads.available_categories.find { |c| c["id"] == service_categories(:hair).id }
    assert category["picture_url"].present?
  end
end
