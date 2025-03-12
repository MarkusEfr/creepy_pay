defmodule CreepyPay.Merchants do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias CreepyPay.Repo
  alias Argon2

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :merchant_gem, :shitty_name, :email, :inserted_at]}
  schema "merchants" do
    field(:merchant_gem, :string)
    field(:shitty_name, :string)
    field(:email, :string)
    field(:madness_key_hash, :string)
    timestamps()
  end

  @doc "Merchant changeset"
  def changeset(merchant, attrs) do
    merchant
    |> cast(attrs, [:merchant_gem, :shitty_name, :email, :madness_key_hash])
    |> validate_required([:merchant_gem, :shitty_name, :email, :madness_key_hash])
    |> validate_length(:shitty_name, min: 3, max: 20)
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    |> unique_constraint(:merchant_gem)
    |> unique_constraint(:email)
  end

  @doc "Registers a merchant with madness_key"
  def register_merchant(%{
        "shitty_name" => shitty_name,
        "email" => email,
        "madness_key" => madness_key
      }) do
    gem = generate_merchant_gem()

    %__MODULE__{}
    |> changeset(%{
      merchant_gem: gem,
      shitty_name: shitty_name,
      email: email,
      madness_key_hash: Argon2.hash_pwd_salt(madness_key)
    })
    |> Repo.insert()
  end

  def authenticate_merchant(identifier, madness_key) do
    query =
      from(m in __MODULE__,
        where:
          m.email == ^identifier or m.shitty_name == ^identifier or m.merchant_gem == ^identifier
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

  defp generate_merchant_gem do
    [
      Faker.Cat.name(),
      Faker.Fruit.En.fruit(),
      Faker.Pizza.style(),
      Faker.Pokemon.name(),
      Faker.Superhero.name(),
      Faker.StarWars.character()
    ]
    |> Enum.shuffle()
    |> Enum.map(&String.replace(&1, ~r/[^a-zA-Z0-9]/, ""))
    |> Enum.join("-")
    |> String.downcase()
  end
end
