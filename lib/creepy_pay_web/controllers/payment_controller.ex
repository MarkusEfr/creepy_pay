defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.{Payments, StealthPay}
  require Logger

  def create_payment(conn, %{"merchant_gem" => merchant_gem, "amount" => amount}) do
    case Payments.store_payment(%{merchant_gem: merchant_gem, amount: amount}) do
      {:ok, payment} ->
        json(conn, payment)

      {:error, _reason} ->
        json(conn, %{error: "Payment creation failed"})
    end
  end

  def generate_payment_request(conn, %{"merchant_gem" => merchant_gem, "amount_wei" => amount_wei}) do
    case StealthPay.generate_payment_request(merchant_gem, amount_wei) do
      {:ok, payment} -> json(conn, %{status: "success", payment: payment})
      {_, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end

  def process_payment(conn, %{"payment_id" => payment_id}) do
    case StealthPay.process_payment(payment_id) do
      {:ok, payment} ->
        json(conn, %{status: "success", payment: payment})

      {:error, reason} ->
        json(conn, %{status: "failed", reason: reason})
    end
  end

  def verify_payment(conn, %{"payment_id" => payment_id}) do
    case StealthPay.verify_payment(payment_id) do
      {:ok, status} -> json(conn, %{status: "success", payment_status: status})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
    end
  end
end
