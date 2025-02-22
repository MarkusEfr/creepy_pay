defmodule CreepyPay.Payments do
  @table :payments

  def store_payment(payment_id, amount, status) do
    :mnesia.transaction(fn ->
      :mnesia.write({@table, payment_id, amount, status})
    end)
  end

  def get_payment(payment_id) do
    :mnesia.transaction(fn ->
      case :mnesia.read({@table, payment_id}) do
        [] -> {:error, "Payment not found"}
        [{@table, _id, amount, status}] -> {:ok, %{amount: amount, status: status}}
      end
    end)
  end

  def update_payment_status(payment_id, new_status) do
    :mnesia.transaction(fn ->
      case :mnesia.read({@table, payment_id}) do
        [] -> {:error, "Payment not found"}
        [{@table, _id, amount, _old_status}] ->
          :mnesia.write({@table, payment_id, amount, new_status})
      end
    end)
  end

  def delete_payment(payment_id) do
    :mnesia.transaction(fn ->
      :mnesia.delete({@table, payment_id})
    end)
  end
end
