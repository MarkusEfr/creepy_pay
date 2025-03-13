defmodule CreepyPayWeb.AuthErrorHandler do
  import Plug.Conn
  alias CreepyPay.Auth.Guardian, as: CreepyGuardian

  require Logger

  @doc """
  Handles authentication errors and sends a JSON response with a clear error message.
  Uses Guardian verification logic with best practices.
  """
  def auth_error(conn, {type, reason}, _opts) do
    token = Guardian.Plug.current_token(conn)

    with {:ok, claims} <- CreepyGuardian.decode_and_verify(token, %{}),
         {:ok, _resource, _claims} <- CreepyGuardian.resource_from_token(token, claims) do
      Logger.warning("[AUTH ERROR] Type: #{inspect(type)}, Reason: #{inspect(reason)}")

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        401,
        Jason.encode!(%{
          error: to_string(type),
          reason: inspect(reason),
          message: "Authentication failed. Please check your token."
        })
      )
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{
            error: to_string(type),
            reason: inspect(reason),
            message: "Unauthorized access."
          })
        )
    end
  end
end
