defmodule CreepyPay.Payments do
  use Ecto.Schema
  import Ecto.Changeset
  alias CreepyPay.Repo

  @primary_key {:payment_metacore, :string, autogenerate: false}
  @derive {Jason.Encoder,
           only: [
             :payment_metacore,
             :amount,
             :status,
             :inserted_at
           ]}
  schema "payments" do
    field(:amount, :string)
    field(:status, :string, default: "pending")

    timestamps()
  end

  @doc """
  Changeset for validating payment data.
  """
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:payment_metacore, :amount, :status])
    |> validate_required([:payment_metacore, :amount, :status])
  end

  @doc """
  Creates a new payment and assigns a stealth address dynamically.
  """
  def store_payment(%{amount: amount} = _payment) do
    %__MODULE__{
      payment_metacore: Ecto.UUID.generate(),
      amount: amount
    }
    |> Repo.insert()
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
