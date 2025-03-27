defmodule CreepyPayWeb.Live.MerchantDashboard do
  use CreepyPayWeb, :live_view

  alias CreepyPay.{Merchants, StealthPay, Payments}
  require Logger

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       madness_key: nil,
       madness_key_hash: nil,
       merchant: nil,
       payments: [],
       error: nil
     )}
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
      {:ok, %{payment_metacore: _, madness_key_hash: _, amount: _, status: _} = p} ->
        {:noreply, update(socket, :payments, fn payments -> [p | payments] end)}

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

  # Main dashboard
  def render(%{merchant: merchant} = assigns) do
    ~H"""
    <div class="bg-neutral-950 min-h-screen text-gray-100 p-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-2xl font-bold tracking-wide text-emerald-400">
          💀 Merchant Dashboard
        </h1>
        <span class="text-sm text-gray-400">Welcome, <%= merchant.shitty_name %></span>
      </div>

      <div class="mb-6 border border-zinc-700 p-4 rounded-xl bg-zinc-900 shadow-lg">
        <form phx-submit="create_payment">
          <div class="flex items-center gap-4">
            <input name="amount_wei" type="text" placeholder="Amount in Wei"
              class="bg-zinc-800 border border-zinc-700 text-gray-100 p-2 rounded w-full" />
            <button type="submit" class="bg-emerald-500 hover:bg-emerald-600 text-white px-4 py-2 rounded shadow">
              + Create Payment
            </button>
          </div>
        </form>
      </div>

      <div class="table-container">
    <table class="payment-table">
    <thead>
      <tr>
        <th>Metacore</th>
        <th>Amount (Wei)</th>
        <th>Madness Key Hash</th>
        <th>Status</th>
        <th>Created</th>
      </tr>
    </thead>
    <tbody>
      <tr :for={payment <- @payments} class="payment-row">
        <td class="mono"><%= payment.payment_metacore %></td>
        <td><%= payment.amount %></td>
        <td class="hash"><%= payment.madness_key_hash %></td>
        <td><span class={status_class(payment.status)}><%= payment.status %></span></td>
        <td>2025-03-27 14:32</td>
      </tr>
    </tbody>
    </table>
    </div>
    </div>
    """
  end

  defp status_class("TX_CONFIRMED"), do: "confirmed"
  defp status_class("TX_FAILED"), do: "failed"
  defp status_class(_), do: "pending"
end
