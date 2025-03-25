defmodule CreepyPay.StealthPay do
  require Logger

  import CreepyPay.Validates.PaymentFlow

  alias CreepyPay.Merchants
  alias QRCode

  @chain_id "11155111"

  def generate_payment_request(
        %{merchant_gem_crypton: merchant_gem_crypton, amount: amount_wei} = _params
      ) do
    %CreepyPay.Wallets.Wallet{address: _address} =
      wallet = CreepyPay.Wallets.create_wallet(%{merchant_gem_crypton: merchant_gem_crypton})

    {:ok, _payment} =
      CreepyPay.Payments.store_payment(%{
        merchant_gem_crypton: merchant_gem_crypton,
        amount: amount_wei,
        wallet: wallet
      })
  end

  def verify_specter_shadow(%{
        payment_metacore: payment_metacore,
        merchant_gem_crypton: _merchant_gem_crypton
      }) do
    with {:ok, payment} <-
           CreepyPay.Payments.get_payment(payment_metacore) |> IO.inspect(label: "[INFO] Payment"),
         %{
           amount: amount_wei,
           stealth_address: _address,
           status: "pending"
         } <- payment |> IO.inspect(label: "[INFO] Payment Details"),
         true <- amount_wei != "0" do
      hashed_payment_id = hash_metacore(payment_metacore)

      case System.cmd(
             "node",
             [
               "assets/js/payment_contractor.mjs",
               "traceSpecter",
               hashed_payment_id
             ],
             env: [
               {"RPC_URL", Application.get_env(:creepy_pay, :rpc_url)},
               {"PRIVATE_KEY", Application.get_env(:creepy_pay, :private_key)},
               {"PAYMENT_PROCESSOR", get_payment_processor()}
             ]
           ) do
        {_, 0} -> :ok
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  def process_payment(payment_metacore) do
    with {:ok,
          %{
            merchant_gem_crypton: merchant_gem_crypton,
            amount: amount_wei,
            stealth_address: address
          }} <-
           validate_payment_waiting_invoke(%{
             "payment_metacore" => payment_metacore
           }) do
      payment_id = hash_metacore(payment_metacore)
      hashed_payment_id = hash_metacore(payment_id)

      Logger.info(
        "Processing payment: #{hashed_payment_id} related to stealth wallet: #{address}"
      )

      {call_data, 0} =
        System.cmd(
          "node",
          [
            "assets/js/payment_contractor.mjs",
            "invokeDrop",
            hashed_payment_id,
            address,
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
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unexpected error"}
    end
  end

  defp hash_metacore(payment_metacore) do
    payment_metacore
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
