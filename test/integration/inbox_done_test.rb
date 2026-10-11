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

  test "stylists and assistants cannot open either inbox and do not see the links" do
    assistant = users(:sam)
    assistant.create_settings!(username: "samlogin", password: Passwords.hash("assistant1"))
    [ %w[janedoe janedoe1], %w[samlogin assistant1] ].each do |username, password|
      post "/login/validate", params: { username: username, password: password }
      get "/inbox"
      assert_response :forbidden, "#{username} on /inbox"
      get "/unknown_inbox"
      assert_response :forbidden, "#{username} on /unknown_inbox"
      get "/customers"
      assert_select "a[href='/inbox']", count: 0
      assert_select "a[href='/unknown_inbox']", count: 0
      reset!
    end

    login_admin
    get "/customers"
    assert_select "a[href='/inbox']"
    assert_select "a[href='/unknown_inbox']"
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
      assert_select ".inbox-done-by", text: /#{Regexp.escape(users(:admin).name)}/
      assert_select "form[action='/messages/#{message.id}/undo_done'] button", text: I18n.t("ea.undo")
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

  test "the header badge and the unread filter leave done messages out" do
    incoming("Open one")
    done = incoming("Done one")
    done.update!(done_at: Time.current, done_by_id: users(:admin).id)
    login_admin
    get "/inbox", params: { unread: 1 }
    assert_select "#inbox-unread", text: "1"
    assert_includes response.body, "Open one"
    assert_not_includes response.body, "Done one"
  end

  test "the unknown inbox has done, show done and undo too" do
    message = incoming("Who is this?", customer: nil)
    login_admin
    post "/messages/#{message.id}/done", headers: STREAM
    assert message.reload.done?
    get "/unknown_inbox"
    assert_not_includes response.body, "Who is this?"
    get "/unknown_inbox", params: { done: 1 }
    assert_select "#inbox-message-#{message.id} form[action='/messages/#{message.id}/undo_done']"
  end

  test "the inbox filters are To Do, Unread Only and Archive; the unknown inbox has To Do and Archive" do
    login_admin
    get "/inbox"
    assert_equal [ "To Do", "Unread Only", "Archive" ], css_select("#inbox-page .btn-group a").map { |a| a.text.strip }
    assert_select "#inbox-page .btn-group a.btn-secondary", text: "To Do"
    get "/unknown_inbox"
    assert_equal [ "To Do", "Archive" ], css_select("#unknown-inbox-page .btn-group a").map { |a| a.text.strip }
  end

  test "the next page keeps the filter" do
    (InboxController::PER_PAGE + 1).times { |i| incoming("Old #{i}").mark_done!(users(:admin)) }
    login_admin
    { "/inbox?done=1" => "/inbox?done=1&page=2", "/inbox?unread=1" => nil, "/inbox" => nil }.each do |path, next_page|
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
