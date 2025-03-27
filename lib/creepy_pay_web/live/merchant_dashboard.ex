defmodule CreepyPayWeb.Live.MerchantDashboard do
  use CreepyPayWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, payments: [])}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-neutral-950 min-h-screen text-gray-100 p-8">
    <h1 class="text-2xl font-bold tracking-wide text-emerald-400 mb-6">💀 Merchant Dashboard</h1>

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

    <div class="overflow-x-auto border border-zinc-700 rounded-xl">
    <table class="min-w-full bg-zinc-900 text-left text-sm">
      <thead class="text-gray-400 uppercase border-b border-zinc-700">
        <tr>
          <th class="px-4 py-3">Metacore</th>
          <th class="px-4 py-3">Amount (Wei)</th>
          <th class="px-4 py-3">Madness Key Hash</th>
          <th class="px-4 py-3">Status</th>
          <th class="px-4 py-3">Created</th>
        </tr>
      </thead>
      <tbody>
        <%= for p <- @payments do %>
          <tr class="hover:bg-zinc-800 transition">
            <td class="px-4 py-2 font-mono"><%= p.payment_metacore %></td>
            <td class="px-4 py-2"><%= p.amount %></td>
            <td class="px-4 py-2 text-xs break-all"><%= p.madness_key_hash %></td>
            <td class="px-4 py-2"><%= p.status %></td>
            <td class="px-4 py-2"><%= p.inserted_at %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    </div>
    </div>
    """
  end
end
