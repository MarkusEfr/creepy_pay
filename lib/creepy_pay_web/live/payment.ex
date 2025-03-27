defmodule CreepyPayWeb.Live.Payment do
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments
  alias CreepyPay.StealthPay

  def mount(%{"payment_metacore" => payment_metacore}, _session, socket) do
    with {:ok, payment} <- Payments.get_payment(payment_metacore) do
      {:ok,
       assign(socket,
         payment: payment,
         payment_contract: StealthPay.get_payment_processor(),
         tx_error: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
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
    """
  end

  def handle_event("tx_failed", %{"reason" => reason}, socket) do
    {:noreply,
     socket
     |> assign(:tx_error, reason)}
  end

  def handle_event(
        "tx_sent",
        %{"tx_hash" => tx_hash},
        %{assigns: %{payment: %{invoice_details: invoice_details} = payment}} = socket
      ) do
    updates = %{
      status: "transaction_sent",
      invoice_details: invoice_details |> Map.put(:tx_hash, tx_hash)
    }

    Payments.update_payment(payment, updates)

    {:noreply, socket |> assign(:payment, payment |> Map.merge(updates))}
  end
end
