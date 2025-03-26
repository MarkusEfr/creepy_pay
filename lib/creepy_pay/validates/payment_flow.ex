defmodule CreepyPay.Validates.PaymentFlow do
  alias CreepyPay.Payments

  def validate_payment_waiting_invoke(%{"payment_metacore" => payment_metacore}) do
    case Payments.get_payment(payment_metacore) do
      {:error, _reason} = error ->
        error

      {:ok, %{status: "pending"} = payment} ->
        {:ok, payment}

      _ ->
        {:error, "Payment already processed"}
    end
  end
end
