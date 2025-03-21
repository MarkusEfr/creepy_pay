defmodule CreepyPayWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use CreepyPayWeb, :controller
      use CreepyPayWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: CreepyPayWeb.Layouts]

      use Gettext, backend: CreepyPayWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(view_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      use Phoenix.VerifiedRoutes,
        endpoint: CreepyPayWeb.Endpoint,
        router: CreepyPayWeb.Router,
        statics: CreepyPayWeb.static_paths()

      import Phoenix.LiveView.Helpers
      import Phoenix.Component

      alias CreepyPayWeb.Router.Helpers, as: Routes
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: CreepyPayWeb.Endpoint,
        router: CreepyPayWeb.Router,
        statics: CreepyPayWeb.static_paths()
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {CreepyPayWeb.Layouts, :root}

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.LiveView.Helpers
      import CreepyPayWeb.CoreComponents
      import CreepyPayWeb.Gettext
      alias CreepyPayWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
