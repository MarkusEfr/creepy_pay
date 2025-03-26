defmodule CreepyPay.StealthPay do
  require Logger

  import CreepyPay.Validates.PaymentFlow

  alias QRCode

  @chain_id "11155111"

  def generate_payment_request(%{amount: amount_wei} = _params) do
    {:ok, _payment} =
      CreepyPay.Payments.store_payment(%{
        amount: amount_wei
      })
  end

  def release_payment(payment_metacore, recipient) do
    hashed_madness_key = hash_madness_key(payment_metacore)

    {_, 0} =
      System.cmd(
        "node",
        [
          "assets/js/payment_contractor.mjs",
          "unleashDamnation",
          hashed_madness_key,
          recipient
        ],
        env: [
          {"RPC_URL", Application.get_env(:creepy_pay, :rpc_url)},
          {"PRIVATE_KEY", Application.get_env(:creepy_pay, :private_key)},
          {"PAYMENT_PROCESSOR", get_payment_processor()}
        ]
      )

    :ok
  end

  def process_payment(%{
        madness_key_hash: madness_key_hash,
        payment_metacore: payment_metacore
      }) do
    case validate_payment_waiting_invoke(%{
           "payment_metacore" => payment_metacore
         }) do
      {:ok, %{amount: amount_wei} = _payment} ->
        {call_data, 0} =
          System.cmd(
            "node",
            [
              "assets/js/payment_contractor.mjs",
              "offerBloodOath",
              hash_madness_key(madness_key_hash),
              amount_wei
            ],
            env: [
              {"RPC_URL", Application.get_env(:creepy_pay, :rpc_url)},
              {"PRIVATE_KEY", Application.get_env(:creepy_pay, :private_key)},
              {"PAYMENT_PROCESSOR", get_payment_processor()}
            ]
          )

        call_data = String.trim(call_data)

        eth_link =
          "ethereum:#{get_payment_processor()}@#{@chain_id}?" <>
            "value=#{amount_wei}&data=#{call_data}"

        {:ok, qr_code} = generate_qr_code(eth_link)

        {:ok,
         %{
           eth_payment_link: eth_link,
           qr_code: qr_code,
           data: call_data
         }}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Unexpected error"}
    end
  end

  def vault_balance(%{madness_key_hash: madness_key_hash}) do
    {_, 0} =
      System.cmd(
        "node",
        [
          "assets/js/payment_contractor.mjs",
          "scryInfernalBalance",
          madness_key_hash |> hash_madness_key()
        ],
        env: [
          {"RPC_URL", Application.get_env(:creepy_pay, :rpc_url)},
          {"PRIVATE_KEY", Application.get_env(:creepy_pay, :private_key)},
          {"PAYMENT_PROCESSOR", Application.get_env(:creepy_pay, :payment_processor)}
        ]
      )
  end

  defp hash_madness_key(madness_key_hash) do
    madness_key_hash
    |> String.replace("-", "")
    |> String.downcase()
    |> then(&:crypto.hash(:sha3_256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("0x" <> &1))
  end

  defp generate_qr_code(link) do
    link
    |> QRCode.create()
    |> QRCode.render(:png, %QRCode.Render.PngSettings{
      scale: 4,
      qrcode_color: {0, 128, 0},
      background_color: {255, 255, 255}
    })
    |> QRCode.to_base64()
  end

  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
end
