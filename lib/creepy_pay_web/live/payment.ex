defmodule CreepyPayWeb.Live.Payment do
  @moduledoc """
  LiveView for payment processing.
  """
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments

  def mount(%{"payment_metacore" => payment_metacore} = _params, _session, socket) do
    {:ok, payment} = Payments.get_payment(payment_metacore)

    socket =
      socket
      |> assign(:payment, payment)
      |> assign(:payment_metacore, payment_metacore)
      |> assign(:payment_contract, Application.get_env(:creepy_pay, :payment_processor))
      |> assign(:payment_data, payment_metacore)
      |> assign(:tx_error, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
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
        <div id="send-tx"
          phx-hook="SendTx"
          data-to={@payment_contract}
          data-value={@payment.amount}
          data-data={@payment_data}
          class="cp-actions">
          <button class="cp-btn">🧾 Confirm Payment</button>
        </div>
        <%= if @tx_error do %>
         <div id="error-box" class="error-box" phx-hook="DismissBox">
          <span class="close-error" style="float:right;cursor:pointer;font-weight:bold;">✖</span>
          <p>⚠️ <%= @tx_error %></p>
          </div>
        <% end %>


      </div>
    </div>
    """
  end

  def handle_event("tx_failed", %{"reason" => reason}, socket) do
    IO.puts("TX failed: #{reason}")

    {:noreply,
     socket
     |> put_flash(:error, "Transaction failed: #{reason}")
     |> assign(:tx_error, reason)}
  end

  def handle_event("tx_sent", %{"tx_hash" => tx_hash}, socket) do
    IO.puts("User sent TX: #{tx_hash}")
    {:noreply, assign(socket, :tx_status, "Transaction sent: #{tx_hash}")}
  end
end
