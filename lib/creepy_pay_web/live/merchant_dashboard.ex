defmodule CreepyPayWeb.Live.MerchantDashboard do
  use CreepyPayWeb, :live_view
  alias CreepyPay.{Auth.Guardian, Merchants, Payments, StealthPay}
  require Logger

  def mount(_params, _session, socket) do
    {:ok, assign_default(socket)}
  end

  defp assign_default(socket) do
    assign(socket,
      merchant: nil,
      madness_key: nil,
      madness_key_hash: nil,
      payments: [],
      error: nil,
      page: 1,
      per_page: 10,
      total_pages: 1,
      expanded_payment_metacore: nil,
      show_modal: false,
      active_payment: nil
    )
  end

  def handle_event("show_payment", %{"core" => core}, socket) do
    case Enum.find(socket.assigns.payments, fn p -> p.payment_metacore == core end) do
      nil ->
        {:noreply, assign(socket, show_modal: false, active_payment: nil)}

      payment ->
        {:noreply, assign(socket, show_modal: true, active_payment: payment)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, active_payment: nil)}
  end

  def handle_event("auth_merchant_with_token", %{"token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:ok, merchant, _claims} ->
        hash = merchant.madness_key_hash
        payments = Payments.list_by_madness_key_hash(hash)

        {:noreply,
         socket
         |> assign(:merchant, merchant)
         |> assign(:madness_key_hash, hash)
         |> assign(:payments, payments)
         |> assign(:total_pages, ceil(length(payments) / socket.assigns.per_page))
         |> assign(:error, nil)}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Invalid or expired token")}
    end
  end

  def handle_event("copy_link", %{"core" => core}, socket) do
    Logger.info("Merchant copied payment link for: #{core}")
    {:noreply, socket}
  end

  def handle_event("change_page", %{"dir" => dir}, socket) do
    current = socket.assigns.page
    total = socket.assigns.total_pages

    new_page =
      case dir do
        "next" -> min(current + 1, total)
        "prev" -> max(current - 1, 1)
        _ -> current
      end

    {:noreply, assign(socket, :page, new_page)}
  end

  def handle_event("login", %{"identifier" => identifier, "madness_key" => key}, socket) do
    case Merchants.authenticate_merchant(identifier, key) do
      {:ok, merchant} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(merchant)

        {:noreply,
         push_event(socket, "merchant_login_success", %{
           token: token
         })}

      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end

  def handle_event(
        "create_payment",
        %{"amount_wei" => amount},
        %{assigns: %{madness_key_hash: hash}} = socket
      ) do
    case StealthPay.generate_payment_request(%{amount: amount, madness_key_hash: hash}) do
      {:ok, %{payment_metacore: metacore}} ->
        {:ok, payment_invoice} = StealthPay.process_payment(%{payment_metacore: metacore})
        {:noreply, update(socket, :payments, fn payments -> [payment_invoice | payments] end)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Failed to create payment: #{reason}")}
    end
  end

  def handle_event("toggle_payment", %{"core" => core}, socket) do
    new_expanded = if socket.assigns.expanded_payment_metacore == core, do: nil, else: core
    {:noreply, assign(socket, :expanded_payment_metacore, new_expanded)}
  end

  def render(%{merchant: nil} = assigns) do
    ~H"""
    <div id="merchant-dashboard" class="cp-login-wrapper" phx-hook="MerchantAuth">
      <h1 class="cp-login-title">Merchant Login</h1>

      <form class="cp-login-form" phx-submit="login">
        <input name="identifier" type="text" placeholder="Email or Shitty Name" />
        <input name="madness_key" type="password" placeholder="Madness Key (32 bytes)" />
        <button type="submit" class="cp-login-submit">Enter Dashboard</button>
      </form>

      <%= if @error do %>
        <div class="cp-login-error"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  def render(%{merchant: _merchant} = assigns) do
    ~H"""
    <div id="merchant-dashboard" class="cp-dashboard-wrapper" phx-hook="MerchantAuth">
      <!-- Keep phx-hook in case of reconnection -->

      <header class="cp-dashboard-header">
        <h1 class="cp-dashboard-title">Merchant Dashboard</h1>
        <div class="cp-dashboard-metadata">
        <div style="margin-top: 1rem;">
          <button id="merchant-logout" class="cp-btn danger">🚪 Logout</button>
        </div>
          <strong>Name:</strong> <%= @merchant.shitty_name %><br/>
          <strong>Email:</strong> <%= @merchant.email %><br/>
          <strong>Merchant ID:</strong> <%= @merchant.id %>
        </div>
      </header>

      <section>
        <h2 class="cp-section-title">Create a New Payment</h2>
        <form phx-submit="create_payment" class="cp-create-payment-form cp-login-form">
          <input name="amount_wei" type="text" placeholder="Amount in Wei" />
          <button type="submit" class="cp-btn" style="margin-top: 1rem;">Create Payment</button>
        </form>
      </section>

      <%= render_payments(assigns) %>

      <footer class="cp-footer-note" style="margin-top: 4rem;">
        CreepyPay Merchant Control Center
      </footer>
    </div>
    """
  end

  defp render_payments(%{payments: [], assigns: assigns}) do
    ~H"""
    <section>
      <h2 class="cp-section-title">Your Payments</h2>
      <div class="cp-subtext" style="margin-top: 1rem;">No payments yet. Start by creating one!</div>
    </section>
    """
  end

  defp render_payments(assigns) do
    ~H"""
    <section>
      <h2 class="cp-section-title">Your Payments</h2>

      <div class="cp-payments-table-wrapper">
        <table class="cp-payments-table">
          <thead>
            <tr>
              <th>Payment Core</th>
              <th style="text-align: right;">Amount (Wei)</th>
              <th style="text-align: center;">Status</th>
              <th style="text-align: center;">Details</th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- Enum.take(@payments, 10) do %>
              <tr>
                <td><%= p.payment_metacore %></td>
                <td style="text-align: right;"><%= p.amount %></td>
                <td style="text-align: center; color: #008060;"><%= p.status %></td>
                <td style="text-align: center;">
                <button
                phx-click="show_payment"
                phx-value-core={p.payment_metacore}
                class="cp-btn"
                style="padding: 0.4rem 0.9rem; font-size: 0.85rem;">
                🔍 View
                </button>

                </td>
              </tr>

              <%= if @show_modal && @active_payment do %>
              <div class="cp-modal-backdrop" phx-click="close_modal">
                <div class="cp-modal" phx-click-stop>
                  <h3 class="cp-modal-title">Payment Details</h3>
                  <div class="cp-modal-content">
                    <div><strong>Core:</strong> <%= @active_payment.payment_metacore %></div>
                    <div><strong>Amount:</strong> <%= @active_payment.amount %> wei</div>
                    <div><strong>Status:</strong> <%= @active_payment.status %></div>
                    <div><strong>Created At:</strong> <%= @active_payment.inserted_at %></div>

                    <%= if @active_payment.invoice_details["link"] do %>
                      <div style="margin-top: 1rem;">
                        <strong>Invoice Link:</strong><br/>
                        <a href={"#{@active_payment.invoice_details["link"]}"} target="_blank" style="color: #008060;">
                          <%= @active_payment.invoice_details["link"] %>
                        </a>
                      </div>
                    <% end %>

                    <%= if @active_payment.invoice_details["deeplinks"] do %>
                      <div style="margin-top: 1rem;">
                        <strong>Wallet Links:</strong><br/>
                        <a href={"#{@active_payment.invoice_details["deeplinks"]["metamask"]}"} target="_blank" style="margin-right: 1rem; color: #005c40;">
                          Metamask
                        </a>
                        <a href={"#{@active_payment.invoice_details["deeplinks"]["trustwallet"]}"} target="_blank" style="color: #005c40;">
                          TrustWallet
                        </a>
                      </div>
                    <% end %>

                    <%= if @active_payment.invoice_details["data"] do %>
                      <div style="margin-top: 1rem;">
                        <strong>Call Data:</strong><br/>
                        <code style="word-break: break-all; font-size: 0.85rem;">
                          <%= @active_payment.invoice_details["data"] %>
                        </code>
                      </div>
                    <% end %>

                    <%= if @active_payment.invoice_details["qr_code"] do %>
                      <div class="cp-expand-qr">
                        <img src={"#{@active_payment.invoice_details["qr_code"]}"} alt="QR Code" />
                      </div>
                    <% end %>
                  </div>

                  <button phx-click="close_modal" class="cp-btn" style="margin-top: 1.5rem;">Close</button>
                </div>
              </div>
            <% end %>

            <% end %>
          </tbody>
        </table>
      </div>
    </section>
    """
  end
end
