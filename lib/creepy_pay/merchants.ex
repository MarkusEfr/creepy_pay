defmodule CreepyPay.Merchants do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias CreepyPay.Repo
  require Logger

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:shitty_name, :email, :inserted_at]}
  schema "merchants" do
    field(:shitty_name, :string)
    field(:email, :string)
    field(:madness_key_hash, :string)
    timestamps()
  end

  @doc "Changeset for merchant creation"
  def changeset(merchant, attrs) do
    merchant
    |> cast(attrs, [:shitty_name, :email, :madness_key_hash])
    |> validate_required([:shitty_name, :email, :madness_key_hash])
    |> validate_length(:shitty_name, min: 3, max: 108)
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,15}$/)
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
    if byte_size(madness_key) != 32 do
      {:error, "madness_key must be exactly 32 bytes"}
    else
      # Use HMAC-SHA256: madness_key (secret), email (message)
      madness_key_hash =
        :crypto.mac(:hmac, :sha256, madness_key, email)
        |> Base.encode32(padding: false)

      merchant = %{
        shitty_name: shitty_name,
        email: email,
        madness_key_hash: madness_key_hash
      }

      case changeset(%__MODULE__{}, merchant) |> Repo.insert() do
        {:ok, merchant} ->
          {:ok, merchant}

        {:error, changeset} ->
          {:error, changeset.errors |> Enum.map(fn {k, {v, _}} -> "#{k}: #{v}" end)}
      end
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
          where: m.email == ^identifier or m.shitty_name == ^identifier
        )

      case Repo.one(query) do
        %__MODULE__{email: email, madness_key_hash: stored_hash} = merchant ->
          calculated_hash =
            :crypto.mac(:hmac, :sha256, madness_key, email)
            |> Base.encode32(padding: false)

          if calculated_hash == stored_hash do
            {:ok, merchant}
          else
            {:error, "Invalid credentials"}
          end

        nil ->
          {:error, "Merchant not found"}
      end
    end
  end

  def get_merchant_by_id(id) do
    case Repo.get(__MODULE__, id) do
      nil -> {:error, "Merchant not found"}
      merchant -> {:ok, merchant}
    end
  end
end
