defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Payments, StealthPay}

  def invoke_drop(conn, %{
        "merchant_gem_crypton" => merchant_gem_crypton,
        "amount_wei" => amount
      }) do
    Guardian.Plug.current_resource(conn)
    |> IO.inspect(label: "[DEBUG] Merchant")

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

  def trace_specter(conn, %{
        "payment_metacore" => payment_metacore,
        "merchant_gem_crypton" => merchant_gem_crypton
      }) do
    case StealthPay.verify_specter_shadow(%{
           payment_metacore: payment_metacore,
           merchant_gem_crypton: merchant_gem_crypton
         }) do
      :ok ->
        Payments.update_payment_status(payment_metacore, "confirmed")
        json(conn, %{status: "confirmed"})

      :error ->
        Payments.update_payment_status(payment_metacore, "failed")
        json(conn, %{status: "failed"})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "failed", reason: "Invalid attempt"})
    end
  end
end
