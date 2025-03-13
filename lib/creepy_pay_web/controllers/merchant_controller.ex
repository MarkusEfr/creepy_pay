defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller

  alias Argon2
  alias CreepyPay.{Auth.Guardian, Merchants, Repo}

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
  def register(conn, %{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    gem_string = Merchants.resolve_gem_crypton()
    gem_combined = gem_string <> madness_key

    if byte_size(gem_combined) >= 64 do
      <<_gem_part::binary-size(32), madness_key_bin::binary-size(32), _::binary>> = gem_combined
      vector = <<2::128>>
      madness_key_hash = Argon2.hash_pwd_salt(madness_key_bin)

      state_encryption = :crypto.crypto_init(:aes_256_ecb, madness_key_bin, vector, true)
      gem_crypton = :crypto.crypto_update(state_encryption, gem_combined)
      :crypto.crypto_update(state_encryption, gem_crypton)

      merchant = %Merchants{
        merchant_gem_crypton: gem_crypton,
        shitty_name: shitty_name,
        email: email,
        madness_key_hash: madness_key_hash
      }

      case Repo.insert(merchant) do
        {:ok, merchant} ->
          json(conn, %{status: "success", merchant: merchant})

        {:error, %Ecto.Changeset{} = changeset} ->
          json(conn, %{status: "failed", error: inspect(changeset.errors)})

        {:error, reason} ->
          json(conn, %{status: "failed", error: inspect(reason)})
      end
    else
      conn
      |> put_status(400)
      |> json(%{error: "Invalid gem or madness_key length"})
    end
  end

  @doc "Merchant login and JWT generation"
  def login(conn, %{"identifier" => identifier, "madness_key" => madness_key}) do
    with {:ok, merchant} <- Merchants.authenticate_merchant(identifier, madness_key),
         {:ok, token, claims} <-
           Guardian.encode_and_sign(merchant) |> IO.inspect(label: "[DEBUG] Token") do
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
