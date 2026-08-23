require "test_helper"

# Service categories is the first admin page served as Rails views inside Turbo
# Frames instead of a jQuery page script over JSON endpoints.
class ServiceCategoriesTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  def login_customer
    customer = users(:jx)
    customer.create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
  end

  def png
    fixture_file_upload("picture.png", "image/png")
  end

  test "the backend layout loads Turbo with Drive off" do
    login_admin
    get "/service_categories"
    assert_select "script[type=module]", text: /import \{ Turbo \} from ".*turbo.*\.js".*Turbo\.session\.drive = false/m
  end

  test "index lists the categories in a frame with rows linking to edit" do
    login_admin
    ServiceCategory.create!(name: "Beard", sort_order: 1)
    get "/service_categories"
    assert_response :success
    assert_select "turbo-frame#service_categories" do
      assert_select ".service-category-row[draggable=true][data-id=?]", service_categories(:hair).id.to_s
      assert_select "a[href=?]", "/service_categories/#{service_categories(:hair).id}/edit", text: "Hair"
      assert_select "a[href=?]", "/service_categories/new"
      assert_select "turbo-frame#service_category"
    end
    names = css_select(".service-category-row strong").map(&:text)
    assert_equal %w[Beard Hair], names
    assert_select "form[action=?][method=get]", "/service_categories"
    assert_select ".sort-alphabetically"
    assert_select "script[src*='pages/service_categories']"
    assert_select "script[src*='service_categories_http_client']", count: 0
  end

  test "index filters by keyword and says when nothing matches" do
    login_admin
    get "/service_categories", params: { keyword: "hai" }
    assert_select ".service-category-row", count: 1
    get "/service_categories", params: { keyword: "zzz" }
    assert_select ".service-category-row", count: 0
    assert_select "em", text: I18n.t("ea.no_records_found")
  end

  test "new renders an empty form in the detail frame" do
    login_admin
    get "/service_categories/new"
    assert_response :success
    assert_select "turbo-frame#service_category form[action=?][method=post][enctype='multipart/form-data']",
                  "/service_categories" do
      assert_select "input[name='service_category[name]'][required]"
      assert_select "textarea[name='service_category[description]']"
      assert_select "input[type=checkbox][name='service_category[is_hidden]']"
      assert_select "input[type=file][name='service_category[picture]']"
      assert_select "button[type=submit]", text: I18n.t("ea.save")
      assert_select "a[href=?]", "/service_categories", text: I18n.t("ea.cancel")
    end
    assert_select "form[action^='/service_categories/'][method=post] input[name=_method][value=delete]", count: 0
  end

  test "create saves the category, attaches the picture and reselects it" do
    login_admin
    assert_difference "ServiceCategory.count", 1 do
      post "/service_categories", params: {
        service_category: { name: "Colour", description: "Tints", is_hidden: "1", picture: png }
      }
    end
    category = ServiceCategory.find_by!(name: "Colour")
    assert_redirected_to "/service_categories?selected=#{category.id}"
    assert_equal "Tints", category.description
    assert category.is_hidden
    assert category.picture.attached?
    assert category.picture_padded.attached?

    follow_redirect!
    assert_select ".alert-success", text: I18n.t("ea.service_category_saved")
    assert_select ".service-category-row.selected[data-id=?]", category.id.to_s
    assert_select "turbo-frame#service_category form[action=?]", "/service_categories/#{category.id}"
  end

  test "create without a name re-renders the form with the error" do
    login_admin
    assert_no_difference "ServiceCategory.count" do
      post "/service_categories", params: { service_category: { name: "", description: "x" } }
    end
    assert_response :unprocessable_entity
    assert_select "turbo-frame#service_category form .is-invalid[name='service_category[name]']"
    assert_select ".form-message.alert-danger"
  end

  test "edit shows the record with its picture and a delete button" do
    login_admin
    category = service_categories(:hair)
    category.update!(description: "Cuts", is_hidden: true)
    PictureVariants.attach(category, file_fixture("picture.png").to_s,
                           filename: "picture.png", content_type: "image/png")
    get "/service_categories/#{category.id}/edit"
    assert_response :success
    assert_select "turbo-frame#service_category form[action=?]", "/service_categories/#{category.id}" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[name='service_category[name]'][value=Hair]"
      assert_select "textarea[name='service_category[description]']", text: "Cuts"
      assert_select "input[type=checkbox][name='service_category[is_hidden]'][checked]"
      assert_select "img#picture-preview[src*=rails]"
      assert_select "input[type=checkbox][name='service_category[remove_picture]']"
    end
    assert_select "form[action=?] input[name=_method][value=delete]", "/service_categories/#{category.id}"
  end

  test "update changes the fields and can remove the picture" do
    login_admin
    category = service_categories(:hair)
    PictureVariants.attach(category, file_fixture("picture.png").to_s,
                           filename: "picture.png", content_type: "image/png")
    patch "/service_categories/#{category.id}", params: {
      service_category: { name: "Hair & Scalp", description: "", is_hidden: "0", remove_picture: "1" }
    }
    assert_redirected_to "/service_categories?selected=#{category.id}"
    category.reload
    assert_equal "Hair & Scalp", category.name
    assert_not category.is_hidden
    assert_not category.picture.attached?
    assert_not category.picture_padded.attached?
  end

  test "update with a blank name re-renders edit with 422" do
    login_admin
    patch "/service_categories/#{service_categories(:hair).id}", params: { service_category: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "Hair", service_categories(:hair).reload.name
  end

  test "destroy deletes the category and keeps its services" do
    login_admin
    category = service_categories(:hair)
    service = Service.create!(name: "Trim", duration: 15, price: 0, currency: "GBP", category: category)
    assert_difference "ServiceCategory.count", -1 do
      delete "/service_categories/#{category.id}"
    end
    assert_redirected_to "/service_categories"
    assert_nil service.reload.id_service_categories
    follow_redirect!
    assert_select ".alert-success", text: I18n.t("ea.service_category_deleted")
  end

  test "sort alphabetically clears the manual order and returns to the list" do
    login_admin
    service_categories(:hair).update!(sort_order: 3)
    post "/service_categories/sort_alphabetically"
    assert_redirected_to "/service_categories"
    assert_nil service_categories(:hair).reload.sort_order
  end

  test "reorder still answers JSON for the drag handler" do
    login_admin
    post "/service_categories/reorder", params: { ids: [ service_categories(:hair).id ] }
    assert_equal({ "success" => true }, response.parsed_body)
    assert_equal 1, service_categories(:hair).reload.sort_order
  end

  test "search still answers JSON for the services page" do
    login_admin
    post "/service_categories/search", params: { keyword: "", limit: 1, offset: 0 }
    assert_response :success
    assert_equal "Hair", response.parsed_body.first["name"]
    assert_equal ServiceCategory.count.to_s, response.headers["X-Total-Count"]
  end

  test "the old JSON endpoints are gone" do
    login_admin
    post "/service_categories/store", params: { service_category: { name: "x" } }
    assert_response :not_found
    post "/service_categories/find", params: { service_category_id: service_categories(:hair).id }
    assert_response :not_found
    post "/service_categories/#{service_categories(:hair).id}/picture", params: { picture: png }
    assert_response :not_found
  end

  test "anonymous users are sent to login and customers are forbidden" do
    get "/service_categories/new"
    assert_redirected_to "/login"

    login_customer
    %w[/service_categories /service_categories/new].each do |path|
      get path
      assert_response :forbidden, path
    end
    get "/service_categories/#{service_categories(:hair).id}/edit"
    assert_response :forbidden
    post "/service_categories", params: { service_category: { name: "Nope" } }
    assert_response :forbidden
    delete "/service_categories/#{service_categories(:hair).id}"
    assert_response :forbidden
    assert ServiceCategory.exists?(service_categories(:hair).id)
  end

  test "save and delete fire the webhooks" do
    login_admin
    webhook = Webhook.create!(name: "Hook", url: "https://hooks.example.org/ea",
                              actions: "service_category_save,service_category_delete")
    post "/service_categories", params: { service_category: { name: "Hooked" } }
    id = ServiceCategory.find_by!(name: "Hooked").id
    delete "/service_categories/#{id}"

    deliveries = enqueued_jobs.select { |job| job["job_class"] == "WebhookDeliveryJob" }
                              .map { |job| job["arguments"].first(2) + [ job["arguments"].last["id"] ] }
    assert_equal [ [ webhook.id, Webhooks::SERVICE_CATEGORY_SAVE, id ],
                   [ webhook.id, Webhooks::SERVICE_CATEGORY_DELETE, id ] ], deliveries
  end
end
