require "rails_helper"

RSpec.describe Webhooks::MailgunEventsController do
  describe "#create" do
    subject(:make_request) { post :create, params: params, as: :json }

    before { allow(controller).to receive(:valid_signature?).and_return(true) }

    context "when the event is delivered" do
      let(:params) do
        {
          signature: {
            timestamp: "1683409840",
            token: "random-token-string",
            signature: "fake-signature",
          },
          event_data: {
            event: "delivered",
            id: "unique-event-id",
            timestamp: 1_683_409_840.123,
            recipient: "user@example.com",
            message: {
              headers: {
                message_id: "abc123@edifyapp.org",
              },
            },
            delivery_status: {
              code: 250,
              message: "OK",
            },
            ip: "1.2.3.4",
            reason: nil,
            client_info: {
              user_agent: "Mozilla/5.0",
            },
          },
        }
      end

      it "returns a 200 response" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "creates a new Analytics::MailgunEvent record" do
        expect { make_request }.to change(Analytics::MailgunEvent, :count).by(1)
      end

      it "saves the event attributes correctly" do
        make_request
        event = Analytics::MailgunEvent.last

        expect(event).to have_attributes(
          email: "user@example.com",
          event: "delivered",
          mailgun_event_id: "unique-event-id",
          mailgun_message_id: "abc123@edifyapp.org",
          ip: "1.2.3.4",
          status: "250",
          response: "OK",
          useragent: "Mozilla/5.0",
        )
      end
    end

    context "when the event is failed" do
      let(:params) do
        {
          signature: {
            timestamp: "1683409840",
            token: "random-token-string",
            signature: "fake-signature",
          },
          event_data: {
            event: "failed",
            id: "failed-event-id",
            timestamp: 1_683_409_840,
            recipient: "bounced@example.com",
            message: {
              headers: {
                message_id: "def456@edifyapp.org",
              },
            },
            delivery_status: {
              code: 550,
              message: "Mailbox not found",
            },
            ip: nil,
            reason: "bounce",
            client_info: {},
          },
        }
      end

      it "returns a 200 response" do
        make_request
        expect(response).to have_http_status(:ok)
      end

      it "saves the reason and status" do
        make_request
        event = Analytics::MailgunEvent.last

        expect(event).to have_attributes(
          email: "bounced@example.com",
          event: "failed",
          reason: "bounce",
          status: "550",
          response: "Mailbox not found",
        )
      end
    end

    context "when the signature is invalid" do
      before { allow(controller).to receive(:valid_signature?).and_return(false) }

      let(:params) do
        {
          signature: {
            timestamp: "1683409840",
            token: "random-token-string",
            signature: "bad-signature",
          },
          event_data: {
            event: "delivered",
            id: "unique-event-id",
            timestamp: 1_683_409_840,
            recipient: "user@example.com",
            message: { headers: { message_id: "abc123@edifyapp.org" } },
            delivery_status: { code: 250, message: "OK" },
          },
        }
      end

      it "returns a 401 response" do
        make_request
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not create a record" do
        expect { make_request }.not_to(change(Analytics::MailgunEvent, :count))
      end
    end

    context "when event_data is missing" do
      let(:params) do
        {
          signature: {
            timestamp: "1683409840",
            token: "random-token-string",
            signature: "fake-signature",
          },
        }
      end

      it "returns a 422 response" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when a required attribute is missing" do
      let(:params) do
        {
          signature: {
            timestamp: "1683409840",
            token: "random-token-string",
            signature: "fake-signature",
          },
          event_data: {
            event: "delivered",
            id: "unique-event-id",
            timestamp: nil,
            recipient: "user@example.com",
            message: { headers: { message_id: "abc123@edifyapp.org" } },
            delivery_status: { code: 250, message: "OK" },
          },
        }
      end

      it "returns a 422 response" do
        make_request
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not create a record" do
        expect { make_request }.not_to(change(Analytics::MailgunEvent, :count))
      end
    end
  end
end
