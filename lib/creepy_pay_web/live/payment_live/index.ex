defmodule CreepyPayWeb.PaymentLive.Index do
  use CreepyPayWeb, :live_view

  alias CreepyPay.Payments

  @impl true
  def mount(params, _session, socket) do
    {:ok, payment} = Payments.get_payment(params["payment_metacore"])
    {:ok, socket |> assign(payment: payment)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="p-6 max-w-2xl mx-auto bg-white rounded shadow-md">
      <h1 class="text-2xl font-bold text-center text-gray-800 mb-6">Payment Request</h1>

      <div class="space-y-4">
        <div>
          <p class="text-gray-600 text-sm">Payment ID</p>
          <p class="font-mono text-lg text-gray-900"><%= @payment.payment_metacore %></p>
        </div>

        <div>
          <p class="text-gray-600 text-sm">Amount (in wei)</p>
          <p class="text-xl font-semibold text-green-700"><%= @payment.amount %></p>
        </div>

        <div>
          <p class="text-gray-600 text-sm">Stealth Address</p>
          <p class="font-mono text-gray-900"><%= @payment.stealth_address %></p>
        </div>

        <div>
          <p class="text-gray-600 text-sm">Status</p>
          <p class={"text-md font-medium #{status_color(@payment.status)}"}><%= @payment.status %></p>
        </div>

        <div :if={Map.has_key?(@payment, :qr_code)} class="text-center mt-6">
          <img src={"data:image/png;base64,#{@qr_code}"} alt="QR Code" class="mx-auto border p-2 bg-white shadow-md rounded" />
          <p class="text-sm text-gray-500 mt-2">Scan to pay via wallet</p>
        </div>

        <div :if={Map.has_key?(@payment, :eth_payment_link)} class="text-center mt-4">
          <a href={@eth_payment_link} target="_blank" class="inline-block px-6 py-2 bg-green-700 hover:bg-green-800 text-white rounded transition">
            Open in Wallet
          </a>
        </div>
      </div>
    </main>
    """
  end

  defp status_color("completed"), do: "text-green-600"
  defp status_color("pending"), do: "text-yellow-600"
  defp status_color("failed"), do: "text-red-600"
  defp status_color(_), do: "text-gray-600"
end
