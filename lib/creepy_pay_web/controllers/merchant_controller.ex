defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller
  alias CreepyPay.Merchants

  @doc "Registers a new merchant"
  def register(conn, %{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    case Merchants.register_merchant(%{
           "shitty_name" => shitty_name,
           "email" => email,
           "madness_key" => madness_key
         }) do
      {:ok, merchant} ->
        json(conn, %{
          merchant_gem: merchant.merchant_gem,
          shitty_name: merchant.shitty_name,
          email: merchant.email,
          madness_key: merchant.madness_key
        })

      {:error, changeset} ->
        json(conn, %{error: "Merchant registration failed", reason: changeset})
    end
  end
end
