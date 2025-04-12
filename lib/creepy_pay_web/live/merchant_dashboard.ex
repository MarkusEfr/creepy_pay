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
      {:ok, %{payment_metacore: metacore}} ->
        {:ok, payment_invoice} = StealthPay.process_payment(%{payment_metacore: metacore})
        {:noreply, update(socket, :payments, fn payments -> [payment_invoice | payments] end)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Failed to create payment: #{reason}")}
    end
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

  defp status_class("TX_CONFIRMED"), do: "text-green-600 font-semibold"
  defp status_class("TX_FAILED"), do: "text-red-500 font-semibold"
  defp status_class(_), do: "text-yellow-500 font-semibold"
end
