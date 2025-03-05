defmodule CreepyPay.StealthPay do
  require Logger
  alias Jason
  alias Finch
  alias QRCode

  # Step 1: Generate Payment Request
  def generate_payment_request(payment_id, amount_wei) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, _} ->
        {:error, "Payment already exists"}

      {:error, _} ->
        CreepyPay.Payments.store_payment(payment_id, nil, amount_wei)
        {:ok, %{payment_id: payment_id, amount_wei: amount_wei}}
    end
  end

  # Step 2: Process Payment (Generate Unsigned TX + Ethereum Payment Link + QR Code)
  def process_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{amount: amount_wei, status: "pending"}} when amount_wei > 0 ->
        with {:ok, unsigned_tx} <- create_unsigned_tx(payment_id, amount_wei),
             {:ok, eth_payment_link} <-
               generate_ethereum_payment_link(
                 get_payment_processor(),
                 DateTime.utc_now() |> DateTime.to_unix(),
                 amount_wei
               ),
             {:ok, qr_base64} <- generate_qr_code(eth_payment_link) do
          payment = %{
            unsigned_tx: unsigned_tx,
            eth_payment_link: eth_payment_link,
            amount_wei: amount_wei,
            qr_code: qr_base64
          }

          {:ok, payment}
        else
          {:error, msg} -> {:error, "Failed to process payment: #{inspect(msg)}"}
        end

      {:ok, _} ->
        {:error, "Payment already processed"}

      {:error, _} ->
        {:error, "Payment not found"}
    end
  end

  # Step 3: Verify Payment Status
  def verify_payment(payment_id) do
    case CreepyPay.Payments.get_payment(payment_id) do
      {:ok, %{payment_status: status}} -> {:ok, status}
      _ -> {:error, "Payment not found"}
    end
  end

  def wei_to_eth(wei) when is_binary(wei) do
    # Detect hex format and convert properly
    parsed_wei =
      if String.starts_with?(wei, "0x") do
        String.slice(wei, 2..-1) |> Integer.parse(16) |> elem(0)
      else
        String.to_integer(wei)
      end

    wei_to_eth(parsed_wei)
  end

  def wei_to_eth(wei) when is_integer(wei) do
    eth = Decimal.div(Decimal.new(wei), Decimal.new("1000000000000000000"))
    # Prevents scientific notation
    Decimal.to_string(eth, :normal)
  end

  # Generates an unsigned transaction for payment processing
  defp create_unsigned_tx(payment_id, amount) do
    encoded_tx = encode_function("processPayment(bytes32,uint256)", [payment_id, amount])

    {:ok,
     %{
       "to" => get_payment_processor(),
       "gas" => "0x5208",
       "gasPrice" => "0x3B9ACA00",
       "value" => "0x" <> amount,
       "data" => encoded_tx
     }}
  end

  defp generate_ethereum_payment_link(recipient, unlock_time, amount_wei) do
    factory_address = get_payment_processor()
    # Sepolia Testnet
    chain_id = "11155111"

    eth_payment_link =
      "ethereum:#{factory_address}@#{chain_id}/createStealthWallet" <>
        "?address=#{recipient}" <>
        "&uint256=#{unlock_time}" <>
        "&value=#{amount_wei}"

    {:ok, eth_payment_link}
  end

  defp generate_qr_code(eth_payment_link) do
    qr_png =
      eth_payment_link
      |> QRCode.create()
      |> QRCode.render(:png, %QRCode.Render.PngSettings{
        background_color: {11, 214, 106},
        scale: 5
      })

    {:ok, qr_base64} = QRCode.to_base64(qr_png)
  end

  # Encodes contract function calls for Ethereum transactions
  defp encode_function(function_name, args) do
    string_function_name = to_string(function_name)

    selector =
      :sha3_256
      |> :crypto.hash(string_function_name)
      |> binary_part(0, 4)
      |> Base.encode16(case: :lower)

    encoded_args =
      Enum.map(args, fn
        arg when is_integer(arg) ->
          Integer.to_string(arg, 16) |> String.pad_leading(64, "0")

        arg when is_binary(arg) ->
          if String.starts_with?(arg, "0x") do
            String.slice(arg, 2..-1) |> String.pad_leading(64, "0")
          else
            String.pad_leading(arg, 64, "0")
          end

        arg ->
          raise ArgumentError, "Unsupported argument type: #{inspect(arg)}"
      end)
      |> Enum.join()

    "0x" <> selector <> encoded_args
  end

  # Retrieves environment variables for blockchain interactions
  defp get_rpc_url, do: Application.get_env(:creepy_pay, :rpc_url, nil)
  defp get_payment_processor, do: Application.get_env(:creepy_pay, :payment_processor, nil)
  defp get_payment_url, do: Application.get_env(:creepy_pay, :payment_url, nil)
end
