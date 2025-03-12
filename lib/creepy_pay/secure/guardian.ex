defmodule CreepyPay.Auth.Guardian do
  use Guardian, otp_app: :creepy_pay

  alias CreepyPay.Merchants
  alias CreepyPay.Repo

  def subject_for_token(%Merchants{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_, _), do: {:error, :reason_for_error}

  def resource_from_claims(%{"sub" => id}) do
    case Repo.get(Merchants, String.to_integer(id)) do
      nil -> {:error, :resource_not_found}
      merchant -> {:ok, merchant}
    end
  end
end
