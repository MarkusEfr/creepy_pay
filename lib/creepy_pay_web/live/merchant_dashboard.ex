defmodule CreepyPayWeb.Live.MerchantDashboard do
  use CreepyPayWeb, :live_view

  alias CreepyPay.{Merchants, StealthPay, Payments}
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
      total_pages: 1
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
      {:ok, %{payment_metacore: metacore, madness_key_hash: _, amount: _, status: _}} ->
        {:ok, payment_invoice} = StealthPay.process_payment(%{payment_metacore: metacore})
        {:noreply, update(socket, :payments, fn payments -> [payment_invoice | payments] end)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Failed to create payment: #{reason}")}
    end
  end

  # Login form if not logged in
  def render(%{merchant: nil} = assigns) do
    ~H"""
    <div class="min-h-screen bg-neutral-950 flex items-center justify-center text-gray-100">
      <div class="bg-zinc-900 border border-zinc-700 p-8 rounded-xl shadow-xl w-full max-w-sm">
        <h1 class="text-2xl font-bold text-emerald-400 mb-6 text-center tracking-wide">☠️ Merchant Login</h1>

        <.form phx-submit="login">
          <input name="identifier" type="text" placeholder="Email or Shitty Name"
            class="w-full mb-4 p-2 rounded bg-zinc-800 border border-zinc-600 text-gray-100" />
          <input name="madness_key" type="password" placeholder="Madness Key (32 bytes)"
            class="w-full mb-4 p-2 rounded bg-zinc-800 border border-zinc-600 text-gray-100" />
          <button type="submit" class="w-full bg-emerald-500 hover:bg-emerald-600 text-white py-2 rounded">
            Enter the Abyss
          </button>
        </.form>

        <%= if @error do %>
          <div class="text-red-500 text-sm mt-4 text-center"><%= @error %></div>
        <% end %>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <% page_payments =
      @payments
      |> Enum.chunk_every(@per_page)
      |> Enum.at(@page - 1, []) %>

    <div class="bg-neutral-950 text-gray-100 h-screen flex flex-col px-8 py-6 overflow-hidden">

      <!-- Header & Form -->
      <div class="flex-shrink-0 mb-4">
        <div class="flex justify-between items-center mb-4">
          <h1 class="text-2xl font-bold tracking-wide text-emerald-400">💀 Merchant Dashboard</h1>
          <span class="text-sm text-gray-400">Welcome, <%= @merchant.shitty_name %></span>
        </div>

        <div class="border border-zinc-700 p-4 rounded-xl bg-zinc-900 shadow-lg">
          <form phx-submit="create_payment">
            <div class="flex items-center gap-4">
              <input name="amount_wei" type="text" placeholder="Amount in Wei"
                class="bg-zinc-800 border border-zinc-700 text-gray-100 p-2 rounded w-full" />
              <button type="submit"
                class="bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded shadow">
                + Create Payment
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Table Container (Fixed height) -->
      <div class="flex-grow overflow-y-auto border border-zinc-800 rounded-xl shadow-inner bg-zinc-900">
        <table class="payment-table w-full text-sm">
          <thead>
            <tr class="bg-zinc-800 text-zinc-400 uppercase text-xs tracking-wide">
              <th class="px-4 py-3 text-left">Metacore</th>
              <th class="px-4 py-3 text-left">Amount (Wei)</th>
              <th class="px-4 py-3 text-left">Madness Key Hash</th>
              <th class="px-4 py-3 text-left">Status</th>
              <th class="px-4 py-3 text-left">Created</th>
            </tr>
          </thead>
          <tbody>
            <%= for payment <- page_payments do %>
              <tr class="border-t border-zinc-800 hover:bg-zinc-800/80">
              <td class="px-4 py-3 text-xs text-zinc-400 break-all font-mono flex items-center gap-2">
              <%= payment.payment_metacore %>
              <button
              id={"copy-link-#{payment.payment_metacore}"}
              phx-hook="CopyLink"
              phx-click="copy_link"
              phx-value-core={payment.payment_metacore}
              title="Copy payment link"
              class="text-rose-500 hover:text-rose-400 transition text-sm">
              🩸
              </button>
              </td>
                <td class="px-4 py-3 text-zinc-100"><%= payment.amount %></td>
                <td class="px-4 py-3 text-xs text-zinc-400 break-all font-mono"><%= payment.madness_key_hash %></td>
                <td class="px-4 py-3">
                  <span class={status_class(payment.status)}>
                    <%= payment.status %>
                  </span>
                </td>
                <td class="px-4 py-3 text-zinc-400 text-xs"><%= payment.inserted_at %></td>
              </tr>
            <% end %>

            <!-- Placeholder rows to prevent jumpy layout -->
            <%= for _ <- 1..(@per_page - length(page_payments)) do %>
              <tr class="border-t border-zinc-800 opacity-30">
                <td class="px-4 py-3">&nbsp;</td>
                <td class="px-4 py-3"></td>
                <td class="px-4 py-3"></td>
                <td class="px-4 py-3"></td>
                <td class="px-4 py-3"></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <!-- Pagination Controls -->
      <div class="flex-shrink-0 mt-4 text-sm text-gray-400 flex justify-between items-center">
        <button
          phx-click="change_page"
          phx-value-dir="prev"
          class="px-3 py-1 bg-zinc-800 hover:bg-zinc-700 rounded disabled:opacity-30"
          disabled={@page == 1}>
          ◀ Prev
        </button>

        <span>Page <%= @page %> of <%= @total_pages %></span>

        <button
          phx-click="change_page"
          phx-value-dir="next"
          class="px-3 py-1 bg-zinc-800 hover:bg-zinc-700 rounded disabled:opacity-30"
          disabled={@page == @total_pages}>
          Next ▶
        </button>
      </div>
    </div>
    """
  end

  defp status_class("TX_CONFIRMED"), do: "confirmed"
  defp status_class("TX_FAILED"), do: "failed"
  defp status_class(_), do: "pending"
end
