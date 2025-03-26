defmodule CreepyPay.StealthPay do
  require Logger

  import CreepyPay.Validates.PaymentFlow

  alias QRCode

  def generate_payment_request(
        %{amount: amount_wei, madness_key_hash: madness_key_hash} = _params
      ) do
    {:ok, _payment} =
      CreepyPay.Payments.store_payment(%{
        amount: amount_wei,
        madness_key_hash: madness_key_hash
      })
  end

  def release_payment(madness_key_hash, recipient) do
    hashed_madness_key = hash_madness_key(madness_key_hash)

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
        payment_metacore: payment_metacore
      }) do
    case validate_payment_waiting_invoke(%{
           "payment_metacore" => payment_metacore
         }) do
      {:ok, %{amount: amount_wei, madness_key_hash: madness_key_hash} = payment} ->
        integer_payment_metacore = payment_metacore_to_integer(payment_metacore)
        payment_contract = get_payment_processor()

        {call_data, 0} =
          System.cmd(
            "node",
            [
              "assets/js/payment_contractor.mjs",
              "offerBloodOath",
              hash_madness_key(madness_key_hash),
              inspect(integer_payment_metacore),
              amount_wei
            ],
            env: [
              {"RPC_URL", Application.get_env(:creepy_pay, :rpc_url)},
              {"PRIVATE_KEY", Application.get_env(:creepy_pay, :private_key)},
              {"PAYMENT_PROCESSOR", payment_contract}
            ]
          )

        %{"data" => call_data, "eth_link" => eth_link, "value" => value} =
          Jason.decode!(call_data)

        {:ok, qr_code} = generate_qr_code(eth_link)

        deeplinks = build_deeplinks(%{to: payment_contract, value: value, data: call_data})

        {:ok,
         %{
           link: eth_link,
           qr_code: qr_code,
           data: call_data,
           deeplinks: deeplinks,
           entity: payment
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
          {"PAYMENT_PROCESSOR", get_payment_processor()}
        ]
      )
  end

  defp build_deeplinks(%{to: to, value: value, data: data}) do
    %{
      metamask: "https://metamask.app.link/send/#{to}?value=#{value}&data=#{data}",
      trustwallet: "https://link.trustwallet.com/send?to=#{to}&value=#{value}&data=#{data}"
    }
  end

  defp payment_metacore_to_integer(payment_metacore) do
    payment_metacore_number =
      payment_metacore
      |> String.replace("0x", "")
      |> String.replace("-", "")
      |> String.downcase()

    :sha3_256
    |> :crypto.hash(payment_metacore_number)
    |> :binary.decode_unsigned()
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
    {:ok, qr_code} =
      link
      |> QRCode.create()
      |> QRCode.render(:png, %QRCode.Render.PngSettings{
        scale: 4,
        qrcode_color: {0, 128, 0},
        background_color: {255, 255, 255}
      })
      |> QRCode.to_base64()

    {:ok, "data:image/png;base64," <> qr_code}
  end

  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
end
