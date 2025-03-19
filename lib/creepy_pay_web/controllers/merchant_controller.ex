defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller

  alias CreepyPay.{Auth.Guardian, Merchants}

  require Logger

  @doc """
  Registers a merchant with madness_key.

  ## Parameters

  - `shitty_name`: A string of length 3-20
  - `email`: A string following the regular expression
    `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$`
  - `madness_key`: A string of length 32

  ## Returns

  - `{:ok, t()}` if registration is successful
  - `{:error, binary()}` if registration fails with an error message
  - `{:error, Ecto.Changeset.t()}` if registration fails with a changeset
  """
  def register(
        conn,
        %{
          "shitty_name" => _shitty_name,
          "email" => _email,
          "madness_key" => _madness_key
        } = params
      ) do
    case Merchants.register_merchant(params) do
      {:ok, merchant} ->
        json(conn, %{status: "success", merchant: merchant})

      {:error, reason} ->
        json(conn, %{status: "failed", reason: reason})
    end
  end

  @doc "Merchant login and JWT generation"
  def login(conn, %{"identifier" => identifier, "madness_key" => madness_key}) do
    with {:ok, merchant} <-
           Merchants.authenticate_merchant(identifier, madness_key),
         {:ok, token, _claims} <-
           Guardian.encode_and_sign(merchant) |> IO.inspect(label: "[DEBUG] Token") do
      json(conn, %{token: token, merchant: merchant})
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
