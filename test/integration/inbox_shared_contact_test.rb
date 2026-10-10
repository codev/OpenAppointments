require "test_helper"

# An Inbox row from a contact several customers share names the others and
# lets an admin move that one message to one of them.
class InboxSharedContactTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @jx = users(:jx)
    @partner = User.create!(name: "Partner Person", email: @jx.email, role: roles(:customer))
    @message = Message.create!(direction: "incoming", channel: "email", from_address: @jx.email,
                               customer_id: @jx.id, body: "Running late", status: "received")
    @earlier = Message.create!(direction: "incoming", channel: "email", from_address: @jx.email,
                               customer_id: @jx.id, body: "Earlier one", status: "received")
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the row names the other customers and offers to move the message to each" do
    get "/inbox"
    assert_select "#inbox-message-#{@message.id} .inbox-shared-contact", text: /#{Regexp.escape(I18n.t('ea.message_shared_contact'))}.*Partner Person/m do
      assert_select "form[action='/messages/#{@message.id}/move'] input[name=customer_id][value=?]", @partner.id.to_s
      assert_select "button", text: I18n.t("ea.message_move_to").sub("{name}", "Partner Person")
    end
  end

  test "a page looks up shared contacts in one email and one phone query, however many rows" do
    texter = User.create!(name: "Tex Ter", mobile_number: "07700 900321", role: roles(:customer))
    sibling = User.create!(name: "Sib Ling", phone_number: "+447700900321", role: roles(:customer))
    from_phone = Message.create!(direction: "incoming", channel: "sms", from_address: "+447700900321",
                                 customer_id: texter.id, body: "On my way", status: "received")
    3.times do |i|
      solo = User.create!(name: "Solo #{i}", email: "solo#{i}@example.org", role: roles(:customer))
      Message.create!(direction: "incoming", channel: "email", from_address: solo.email,
                      customer_id: solo.id, body: "Hello #{i}", status: "received")
    end

    lookups = 0
    counter = ->(*, payload) { lookups += 1 if payload[:sql].match?(/LOWER\(email\)|phone_number/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/inbox" }

    assert_equal 2, lookups
    assert_select "#inbox-message-#{@message.id} .inbox-shared-contact", text: /Partner Person/
    assert_select "#inbox-message-#{from_phone.id} .inbox-shared-contact", text: /Sib Ling/
    assert_select "#inbox-message-#{from_phone.id} .inbox-shared-contact", text: /Tex Ter/, count: 0
  end

  test "a contact only one customer uses shows no alternatives" do
    @partner.update!(email: "partner@example.org")
    get "/inbox"
    assert_select ".inbox-shared-contact", count: 0
  end

  test "move reassigns only that message, sends nothing, and re-renders the row" do
    Notification.create!(title: "Customer Message Received", event: "customer_message", audiences: %w[provider admins],
                         channels: %w[email], short_text: "New message from {{Customer Name}}")
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      post "/messages/#{@message.id}/move", params: { customer_id: @partner.id }, headers: STREAM
    end
    assert_select "turbo-stream[action=replace][target=?]", "inbox-message-#{@message.id}" do
      assert_select "template .inbox-meta a[href='/customers?customer_id=#{@partner.id}']", text: "Partner Person"
      assert_select "template .inbox-moved", text: I18n.t("ea.message_moved")
      assert_select "template form[action='/messages/#{@message.id}/move'] input[name=customer_id][value=?]", @jx.id.to_s
    end
    assert_equal @partner.id, @message.reload.customer_id
    assert_equal @jx.id, @earlier.reload.customer_id
  end

  test "a message cannot be moved to a customer who does not use its contact, nor by a stylist" do
    stranger = User.create!(name: "Stranger", email: "stranger@example.org", role: roles(:customer))
    post "/messages/#{@message.id}/move", params: { customer_id: stranger.id }, headers: STREAM
    assert_response :unprocessable_entity
    assert_equal @jx.id, @message.reload.customer_id

    reset!
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    post "/messages/#{@message.id}/move", params: { customer_id: @partner.id }, headers: STREAM
    assert_response :forbidden
    assert_equal @jx.id, @message.reload.customer_id
  end
end
