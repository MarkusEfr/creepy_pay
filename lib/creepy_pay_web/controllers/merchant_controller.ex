defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Merchants, Auth.Guardian}
  alias Argon2

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
      {:error, %Ecto.Changeset{errors: errors}} ->
        json(conn, %{error: "Merchant registration failed", reason: "#{inspect(errors)}"})

      {:ok, merchant} ->
        json(conn, merchant)
    end
  end

  @doc "Merchant login and JWT generation"
  def login(conn, %{"identifier" => identifier, "madness_key" => madness_key}) do
    with {:ok, merchant} <- Merchants.authenticate_merchant(identifier, madness_key),
         {:ok, token, _claims} <- Guardian.encode_and_sign(merchant) do
      json(conn, %{token: token, merchant_gem: merchant.merchant_gem})
    else
      {:error, _} -> json(conn, %{error: "Invalid credentials"})
    end
  end

  @doc "Retrieves current authenticated merchant"
  def me(conn, _params) do
    merchant = Guardian.Plug.current_resource(conn)
    json(conn, %{merchant: merchant})
  end
end
