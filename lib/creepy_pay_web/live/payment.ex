defmodule CreepyPayWeb.Live.Payment do
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments
  alias CreepyPay.StealthPay

  def mount(%{"payment_metacore" => payment_metacore}, _session, socket) do
    case Payments.get_payment(payment_metacore) do
      {:ok, payment} ->
        {:ok,
         assign(socket,
           payment: payment,
           payment_contract: StealthPay.get_payment_processor(),
           tx_error: nil,
           not_found: false
         )}

      {:error, _reason} ->
        {:ok,
         assign(socket,
           not_found: true
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <%= if @not_found do %>
      <div class="cp-404-wrapper">
        <div class="cp-404-box">
          <h1 class="cp-404-title">😵 Payment Not Found</h1>
          <p class="cp-404-message">
            The payment you’re looking for has vanished into the crypto void.
          </p>
          <a href="/" class="cp-404-home-btn">👻 Return to Safety</a>
        </div>
      </div>
    <% else %>
      <div class="cp-mobile-wrapper">
        <div class="cp-invoice-card">
          <div class="cp-header">
            <h1 class="cp-title">CreepyPay Invoice</h1>
          </div>

          <div class="cp-info-group">
            <label>💀 Metacore</label>
            <p class="cp-value"><%= @payment.payment_metacore %></p>

            <label>💰 Amount</label>
            <p class="cp-value"><%= @payment.amount %> wei</p>

            <label>🧠 Madness Key</label>
            <p class="cp-value"><%= @payment.madness_key_hash %></p>

            <label>📦 Status</label>
            <p class={"cp-status cp-status-#{@payment.status}"}><%= @payment.status %></p>
          </div>

          <div id="send-tx"
            phx-hook="SendTx"
            data-contract={@payment_contract}
            data-payment={Jason.encode!(@payment)}
            class="cp-actions">
            <button :if={@payment.status == "pending"} class="cp-btn">🧾 Confirm Payment</button>
          </div>

          <%= if @tx_error do %>
            <div id="error-box" class="error-box" phx-hook="DismissBox">
              <span class="close-error" onclick="this.parentNode.remove()">✖</span>
              <p>⚠️ <%= @tx_error %></p>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("tx_failed", %{"reason" => reason}, socket) do
    {:noreply,
     socket
     |> assign(:tx_error, reason)}
  end

  def handle_event(
        "tx_sent",
        %{
          "receipt" =>
            %{
              "from" => _sender_address,
              "gasPrice" => _gas_price,
              "gasUsed" => _gas_used,
              "hash" => _tx_hash,
              "status" => status
            } = receipt
        },
        %{assigns: %{payment: payment}} = socket
      ) do
    updates = %{
      status: define_status_changeset(status),
      invoice_details: Map.put_new(payment.invoice_details, :receipt, receipt)
    }

    {:ok, payment} = Payments.update_payment(payment, updates)

    {:noreply, socket |> assign(:payment, payment)}
  end

  defp define_status_changeset(1), do: "TX_CONFIRMED"
  defp define_status_changeset(_), do: "TX_FAILED"
end
