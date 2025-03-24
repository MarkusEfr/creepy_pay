defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Payments, StealthPay}

  def invoke_drop(conn, %{
        "merchant_gem_crypton" => merchant_gem_crypton,
        "amount_wei" => amount
      }) do
    with {:ok, %{payment_metacore: payment_metacore}} <-
           StealthPay.generate_payment_request(%{
             merchant_gem_crypton: merchant_gem_crypton,
             amount: amount
           }),
         {:ok, payment_data} <-
           StealthPay.process_payment(payment_metacore) do
      json(conn, %{status: "success", payment: payment_data})
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "failed", reason: reason})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "failed", reason: "Unexpected error"})
    end
  end

  def get_payment_details(conn, %{"payment_metacore" => payment_metacore}) do
    {:ok, payment} = Payments.get_payment(payment_metacore)
    json(conn, %{status: "success", payment: payment})
  end
end
