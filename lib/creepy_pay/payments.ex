defmodule CreepyPay.Payments do
  use Ecto.Schema
  import Ecto.Changeset
  alias CreepyPay.Repo

  @primary_key {:payment_metacore, :string, autogenerate: false}
  @derive {Jason.Encoder,
           only: [
             :payment_metacore,
             :madness_key_hash,
             :amount,
             :status,
             :invoice_details,
             :inserted_at
           ]}
  schema "payments" do
    field(:madness_key_hash, :string)
    field(:amount, :string)
    field(:status, :string, default: "pending")
    field(:invoice_details, :map, default: %{})

    timestamps()
  end

  @doc """
  Changeset for validating payment data.
  """
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:payment_metacore, :madness_key_hash, :amount, :status, :invoice_details])
    |> validate_required([
      :payment_metacore,
      :madness_key_hash,
      :amount,
      :status,
      :invoice_details
    ])
  end

  @doc """
  Updates any field(s) of a payment given its payment_metacore and a map of updates.
  """
  def update_payment(%{payment_metacore: payment_metacore} = payment, %{} = updates) do
    updated_payment =
      payment
      |> changeset(updates)
      |> Repo.update()

    case updated_payment do
      {:ok, payment} -> {:ok, payment}
      error -> error
    end
  end

  @doc """
  Creates a new payment and assigns a stealth address dynamically.
  """
  def store_payment(%{amount: amount, madness_key_hash: madness_key_hash} = _payment) do
    %__MODULE__{
      payment_metacore: Ecto.UUID.generate(),
      madness_key_hash: madness_key_hash,
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

  @doc """
  Update the invoice details.
  """
  def update_invoice_details(payment_metacore, invoice_details) do
    case get_payment(payment_metacore) do
      {:ok, payment} ->
        payment
        |> changeset(%{invoice_details: invoice_details})
        |> Repo.update()

      error ->
        error
    end
  end
end
