defmodule CreepyPay.Guardian do
  use Guardian, otp_app: :creepy_pay

  def subject_for_token(resource, _claims) do
    {:ok, to_string(resource.id)}
  end

  def resource_from_claims(claims) do
    resource_id = claims["merchant_greed"]
    resource = CreepyPay.Merchants.get_merchant(resource_id)
    {:ok, resource}
  end
end
