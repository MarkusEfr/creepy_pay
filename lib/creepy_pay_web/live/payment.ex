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
        {:ok, assign(socket, not_found: true)}
    end
  end

  def render(assigns) do
    ~H"""
    <%= if @not_found do %>
      <div class="cp-invoice-wrapper">
        <div class="cp-header">
          <img src="/images/icons/warning_cat.png" class="cp-icon" />
          <h1 class="cp-title">404: Invoice Vanished</h1>
        </div>
        <p>This invoice was either devoured by the void or never born.</p>
        <a href="/" class="cp-btn">Return to Safety</a>
      </div>
    <% else %>
      <div class="cp-invoice-wrapper">
        <div class="cp-header">
          <img src="/images/icons/golden_cat_hat.png" class="cp-icon" />
          <h1 class="cp-title">Obsidian Invoice</h1>
        </div>

        <div class="cp-info-group">
          <label>Metacore</label>
          <p class="cp-value"><%= @payment.payment_metacore %></p>

          <label>Amount</label>
          <p class="cp-value"><%= @payment.amount %> wei</p>

          <label>Madness Key</label>
          <p class="cp-value"><%= @payment.madness_key_hash %></p>

          <label>Status</label>
          <p class={"cp-status cp-status-#{String.downcase(@payment.status)}"}>
            <%= @payment.status %>
          </p>
        </div>

        <div id="send-tx"
          phx-hook="SendTx"
          data-contract={@payment_contract}
          data-payment={Jason.encode!(@payment)}
          class="cp-actions">
          <button :if={@payment.status == "pending"} class="cp-btn">
            Confirm Payment
          </button>
        </div>

        <%= if @tx_error do %>
          <div class="error-box">
            <span class="close-error" onclick="this.parentNode.remove()">✖</span>
            <p>⚠️ <%= @tx_error %></p>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  def handle_event("tx_failed", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, :tx_error, reason)}
  end

  def handle_event(
        "tx_sent",
        %{
          "receipt" =>
            %{
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

    {:noreply, assign(socket, payment: payment)}
  end

  defp define_status_changeset(1), do: "TX_CONFIRMED"
  defp define_status_changeset(_), do: "TX_FAILED"
end
