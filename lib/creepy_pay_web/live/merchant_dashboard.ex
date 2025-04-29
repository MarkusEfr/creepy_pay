defmodule CreepyPayWeb.Live.MerchantDashboard do
  use CreepyPayWeb, :live_view

  alias CreepyPay.{Merchants, Payments, StealthPay}
  require Logger

  def mount(_params, _session, socket) do
    case get_connect_params(socket) do
      %{"merchant_id" => id} ->
        with {:ok, merchant} <- Merchants.get_merchant_by_id(id) do
          hash = merchant.madness_key_hash
          payments = Payments.list_by_madness_key_hash(hash)

          {:ok,
           assign(socket,
             merchant: merchant,
             madness_key_hash: hash,
             payments: payments,
             page: 1,
             per_page: 10,
             total_pages: ceil(length(payments) / 10),
             error: nil
           )}
        else
          _ -> {:ok, assign_default(socket)}
        end

      _ ->
        {:ok, assign_default(socket)}
    end
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
      expanded_payment_metacore: nil
    )
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
        hash = merchant.madness_key_hash
        payments = CreepyPay.Payments.list_by_madness_key_hash(hash)

        {:noreply,
         socket
         |> assign(:madness_key, key)
         |> assign(:madness_key_hash, hash)
         |> assign(:merchant, merchant)
         |> assign(:payments, payments)
         |> assign(:total_pages, ceil(length(payments) / socket.assigns.per_page))
         |> assign(:error, nil)}

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
    new_expanded =
      if socket.assigns.expanded_payment_metacore == core do
        nil
      else
        core
      end

    {:noreply, assign(socket, :expanded_payment_metacore, new_expanded)}
  end

  def render(%{merchant: nil} = assigns) do
    ~H"""
    <div class="cp-login-wrapper">
      <h1 class="cp-login-title">Merchant Login</h1>

      <form class="cp-login-form" phx-submit="login">
        <input name="identifier" type="text" placeholder="Email or Shitty Name" />
        <input name="madness_key" type="password" placeholder="Madness Key (32 bytes)" />
        <button type="submit" class="cp-login-submit">Enter the Abyss</button>
      </form>

      <%= if @error do %>
        <div class="cp-login-error"><%= @error %></div>
      <% end %>
    </div>
    """
  end

  def render(%{merchant: merchant} = assigns) do
    ~H"""
    <div class="cp-dashboard-wrapper">

      <header class="cp-dashboard-header">
        <h1 class="cp-dashboard-title">Merchant Dashboard</h1>
        <div class="cp-dashboard-metadata">
          <strong>Name:</strong> <%= merchant.shitty_name %><br/>
          <strong>Email:</strong> <%= merchant.email %><br/>
          <strong>Merchant ID:</strong> <%= merchant.id %>
        </div>
      </header>

      <section>
        <h2 class="cp-section-title">Create a New Payment</h2>
        <form phx-submit="create_payment" class="cp-create-payment-form cp-login-form">
          <input name="amount_wei" type="text" placeholder="Amount in Wei" />
          <button type="submit" class="cp-btn" style="margin-top: 1rem;">Create Payment</button>
        </form>
      </section>

      <section>
        <h2 class="cp-section-title">Your Payments</h2>

        <%= if @payments == [] do %>
          <div class="cp-subtext" style="margin-top: 1rem;">No payments yet. Start by creating one!</div>
        <% else %>
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
                        phx-click="toggle_payment"
                        phx-value-core={p.payment_metacore}
                        class="cp-btn"
                        style="padding: 0.4rem 0.9rem; font-size: 0.85rem;">
                        <%= if @expanded_payment_metacore == p.payment_metacore do %>🔼 Hide<% else %>🔽 Show<% end %>
                      </button>
                    </td>
                  </tr>

                  <%= if @expanded_payment_metacore == p.payment_metacore do %>
                    <tr>
                      <td colspan="4">
                        <div class="cp-expand-details">

                          <div><strong>Core:</strong> <%= p.payment_metacore %></div>
                          <div><strong>Amount:</strong> <%= p.amount %> wei</div>
                          <div><strong>Status:</strong> <%= p.status %></div>
                          <div><strong>Created At:</strong> <%= p.inserted_at %></div>

                          <%= if p.invoice_details["link"] do %>
                            <div style="margin-top: 1rem;">
                              <strong>Invoice Link:</strong><br/>
                              <a href={"#{p.invoice_details["link"]}"} target="_blank" style="color: #008060;">
                                <%= p.invoice_details["link"] %>
                              </a>
                            </div>
                          <% end %>

                          <%= if p.invoice_details["deeplinks"] do %>
                            <div style="margin-top: 1rem;">
                              <strong>Wallet Links:</strong><br/>
                              <a href={"#{p.invoice_details["deeplinks"]["metamask"]}"} target="_blank" style="margin-right: 1rem; color: #005c40;">
                                Metamask
                              </a>
                              <a href={"#{p.invoice_details["deeplinks"]["trustwallet"]}"} target="_blank" style="color: #005c40;">
                                TrustWallet
                              </a>
                            </div>
                          <% end %>

                          <%= if p.invoice_details["data"] do %>
                            <div style="margin-top: 1rem;">
                              <strong>Call Data:</strong><br/>
                              <code style="word-break: break-all; font-size: 0.85rem;">
                                <%= p.invoice_details["data"] %>
                              </code>
                            </div>
                          <% end %>

                          <%= if p.invoice_details["qr_code"] do %>
                            <div class="cp-expand-qr">
                              <img src={"#{p.invoice_details["qr_code"]}"} alt="QR Code" />
                            </div>
                          <% end %>

                        </div>
                      </td>
                    </tr>
                  <% end %>

                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>

      <footer class="cp-footer-note" style="margin-top: 4rem;">CreepyPay Merchant Control Center</footer>

    </div>
    """
  end
end
