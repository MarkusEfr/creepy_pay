defmodule CreepyPayWeb.Layouts do
  use CreepyPayWeb, :html

  embed_templates("layouts/*")

  def root(assigns) do
    ~H"""
     <html lang="en" id="root" phx-hook="RootHook" phx-track-static>
     <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
    <head>
    <%= Phoenix.LiveView.Helpers.live_title_tag(assigns[:page_title] || "CreepyPay") %>
    </head>
    <body>
    <%= @inner_content %>
    </body>
    </html>
    """
  end
end
