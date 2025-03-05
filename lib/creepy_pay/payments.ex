defmodule CreepyPay.Payments do
  use Ecto.Schema
  import Ecto.Changeset
  alias CreepyPay.Repo
  alias CreepyPay.Wallets

  @primary_key {:payment_id, :string, autogenerate: false}
  @derive {Jason.Encoder,
           only: [:payment_id, :merchant_gem, :stealth_address, :amount, :status, :inserted_at]}
  schema "payments" do
    field(:merchant_gem, :string)
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
    |> cast(attrs, [:payment_id, :merchant_gem, :stealth_address, :amount, :status])
    |> validate_required([:payment_id, :merchant_gem, :amount, :status])
  end

  @doc """
  Creates a new payment and assigns a stealth address dynamically.
  """
  def store_payment(%{merchant_gem: merchant_gem, amount: _amount} = payment) do
    case Wallets.get_wallet_by_merchant(merchant_gem) do
      nil ->
        {:error, "Merchant wallet not found"}

      _wallet ->
        stealth_address = Wallets.create_wallet(merchant_gem) |> elem(1) |> Map.get(:address)

        %__MODULE__{}
        |> changeset(
          payment
          |> Map.put(:payment_id, Ecto.UUID.generate())
          |> Map.put(:stealth_address, stealth_address)
          |> Map.put(:status, "pending")
        )
        |> Repo.insert()
    end
  end

  @doc """
  Retrieves a payment by ID.
  """
  def get_payment(payment_id) do
    case Repo.get(__MODULE__, payment_id) do
      nil -> {:error, "Payment not found"}
      payment -> {:ok, payment}
    end
  end

  @doc """
  Updates the payment status.
  """
  def update_payment_status(payment_id, new_status) do
    case get_payment(payment_id) do
      {:ok, payment} ->
        payment
        |> changeset(%{status: new_status})
        |> Repo.update()

      error ->
        error
    end
  end
end
