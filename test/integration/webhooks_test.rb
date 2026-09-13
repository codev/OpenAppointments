require "test_helper"

class WebhooksTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  setup do
    @hook = Webhook.create!(name: "Old hook", url: "https://hooks.example.org/old",
                            actions: "appointment_save,customer_delete")
  end

  test "index links back to integrations and shows the action count per row" do
    login_admin
    get "/webhooks"
    assert_response :success
    assert_select "turbo-frame#webhooks a[href=?]", "/integrations"
    assert_select ".webhook-row[data-id=?] small", @hook.id.to_s, text: "2 #{I18n.t('ea.actions')}"
    assert_select "a[href=?]", "/webhooks/#{@hook.id}/edit"
  end

  test "edit renders every available action as a switch with the saved ones checked" do
    login_admin
    get "/webhooks/#{@hook.id}/edit"
    assert_select "#actions input[type=checkbox][name='webhook[actions][]']",
                  count: WebhooksController::AVAILABLE_ACTIONS.length
    assert_select "#actions input[value=appointment_save][checked]"
    assert_select "#actions input[value=customer_delete][checked]"
    assert_select "#actions input[value=service_save][checked]", count: 0
    assert_select "label[for=include-appointment-save]", text: I18n.t("ea.appointment_save")
    assert_select "input[type=checkbox][name='webhook[is_ssl_verified]'][checked]"
  end

  test "actions round trip as a comma list, unknown ones dropped, none means empty" do
    login_admin
    patch "/webhooks/#{@hook.id}", params: {
      webhook: { actions: [ "", "service_save", "bogus", "admin_delete" ], is_ssl_verified: "0" }
    }
    assert_redirected_to "/webhooks?selected=#{@hook.id}"
    @hook.reload
    assert_equal "service_save,admin_delete", @hook.actions
    assert_not @hook.is_ssl_verified

    patch "/webhooks/#{@hook.id}", params: { webhook: { actions: [ "" ] } }
    assert_equal "", @hook.reload.actions
  end

  test "saving a webhook enqueues no deliveries" do
    login_admin
    Webhook.create!(name: "Listener", url: "https://hooks.example.org/all",
                    actions: WebhooksController::AVAILABLE_ACTIONS.join(","))
    assert_no_enqueued_jobs only: WebhookDeliveryJob do
      post "/webhooks", params: { webhook: { name: "New", url: "https://hooks.example.org/new" } }
      delete "/webhooks/#{Webhook.find_by!(name: 'New').id}"
    end
  end

  test "a missing url re-renders with the field marked" do
    login_admin
    post "/webhooks", params: { webhook: { name: "No url", url: "" } }
    assert_response :unprocessable_entity
    assert_select "input.is-invalid[name='webhook[url]']"
    assert_nil Webhook.find_by(name: "No url")
  end

  test "the old JSON endpoints are gone and customers are forbidden" do
    login_admin
    post "/webhooks/search", params: { keyword: "" }
    assert_response :not_found
    post "/webhooks/store", params: { webhook: { name: "x", url: "y" } }
    assert_response :not_found

    users(:jx).create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
    get "/webhooks"
    assert_response :forbidden
    delete "/webhooks/#{@hook.id}"
    assert_response :forbidden
    assert Webhook.exists?(@hook.id)
  end
end
