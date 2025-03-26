defmodule CreepyPayWeb.Live.Payment do
  @moduledoc """
  LiveView for payment processing.
  """
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments

  def mount(%{"payment_metacore" => payment_metacore} = _params, _session, socket) do
    {:ok, payment} = Payments.get_payment(payment_metacore)
    IO.inspect(payment, label: "[DEBUG] mount payment")

    socket =
      socket
      |> assign(:payment, payment)
      |> assign(:payment_metacore, payment_metacore)
      |> assign(:payment_contract, Application.get_env(:creepy_pay, :payment_processor))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id="send-tx"
      phx-hook={"SendTx"}
      class="cp-mobile-wrapper" >
      <div class="cp-invoice-card">
        <div class="cp-header">
          <h1 class="cp-title">CreepyPay Invoice</h1>
        </div>

        <div class="cp-info-group">
          <label>💀 Metacore</label>
          <p class="cp-value"><%= @payment_metacore %></p>

          <label>💰 Amount</label>
          <p class="cp-value"><%= @payment.amount %> wei</p>

          <label>🧠 Madness Key</label>
          <p class="cp-value"><%= @payment.madness_key_hash %></p>

          <label>📦 Status</label>
          <p class={"cp-status cp-status-#{@payment.status}"}><%= @payment.status %></p>
        </div>
        <div
      data-to={@payment_contract}
      data-value={@payment.amount}
      data-data="0x"
      class="cp-actions">
      <button class="cp-btn">🧾 Confirm Payment</button>
      </div>
      </div>
    </div>
    """
  end

  def handle_event("tx_sent", %{"tx_hash" => tx_hash}, socket) do
    IO.puts("User sent TX: #{tx_hash}")
    {:noreply, assign(socket, :tx_status, "Transaction sent: #{tx_hash}")}
  end
end
