defmodule CreepyPay.Auth.Guardian do
  use Guardian, otp_app: :creepy_pay

  alias CreepyPay.Merchants
  alias CreepyPay.Repo

  @doc "Fetches merchant by ID and returns it"
  def subject_for_token(%Merchants{} = merchant, _claims), do: {:ok, merchant.id}
  def subject_for_token(_, _), do: {:error, "Unknown resource type"}

  @doc "Fetches merchant from token claims"
  def resource_from_claims(%{"sub" => merchant_id}) do
    case Repo.get(Merchants, merchant_id) do
      nil -> {:error, "Merchant not found"}
      merchant -> {:ok, merchant}
    end
  end
end
