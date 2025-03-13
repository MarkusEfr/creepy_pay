defmodule CreepyPay.Merchants do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_status: 2]

  alias CreepyPay.Repo
  alias Faker, as: GemChunk
  require Logger

  @gem_len 32

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder,
           only: [
             :shitty_name,
             :email,
             :inserted_at
           ]}
  schema "merchants" do
    field(:merchant_gem_crypton, :binary)
    field(:shitty_name, :string)
    field(:email, :string)
    field(:madness_key_hash, :string)
    timestamps()
  end

  @doc "Merchant changeset"
  def changeset(merchant, attrs) do
    merchant
    |> cast(attrs, [:merchant_gem_crypton, :shitty_name, :email, :madness_key_hash])
    |> validate_required([:merchant_gem_crypton, :shitty_name, :email, :madness_key_hash])
    |> validate_length(:shitty_name, min: 3, max: 20)
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    |> unique_constraint(:merchant_gem_crypton)
    |> unique_constraint(:email)
  end

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
  def register_merchant(conn, %{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    gem_string = resolve_gem_crypton()
    gem_combined = gem_string <> madness_key

    if byte_size(gem_combined) >= 64 do
      <<_gem_part::binary-size(32), madness_key_bin::binary-size(32), _::binary>> = gem_combined
      vector = <<2::128>>
      madness_key_hash = Argon2.hash_pwd_salt(madness_key_bin)

      state_encryption = :crypto.crypto_init(:aes_128_ctr, madness_key_bin, vector, true)
      gem_crypton = :crypto.crypto_update(state_encryption, gem_combined)
      :crypto.crypto_update(state_encryption, gem_crypton)

      merchant = %__MODULE__{
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

  def authenticate_merchant(identifier, madness_key) do
    query =
      from(m in __MODULE__,
        where:
          m.email == ^identifier or m.shitty_name == ^identifier or
            m.merchant_gem_crypton == ^identifier
      )

    with %__MODULE__{} = merchant <- Repo.one(query),
         true <- Argon2.verify_pass(madness_key, merchant.madness_key_hash) do
      {:ok, merchant}
    else
      reason -> {:error, inspect(reason)}
    end
  end

  def resolve_gem_crypton,
    do:
      [
        GemChunk.Cat.name(),
        GemChunk.Food.dish(),
        GemChunk.Pizza.style(),
        GemChunk.Pokemon.name(),
        GemChunk.Superhero.name(),
        GemChunk.StarWars.character()
      ]
      |> Enum.shuffle()
      |> Enum.map(&String.replace(&1, ~r/[^a-zA-Z0-9]/, ""))
      |> Enum.map_join(&String.slice(&1, 0..@gem_len))
end
