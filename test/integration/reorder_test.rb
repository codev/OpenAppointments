require "test_helper"

class ReorderTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "reorder persists the dragged order and drives the booking page" do
    login_admin
    zebra = Service.create!(name: "AAA First Alphabetically", duration: 30)
    ServiceProviderLink.create!(id_services: zebra.id, id_users: users(:zane).id)

    post "/services/reorder", params: { ids: [ services(:haircut).id, zebra.id ] }
    assert_response :success
    assert_equal 1, services(:haircut).reload.sort_order
    assert_equal 2, zebra.reload.sort_order

    names = BookingPayloads.available_services.map { |service| service["name"] }
    assert_operator names.index(services(:haircut).name), :<, names.index(zebra.name)

    post "/services/search", params: { keyword: "" }
    admin_names = response.parsed_body.map { |row| row["name"] }
    assert_operator admin_names.index(services(:haircut).name), :<, admin_names.index(zebra.name)
  end

  test "unordered records fall to the end alphabetically" do
    login_admin
    zebra = Service.create!(name: "AAA Unordered", duration: 30)
    ServiceProviderLink.create!(id_services: zebra.id, id_users: users(:zane).id)
    post "/services/reorder", params: { ids: [ services(:haircut).id ] }

    names = BookingPayloads.available_services.map { |service| service["name"] }
    assert_operator names.index(services(:haircut).name), :<, names.index(zebra.name)
  end

  test "sort alphabetically clears the manual order" do
    login_admin
    post "/services/reorder", params: { ids: [ services(:haircut).id ] }
    assert_equal 1, services(:haircut).reload.sort_order

    post "/services/sort_alphabetically"
    assert_response :success
    assert_nil services(:haircut).reload.sort_order
  end

  test "categories and providers reorder too" do
    login_admin
    post "/service_categories/reorder", params: { ids: [ service_categories(:hair).id ] }
    assert_equal 1, service_categories(:hair).reload.sort_order

    post "/providers/reorder", params: { ids: [ users(:zane).id ] }
    assert_equal 1, users(:zane).reload.sort_order

    # The providers endpoint must not touch other roles.
    post "/providers/reorder", params: { ids: [ users(:admin).id ] }
    assert_nil users(:admin).reload.sort_order
  end

  test "reordering requires the edit privilege" do
    customer = users(:jx)
    customer.create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }

    post "/services/reorder", params: { ids: [ services(:haircut).id ] }
    assert_equal false, response.parsed_body["success"]
    assert_nil services(:haircut).reload.sort_order
  end

  test "the admin lists show the reorder hint and sort button" do
    login_admin
    %w[services service_categories providers].each do |page|
      get "/#{page}"
      assert_select ".sort-alphabetically", text: I18n.t("ea.sort_alphabetically")
      assert_match I18n.t("ea.drag_to_reorder"), response.body
    end
  end

  test "sort order rides export and import" do
    login_admin
    post "/services/reorder", params: { ids: [ services(:haircut).id ] }
    upload_path = Rails.root.join("tmp", "reorder-roundtrip-#{SecureRandom.hex(4)}.ods")
    File.binwrite(upload_path, DataExport.generate)
    services(:haircut).update!(sort_order: nil)

    post "/import/start", params: {
      file: Rack::Test::UploadedFile.new(upload_path, Ods::MIMETYPE), import_type: "ods",
      phases: [ "services" ], days_back: 21, days_forward: 21
    }
    perform_enqueued_jobs
    assert_equal 1, services(:haircut).reload.sort_order
  ensure
    FileUtils.rm_f(upload_path) if upload_path
  end

  test "the reorder strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[drag_to_reorder sort_alphabetically sort_alphabetically_confirm].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
