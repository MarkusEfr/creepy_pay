defmodule CreepyPay.Merchants do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias CreepyPay.Repo
  alias Faker, as: GemChunk
  require Logger

  @gem_len 32
  @aes_vector <<2::128>>

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:shitty_name, :email, :inserted_at, :merchant_gem_crypton]}
  schema "merchants" do
    field(:merchant_gem_crypton, :binary)
    field(:shitty_name, :string)
    field(:email, :string)
    field(:madness_key_hash, :string)
    timestamps()
  end

  @doc "Changeset for merchant creation"
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
  Registers a merchant with custom encrypted madness_key and encrypted gem string.
  """
  def register_merchant(%{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    gem_string = resolve_gem_crypton()

    gem_cipher = :crypto.crypto_init(:aes_256_ctr, madness_key, @aes_vector, true)
    gem_encrypted = :crypto.crypto_update(gem_cipher, gem_string)

    key_cipher = :crypto.crypto_init(:aes_256_ctr, madness_key, @aes_vector, true)
    madness_key_encrypted = :crypto.crypto_update(key_cipher, madness_key)

    merchant = %{
      merchant_gem_crypton: gem_encrypted,
      shitty_name: shitty_name,
      email: email,
      madness_key_hash: Base.encode64(madness_key_encrypted)
    }

    case changeset(%__MODULE__{}, merchant) |> Repo.insert() do
      {:ok, merchant} ->
        {:ok,
         %{
           merchant: merchant |> Map.put(:merchant_gem_crypton, gem_string)
         }}

      {:error, changeset} ->
        {:error, changeset.errors |> Enum.map(fn {k, {v, _}} -> "#{k}: #{v}" end)}
    end
  end

  @doc """
  Authenticates a merchant using custom encrypted madness_key.
  """
  def authenticate_merchant(identifier, madness_key) do
    if byte_size(madness_key) != 32 do
      {:error, "madness_key must be exactly 32 bytes"}
    else
      query =
        from(m in __MODULE__,
          where:
            m.email == ^identifier or m.shitty_name == ^identifier or
              m.merchant_gem_crypton == ^identifier
        )

      case Repo.one(query) do
        %__MODULE__{madness_key_hash: encoded_hash} = merchant ->
          cipher = :crypto.crypto_init(:aes_256_ctr, madness_key, @aes_vector, true)
          encrypted = :crypto.crypto_update(cipher, madness_key)

          if Base.encode64(encrypted) == encoded_hash do
            {:ok, merchant_gem_decrypted} = decrypt_merchant_gem(merchant, madness_key)
            {:ok, %{merchant | merchant_gem_crypton: merchant_gem_decrypted}}
          else
            {:error, "Invalid credentials"}
          end

        nil ->
          {:error, "Merchant not found"}
      end
    end
  end

  @doc "Generates a random merchant_gem_crypton string"
  def resolve_gem_crypton do
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

  @doc """
  Decrypts a merchant's encrypted gem_crypton using their madness_key.
  """
  def decrypt_merchant_gem(%__MODULE__{merchant_gem_crypton: crypton}, madness_key)
      when is_binary(crypton) and is_binary(madness_key) do
    if byte_size(madness_key) != 32 do
      {:error, "madness_key must be exactly 32 bytes"}
    else
      cipher = :crypto.crypto_init(:aes_256_ctr, madness_key, @aes_vector, true)
      decrypted = :crypto.crypto_update(cipher, crypton)
      {:ok, decrypted}
    end
  end
end
