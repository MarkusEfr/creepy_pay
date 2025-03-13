defmodule CreepyPay.Merchants do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias CreepyPay.Repo
  alias Argon2

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

  @doc "Registers a merchant with madness_key"
  def register_merchant(%{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    gem = resolve_gem_crypton() <> madness_key

    with <<^gem::binary-size(32), madness_key_bin::binary-size(32)>> = <<2::128>> <> gem,
         {vector, madness_key_hash} <- {<<2::128>>, Argon2.hash_pwd_salt(madness_key_bin)},
         state_encryption = :crypto.crypto_init(:aes_128_ctr, madness_key_bin, vector, true),
         gem_crypton = generate_merchant_gem(),
         :crypto.crypto_update(state_encryption, gem_crypton),
         merchant <- %__MODULE__{
           merchant_gem_crypton: gem_crypton,
           shitty_name: shitty_name,
           email: email,
           madness_key_hash: madness_key_hash
         },
         {:ok, merchant} <- Repo.insert(merchant) do
      {:ok, merchant}
    else
      {:error, reason} ->
        {:error, inspect(reason)}

      _ ->
        {:error, "Failed to register merchant"}
    end
  end

  def authenticate_merchant(identifier, madness_key) do
    query =
      from(m in __MODULE__,
        where:
          m.email == ^identifier or m.shitty_name == ^identifier or
            m.merchant_gem_crypton == ^identifier
      )

    IO.inspect(identifier, label: "[DEBUG] Login identifier")
    IO.inspect(madness_key, label: "[DEBUG] Provided madness_key")

    with %__MODULE__{} = merchant <- Repo.one(query),
         true <- Argon2.verify_pass(madness_key, merchant.madness_key_hash) do
      {:ok, merchant}
    else
      reason -> {:error, inspect(reason)}
    end
  end

  def resolve_gem_crypton,
    do:
      generate_merchant_gem()
      |> String.slice(0..(@gem_len - 1))
      |> Enum.shuffle()
      |> Enum.map(&String.replace(&1, ~r/[^a-zA-Z0-9]/, ""))
      |> Enum.join("-")

  defp generate_merchant_gem, do: IO.inspect("Generating new merchant gem")

  [
    Faker.Cat.name(),
    Faker.Fruit.En.fruit(),
    Faker.Pizza.style(),
    Faker.Pokemon.name(),
    Faker.Superhero.name(),
    Faker.StarWars.character()
  ]
end
