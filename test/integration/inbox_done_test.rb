require "test_helper"

# The Inbox is an admin task list: each inbound message is Done once dealt
# with, Archive lists those with Undo, and the customer history keeps them.
class InboxDoneTest < ActionDispatch::IntegrationTest
  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def incoming(body, customer: users(:jx))
    Message.create!(direction: "incoming", channel: "email", from_address: customer&.email || "who@example.org",
                    customer_id: customer&.id, body: body, status: "received")
  end

  test "stylists and assistants cannot open the inbox and do not see the link" do
    assistant = users(:sam)
    assistant.create_settings!(username: "samlogin", password: Passwords.hash("assistant1"))
    [ %w[janedoe janedoe1], %w[samlogin assistant1] ].each do |username, password|
      post "/login/validate", params: { username: username, password: password }
      get "/inbox"
      assert_response :forbidden, "#{username} on /inbox"
      get "/customers"
      assert_select "a[href='/inbox']", count: 0
      reset!
    end

    login_admin
    get "/customers"
    assert_select "a[href='/inbox']"
    assert_select "a[href='/unknown_inbox']", count: 0
  end

  test "done leaves the inbox, shows under show done with who and when, and undo brings it back" do
    message = incoming("Running late")
    login_admin

    post "/messages/#{message.id}/done", headers: STREAM
    assert_response :success
    assert_select "turbo-stream[action=remove][target=?]", "inbox-message-#{message.id}"
    message.reload
    assert message.done?
    assert_equal users(:admin).id, message.done_by_id
    assert message.read?

    get "/inbox"
    assert_not_includes response.body, "Running late"
    get "/inbox", params: { done: 1 }
    assert_select "#inbox-message-#{message.id}" do
      assert_select ".inbox-row > .bubble-row + .inbox-done", 1, "Done by and Undo on their own line under the bubble" do
        assert_select ":first-child.inbox-done-by", text: /\ADone by #{Regexp.escape(users(:admin).name)} \d\d\/\d\d \d{1,2}:\d\d [ap]m\z/
        assert_select ":last-child form[action='/messages/#{message.id}/undo_done'] button", text: I18n.t("ea.undo")
      end
      assert_select ".inbox-actions", count: 0
    end

    post "/messages/#{message.id}/undo_done", headers: STREAM
    assert_select "turbo-stream[action=remove][target=?]", "inbox-message-#{message.id}"
    message.reload
    assert_not message.done?
    assert_nil message.done_by_id
    assert message.read?, "undo keeps the read state"
    get "/inbox"
    assert_select "#inbox-message-#{message.id} form[action='/messages/#{message.id}/done'] button", text: I18n.t("ea.inbox_done")
  end

  test "the customer history keeps done messages and replying does not mark done" do
    message = incoming("Running late")
    login_admin
    post "/customer_messages/send", params: { customer_id: users(:jx).id, channel: "email", body: "No problem" }
    assert_not message.reload.done?

    post "/messages/#{message.id}/done", headers: STREAM
    post "/customer_messages/find", params: { customer_id: users(:jx).id }
    assert_includes response.parsed_body["messages"].map { |row| row["body"] }, "Running late"
  end

  test "the header badge counts the messages not yet done, read or not, and done ones leave the list" do
    incoming("Open one").mark_read!
    incoming("Who is this?", customer: nil)
    done = incoming("Done one")
    done.update!(done_at: Time.current, done_by_id: users(:admin).id)
    login_admin
    get "/inbox", params: { unread: 1 }
    assert_select "#inbox-count", text: "2"
    assert_includes response.body, "Open one", "read messages stay listed; unread=1 is not a filter"
    assert_includes response.body, "Who is this?"
    assert_not_includes response.body, "Done one"
  end

  test "an unknown sender's message has done, archive and undo too" do
    message = incoming("Who is this?", customer: nil)
    login_admin
    post "/messages/#{message.id}/done", headers: STREAM
    assert message.reload.done?
    get "/inbox"
    assert_not_includes response.body, "Who is this?"
    get "/inbox", params: { done: 1 }
    assert_select "#inbox-message-#{message.id} form[action='/messages/#{message.id}/undo_done']"
  end

  test "the inbox filters are Inbox and Archive; the current one is marked and is not a link" do
    login_admin
    get "/inbox"
    assert_equal [ "Inbox", "Archive" ], css_select("#inbox-page .switch-view .nav-link").map { |a| a.text.strip }
    assert_select "#inbox-page .switch-view span.nav-link.active[aria-current=page]", text: "Inbox"
    assert_select "#inbox-page .switch-view a.nav-link[href='/inbox?done=1']", text: "Archive"
    assert_select "#inbox-page .switch-view a.active", count: 0
    get "/inbox", params: { done: 1 }
    assert_select "#inbox-page .switch-view span.nav-link.active[aria-current=page]", text: "Archive"
    assert_select "#inbox-page .switch-view a.nav-link[href='/inbox']", text: "Inbox"
  end

  test "the next page keeps the filter" do
    (InboxController::PER_PAGE + 1).times { |i| incoming("Old #{i}").mark_done!(users(:admin)) }
    login_admin
    { "/inbox?done=1" => "/inbox?done=1&page=2", "/inbox" => nil }.each do |path, next_page|
      get path
      if next_page
        assert_select "a[href=?]", next_page
      else
        assert_select "a[href*='page=2']", count: 0
      end
    end
  end

  test "only admins can mark done or undo" do
    message = incoming("Running late")
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    post "/messages/#{message.id}/done", headers: STREAM
    assert_response :forbidden
    post "/messages/#{message.id}/undo_done", headers: STREAM
    assert_response :forbidden
    assert_not message.reload.done?
  end
end
