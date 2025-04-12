defmodule CreepyPayWeb.Live.Payment do
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments
  alias CreepyPay.StealthPay

  def mount(%{"payment_metacore" => payment_metacore}, _session, socket) do
    case Payments.get_payment(payment_metacore) do
      {:ok, payment} ->
        IO.inspect(payment, label: "Payment")

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
    <div class="cp-invoice-wrapper not-found">
    <div class="cp-header">
    <img src="/images/icons/warning_cat.png" alt="Warning Cat" class="cp-icon-warning" />
    <h1 class="cp-title danger">404: Invoice Vanished</h1>
    </div>
    <p class="cp-subtext">This invoice was either devoured by the void or never born.</p>
    <a href="/" class="cp-btn">Return to Safety</a>
    </div>

    <% else %>
      <div class="cp-invoice-wrapper">
        <h1 class="cp-title">Payment Order</h1>

        <div class="cp-metadata">
          Invoice No.: <%= @payment.payment_metacore %><br/>
          Issued Date: <%= Date.utc_today() |> to_string() %>
        </div>

        <div class="cp-section-title">Payment Summary</div>

        <div class="cp-info-row">
          <label>Amount</label>
          <div class="value"><%= @payment.amount %> wei</div>
        </div>

        <div class="cp-info-row">
          <label>Madness Key Hash</label>
          <div class="value"><%= @payment.madness_key_hash %></div>
        </div>

        <div class="cp-info-row">
          <label>Status</label>
          <div class={"value cp-status cp-status-#{String.downcase(@payment.status)}"}>
            <%= @payment.status %>
          </div>
        </div>

        <%= if @payment.invoice_details["receipt"] do %>
          <div class="cp-section-title">Ethereum Receipt</div>

          <div class="cp-info-row">
            <label>Tx Hash</label>
            <div class="value"><%= @payment.invoice_details["receipt"]["hash"] %></div>
          </div>

          <div class="cp-info-row">
            <label>Block Number</label>
            <div class="value"><%= @payment.invoice_details["receipt"]["blockNumber"] %></div>
          </div>

          <div class="cp-info-row">
            <label>From</label>
            <div class="value"><%= @payment.invoice_details["receipt"]["from"] %></div>
          </div>

          <div class="cp-info-row">
            <label>To</label>
            <div class="value"><%= @payment.invoice_details["receipt"]["to"] %></div>
          </div>

          <div class="cp-info-row">
            <label>Gas Used</label>
            <div class="value"><%= @payment.invoice_details["receipt"]["gasUsed"] %></div>
          </div>
        <% end %>

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

        <div class="cp-footer-note">
          ⬤ This invoice is issued by CreepyPay Corp, verified via on-chain meta.
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("tx_failed", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, :tx_error, reason)}
  end

  def handle_event(
        "tx_sent",
        %{"receipt" => %{"hash" => _tx_hash, "status" => status} = receipt},
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
