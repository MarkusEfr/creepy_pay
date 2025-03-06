defmodule CreepyPay.Guardian.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :my_app,
    module: CreepyPay.Guardian,
    error_handler: CreepyPay.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, realm: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end
