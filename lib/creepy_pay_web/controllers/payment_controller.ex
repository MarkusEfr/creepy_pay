defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.StealthPay
  require Logger

  def generate_payment_request(conn, %{"payment_id" => payment_id, "amount_wei" => amount_wei}) do
    case StealthPay.generate_payment_request(payment_id, amount_wei) do
      {:ok, response} -> json(conn, %{status: "success", payment: response})
      {:error, reason} -> json(conn, %{status: "failed", reason: reason})
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
