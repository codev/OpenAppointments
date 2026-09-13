require "test_helper"

# Unguessable xxxx-xxxx booking slugs on services and providers.
class BookingSlugsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "generated slugs match the unambiguous format" do
    20.times do
      slug = BookingSlug.generate
      assert_match BookingSlug::FORMAT, slug
      assert_no_match(/[01ilo]/, slug)
    end
  end

  test "new services and providers get unique slugs automatically" do
    service = Service.create!(name: "Slugged", duration: 30)
    assert_match BookingSlug::FORMAT, service.booking_slug

    provider = User.create!(name: "Slug Provider", email: "slugprov@example.org",
                            role: Role.find_by!(slug: Role::PROVIDER))
    assert_match BookingSlug::FORMAT, provider.booking_slug

    customer = User.create!(name: "Slugless", email: "slugless@example.org",
                            role: Role.find_by!(slug: Role::CUSTOMER))
    assert_nil customer.booking_slug
  end

  test "every service and provider carries a slug" do
    assert Service.where(booking_slug: nil).none?
    assert User.providers.where(booking_slug: nil).none?
  end

  test "the booking payloads carry slugs but the public page does not, admin rows do" do
    assert BookingPayloads.available_services.all? { |row| row["booking_slug"].match?(/\A[a-z2-9]{4}-[a-z2-9]{4}\z/) }
    get "/"
    assert_no_match services(:haircut).booking_slug, response.body

    login_admin
    get "/services/#{services(:haircut).id}/edit"
    assert_select "a[href=?]", "/?service=#{services(:haircut).booking_slug}"
    get "/providers/#{users(:zane).id}/edit"
    assert_select "a[href=?]", "/?provider=#{users(:zane).booking_slug}"
  end

  test "regenerate endpoints issue a fresh slug" do
    login_admin
    service = services(:haircut)
    old_slug = service.booking_slug
    post "/services/#{service.id}/regenerate_link"
    assert_redirected_to "/services/#{service.id}/edit"
    new_slug = service.reload.booking_slug
    assert_match BookingSlug::FORMAT, new_slug
    assert_not_equal old_slug, new_slug

    provider = users(:zane)
    old_slug = provider.booking_slug
    post "/providers/#{provider.id}/regenerate_link"
    assert_redirected_to "/providers/#{provider.id}/edit"
    assert_not_equal old_slug, provider.reload.booking_slug
  end

  test "regenerating needs the right permissions" do
    customer = users(:jx)
    customer.create_settings!(username: "jxlogin", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jxlogin", password: "customer1" }

    post "/services/#{services(:haircut).id}/regenerate_link"
    assert_response :forbidden
    assert_equal services(:haircut).booking_slug, services(:haircut).reload.booking_slug
  end

  test "the regenerate labels exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[regenerate_link regenerate_link_warning_service regenerate_link_warning_provider change].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
