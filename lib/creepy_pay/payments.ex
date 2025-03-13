defmodule CreepyPay.Payments do
  use Ecto.Schema
  import Ecto.Changeset
  alias CreepyPay.Repo
  alias CreepyPay.Wallets

  @primary_key {:payment_metacore, :binary, autogenerate: false}
  @derive {Jason.Encoder,
           only: [
             :payment_metacore,
             :merchant_gem_crypton,
             :stealth_address,
             :amount,
             :status,
             :inserted_at
           ]}
  schema "payments" do
    field(:merchant_gem_crypton, :binary)
    field(:stealth_address, :string)
    field(:amount, :string)
    field(:status, :string, default: "pending")

    timestamps()
  end

  @doc """
  Changeset for validating payment data.
  """
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:payment_metacore, :merchant_gem_crypton, :stealth_address, :amount, :status])
    |> validate_required([:payment_metacore, :merchant_gem_crypton, :amount, :status])
  end

  @doc """
  Creates a new payment and assigns a stealth address dynamically.
  """
  def store_payment(%{merchant_gem_crypton: merchant_gem_crypton, amount: _amount} = payment) do
    case Wallets.get_wallet_by_merchant(merchant_gem_crypton) do
      nil ->
        {:error, "Merchant wallet not found"}

      _wallet ->
        stealth_address =
          Wallets.create_wallet(merchant_gem_crypton) |> elem(1) |> Map.get(:address)

        %__MODULE__{}
        |> changeset(
          payment
          |> Map.put(:payment_metacore, Ecto.UUID.generate())
          |> Map.put(:stealth_address, stealth_address)
          |> Map.put(:status, "pending")
        )
        |> Repo.insert()
    end
  end

  @doc """
  Retrieves a payment by ID.
  """
  def get_payment(payment_metacore) do
    case Repo.get(__MODULE__, payment_metacore) do
      nil -> {:error, "Payment not found"}
      payment -> {:ok, payment}
    end
  end

  @doc """
  Updates the payment status.
  """
  def update_payment_status(payment_metacore, new_status) do
    case get_payment(payment_metacore) do
      {:ok, payment} ->
        payment
        |> changeset(%{status: new_status})
        |> Repo.update()

      error ->
        error
    end
  end
end
