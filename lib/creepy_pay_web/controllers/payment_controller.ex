defmodule CreepyPayWeb.PaymentController do
  use CreepyPayWeb, :controller
  alias CreepyPay.StealthPay

  def offer_blood_oath(conn, %{"amount_wei" => amount}) do
    %CreepyPay.Merchants{madness_key_hash: madness_key_hash} =
      Guardian.Plug.current_resource(conn)

    with {:ok, %{payment_metacore: payment_metacore}} <-
           StealthPay.generate_payment_request(%{
             amount: amount,
             madness_key_hash: madness_key_hash
           }),
         {:ok, payment_data} <-
           StealthPay.process_payment(%{
             payment_metacore: payment_metacore
           }) do
      json(conn, %{status: "success", payment: payment_data})
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "failed", reason: reason})

      result ->
        conn
        |> put_status(:bad_request)
        |> json(result)
    end
  end

  def unleash_damnation(conn, %{
        "madness_key" => madness_key,
        "recipient" => recipient
      }) do
    case StealthPay.release_payment(%{madness_key: madness_key, recipient: recipient}) do
      {:ok, transaction} ->
        conn
        |> put_status(:ok)
        |> json(transaction)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(reason)

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{"status" => "failed", "reason" => "Unexpected error"})
    end
  end

  def vault_balance(conn, _) do
    %{madness_key_hash: madness_key_hash} = Guardian.Plug.current_resource(conn)

    case StealthPay.vault_balance(%{madness_key_hash: madness_key_hash}) do
      {amount, 0} ->
        json(conn, %{status: "ok", balance_wei: String.trim(amount)})

      {error_msg, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "failed", reason: String.trim(error_msg)})
    end
  end
end
