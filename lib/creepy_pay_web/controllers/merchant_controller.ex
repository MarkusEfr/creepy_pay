defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Repo, Merchants, Auth.Guardian}
  alias Argon2

  require Logger

  def register_merchant(conn, %{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    Logger.info("Registering merchant", email: email, shitty_name: shitty_name)

    gem_string = Merchants.resolve_gem_crypton()
    gem_combined = gem_string <> madness_key

    if byte_size(gem_combined) >= 64 do
      <<_gem_part::binary-size(32), madness_key_bin::binary-size(32), _::binary>> = gem_combined
      vector = <<2::128>>
      madness_key_hash = Argon2.hash_pwd_salt(madness_key_bin)

      state_encryption = :crypto.crypto_init(:aes_128_ctr, madness_key_bin, vector, true)
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
          json(conn, %{merchant: merchant})

        {:error, reason} ->
          conn |> put_status(422) |> json(%{error: inspect(reason)})
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
         Logger.info("Merchant authenticated", merchant: merchant),
         {:ok, token, _claims} <-
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
