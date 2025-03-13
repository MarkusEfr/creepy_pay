defmodule CreepyPayWeb.MerchantController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Auth.Guardian, Repo, Merchants}
  alias Argon2

  require Logger

  def register_merchant(conn, %{
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

      state = :crypto.crypto_init(:aes_256_ecb, madness_key_bin, vector, true)
      encrypted = :crypto.crypto_update(state, gem_combined)
      gem_crypton = :crypto.crypto_final(state) <> encrypted

      merchant = %Merchants{
        merchant_gem_crypton: gem_crypton,
        shitty_name: shitty_name,
        email: email,
        madness_key_hash: madness_key_hash
      }

      Logger.debug("[DEBUG] Registering merchant: #{email} (#{shitty_name})")

      try do
        case Repo.insert(merchant) do
          {:ok, merchant} ->
            json(conn, %{status: "success", merchant: merchant})

          {:error, changeset} ->
            Logger.warning("[WARN] Merchant insert failed: #{inspect(changeset)}")
            conn |> put_status(422) |> json(%{status: "failed", error: inspect(changeset)})
        end
      rescue
        e ->
          Logger.error("[ERROR] Merchant registration exception: #{inspect(e)}")
          conn |> put_status(500) |> json(%{error: "Unexpected error occurred"})
      end
    else
      Logger.warning("[WARN] Invalid key or gem size")

      conn
      |> put_status(400)
      |> json(%{error: "Invalid gem or madness_key length"})
    end
  end

  @doc "Merchant login and JWT generation"
  def login(conn, %{"identifier" => identifier, "madness_key" => madness_key}) do
    with {:ok, merchant} <- Merchants.authenticate_merchant(identifier, madness_key),
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
