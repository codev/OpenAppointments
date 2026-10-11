require "test_helper"

# Admins can permanently delete one message (mistakes, erasure requests): on
# the customer page, and in the Inbox for unknown senders, who have no customer page.
class MessageDeleteTest < ActionDispatch::IntegrationTest
  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  def incoming(body, customer: users(:jx))
    Message.create!(direction: "incoming", channel: "email", from_address: customer&.email || "who@example.org",
                    customer_id: customer&.id, body: body, status: "received")
  end

  test "an admin deletes one incoming or outgoing message and the header count follows" do
    kept = incoming("Keep me")
    gone = incoming("Delete me")
    sent = Message.create!(direction: "outgoing", channel: "email", to_address: users(:jx).email,
                           customer_id: users(:jx).id, body: "Sent by mistake", status: "sent")
    post "/login/validate", params: { username: "administrator", password: "administrator1" }

    delete "/messages/#{gone.id}", as: :json
    assert_response :success
    assert_equal({ "success" => true, "inbox_unread" => 1 }, response.parsed_body)
    delete "/messages/#{sent.id}", as: :json
    assert_equal [ kept.id ], Message.where(customer_id: users(:jx).id).pluck(:id)
  end

  test "stylists cannot delete" do
    message = incoming("Stay")
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    delete "/messages/#{message.id}", as: :json
    assert_response :forbidden
    assert Message.exists?(message.id)
  end

  test "delete follows the session role like done does" do
    done = incoming("Done me")
    gone = incoming("Delete me")
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    users(:admin).update!(role: roles(:provider))

    post "/messages/#{done.id}/done", headers: STREAM
    assert_response :success
    delete "/messages/#{gone.id}", as: :json
    assert_response :success
  end

  test "the inbox offers delete with a confirm on an unknown sender's row only, and removes the row in place" do
    unknown = incoming("Who is this?", customer: nil)
    known = incoming("Running late")
    post "/login/validate", params: { username: "administrator", password: "administrator1" }

    get "/inbox"
    assert_select "#inbox-message-#{unknown.id} form[action='/messages/#{unknown.id}'][data-turbo-confirm=?]",
                  I18n.t("ea.message_delete_confirm") do
      assert_select "input[name=_method][value=delete]", count: 1
    end
    assert_select "#inbox-message-#{known.id} form[action='/messages/#{known.id}']", count: 0

    delete "/messages/#{unknown.id}", headers: STREAM
    assert_select "turbo-stream[action=remove][target=?]", "inbox-message-#{unknown.id}"
    assert_not Message.exists?(unknown.id)
  end
end
