defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Payments, StealthPay}
  require Logger

  def create_payment(conn, %{
        "merchant_gem_crypton" => merchant_gem_crypton,
        "amount_wei" => amount
      }) do
    case StealthPay.generate_payment_request(%{
           merchant_gem_crypton: merchant_gem_crypton,
           amount: amount
         }) do
      {:ok, payment} ->
        json(conn, payment)

      _ ->
        json(conn, %{error: "Payment creation failed"})
    end
  end

  def get_payment_details(conn, %{"payment_metacore" => payment_metacore}) do
    {:ok, payment} = Payments.get_payment(payment_metacore)
    json(conn, %{status: "success", payment: payment})
  end

  def process_payment(conn, %{"payment_metacore" => payment_metacore}) do
    case StealthPay.process_payment(payment_metacore) do
      {:ok, payment} ->
        json(conn, %{status: "success", payment: payment})

      {:error, reason} ->
        json(conn, %{status: "failed", reason: reason})
    end
  end

  def verify_payment(conn, %{"payment_metacore" => payment_metacore}) do
    case StealthPay.verify_payment(payment_metacore) do
      {:ok, status} -> json(conn, %{status: "success", payment_status: status})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end
end
