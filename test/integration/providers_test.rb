require "test_helper"

class ProvidersTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def provider_params(**overrides)
    { name: "Pat Stylist", email: "pat@example.org", language: "english", timezone: "Europe/London",
      settings: { username: "patstylist", password: "password1", password_confirmation: "password1" } }.deep_merge(overrides)
  end

  test "the form carries the plan JSON, the company plan for a new provider, and the first weekday" do
    login_admin
    get "/providers/new"
    assert_select "input[type=hidden][name='provider[settings][working_plan]'][value=?]", Setting.get("company_working_plan")
    assert_select "input[type=hidden][name='provider[settings][working_plan_exceptions]'][value='[]']"
    assert_select "#working-plan table.working-plan tbody"
    assert_select "#reset-working-plan[data-company-working-plan]"
    assert_select ".nav-pills a[href='#working-plan']"
    assert_select "textarea[name='provider[about]']"
    assert_select "#provider-services input[type=checkbox][name='provider[services][]'][value=?]", services(:haircut).id.to_s
    assert_match(/"first_weekday"/, response.body)

    exception = WorkingPlanException.create!(id_users_provider: users(:zane).id, start_date: "2026-09-01",
                                             end_date: "2026-09-01", start_time: "10:00", end_time: "14:00", breaks: "[]")
    get "/providers/#{users(:zane).id}/edit"
    assert_select "input[name='provider[settings][working_plan]'][value=?]", users(:zane).settings.working_plan
    assert_select "input[name='provider[settings][working_plan_exceptions]'][value*=?]", "\"id\":#{exception.id}"
    assert_select "a[href=?][target=_blank]", "/?provider=#{users(:zane).booking_slug}"
    assert_select "#provider-services input[value=?][checked]", services(:haircut).id.to_s
  end

  test "create without a plan gets the company plan; with a plan and exceptions they are stored" do
    login_admin
    post "/providers", params: { provider: provider_params }
    pat = User.providers.find_by!(email: "pat@example.org")
    assert_redirected_to "/providers?selected=#{pat.id}"
    assert_equal Setting.get("company_working_plan"), pat.settings.working_plan
    assert pat.booking_slug.present?

    plan = { monday: { start: "10:00", end: "16:00", breaks: [] } }.to_json
    exceptions = [ { startDate: "2026-09-01", endDate: "2026-09-01", startTime: "10:00", endTime: "14:00", breaks: [] } ].to_json
    patch "/providers/#{pat.id}", params: {
      provider: { services: [ "", services(:haircut).id ],
                  settings: { working_plan: plan, working_plan_exceptions: exceptions } }
    }
    assert_redirected_to "/providers?selected=#{pat.id}"
    assert_equal plan, pat.settings.reload.working_plan
    assert_equal [ "2026-09-01" ], WorkingPlanException.where(id_users_provider: pat.id).pluck(:start_date).map(&:to_s)
    assert_equal [ services(:haircut).id ], pat.services.map(&:id)

    patch "/providers/#{pat.id}", params: { provider: { settings: { working_plan_exceptions: "[]" } } }
    assert_equal 0, WorkingPlanException.where(id_users_provider: pat.id).count
  end

  test "regenerate link and sort alphabetically redirect" do
    login_admin
    post "/providers/#{users(:zane).id}/regenerate_link"
    assert_redirected_to "/providers/#{users(:zane).id}/edit"
    assert_not_equal "cdef-ghjk", users(:zane).reload.booking_slug

    users(:zane).update!(sort_order: 2)
    post "/providers/sort_alphabetically"
    assert_redirected_to "/providers"
    assert_nil users(:zane).reload.sort_order
  end

  test "the old JSON endpoints are gone and customers are forbidden" do
    login_admin
    post "/providers/search", params: { keyword: "" }
    assert_response :not_found
    post "/providers/regenerate_link", params: { provider_id: users(:zane).id }
    assert_response :not_found

    users(:jx).create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
    post "/providers/#{users(:zane).id}/regenerate_link"
    assert_response :forbidden
    delete "/providers/#{users(:zane).id}"
    assert_response :forbidden
  end
end
