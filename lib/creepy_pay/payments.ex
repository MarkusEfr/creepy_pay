defmodule CreepyPay.Payments do
  use Memento.Table,
    attributes: [:payment_id, :stealth_address, :amount, :status],
    type: :set

  @table __MODULE__

  def setup do
    nodes = [node()]
    Memento.stop()
    Memento.Schema.create(nodes)
    Memento.start()

    case Memento.Table.create(@table, disc_copies: nodes) do
      :ok -> IO.puts("✅ Mnesia table #{@table} created successfully")
      {:error, {:already_exists, _}} -> IO.puts("⚠️ Mnesia table #{@table} already exists")
      _ -> IO.puts("❌ Mnesia setup failed")
    end
  end

  def store_payment(payment_id, stealth_address, amount) do
    Memento.transaction!(fn ->
      Memento.Query.write(%@table{
        payment_id: payment_id,
        stealth_address: stealth_address,
        amount: amount,
        status: "pending"
      })
    end)
  end

  def get_payment(payment_id) do
    Memento.transaction!(fn ->
      case Memento.Query.read(@table, payment_id) do
        nil -> {:error, "Payment not found"}
        record -> {:ok, record}
      end
    end)
  end

  def update_payment_status(payment_id, new_status) do
    Memento.transaction!(fn ->
      case Memento.Query.read(@table, payment_id) do
        nil -> {:error, "Payment not found"}
        record -> Memento.Query.write(%{record | status: new_status})
      end
    end)
  end
end
