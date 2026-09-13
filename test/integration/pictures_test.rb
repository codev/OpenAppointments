require "test_helper"

class PicturesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def png = fixture_file_upload("picture.png", "image/png")

  test "provider picture upload with the form, preview url and removal" do
    login_admin
    zane = users(:zane)

    patch "/providers/#{zane.id}", params: { provider: { picture: png } }
    assert_redirected_to "/providers?selected=#{zane.id}"
    assert zane.reload.picture_padded.attached?, "upload must create the padded variant"
    assert zane.picture_zoomed.attached?, "upload must create the zoomed variant"
    assert zane.picture.attached?
    get "/providers/#{zane.id}/edit"
    assert_select "img.picture-preview[src*='/rails/']"
    assert_select "input[name='provider[remove_picture]']"

    patch "/providers/#{zane.id}", params: { provider: { remove_picture: "1" } }
    assert_not zane.reload.picture.attached?
  end

  test "non-image uploads are rejected" do
    login_admin
    file = Rack::Test::UploadedFile.new(StringIO.new("plain"), "text/plain", original_filename: "x.txt")
    patch "/providers/#{users(:zane).id}", params: { provider: { picture: file } }
    assert_response :unprocessable_entity
    assert_select ".form-message", text: /Unsupported picture type/
    assert_not users(:zane).reload.picture.attached?
  end

  test "picture upload requires a permitted session" do
    patch "/providers/#{users(:zane).id}", params: { provider: { picture: png } }
    assert_response :redirect
    assert_not users(:zane).reload.picture.attached?
  end

  test "backend row payloads carry picture_url" do
    users(:zane).picture.attach(png)
    row = EaRows.user_row(users(:zane))
    assert row["picture_url"].present?

    services(:haircut).picture.attach(png)
    assert EaRows.service_row(services(:haircut))["picture_url"].present?
  end

  test "booking payloads carry picture urls" do
    users(:zane).picture.attach(png)
    services(:haircut).picture.attach(png)
    service_categories(:hair).picture.attach(png)

    provider = BookingPayloads.available_providers.find { |p| p["id"] == users(:zane).id }
    assert provider["picture_url"].present?

    service = BookingPayloads.available_services.find { |s| s["id"] == services(:haircut).id }
    assert service["picture_url"].present?

    category = BookingPayloads.available_categories.find { |c| c["id"] == service_categories(:hair).id }
    assert category["picture_url"].present?
  end
end
