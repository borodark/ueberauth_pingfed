defmodule Ueberauth.Strategy.PingFed do
  # :pf_token
  # :pf_user
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with PingFed.

  ### Setup

  Create an application in PingFed for you to use.

  Create setup in Ping Fdederate and get the `client_id` and `client_secret`.
  # TODO insert link to sample
  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          pingfed: { Ueberauth.Strategy.PingFed, [] }
        ]

  Then include the configuration for github.

      config :ueberauth, Ueberauth.Strategy.PingFed.OAuth,
        client_id: System.get_env("PINGFED_CLIENT_ID"),
        client_secret: System.get_env("PINGFED_CLIENT_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end


  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
        end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end

  You can edit the behaviour of the Strategy by including some options when you register your provider.

  To set the `uid_field`

      config :ueberauth, Ueberauth,
        providers: [
          pingfed: { Ueberauth.Strategy.PingFed, [uid_field: :email] }
        ]

  Default is `:id`

  To set the default 'scopes' (permissions):

      config :ueberauth, Ueberauth,
        providers: [
          pingfed: { Ueberauth.Strategy.PingFed, [default_scope: "user,public_repo"] }
        ]

  Default is empty ("") which "Grants read-only access to public information (includes public user profile info, public repository info, and gists)"
  """
  use Ueberauth.Strategy, uid_field: :sub,
                          default_scope: "openid",
                          oauth2_module: Ueberauth.Strategy.PingFed.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles the initial redirect to the PF authentication page.

  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    send_redirect_uri = Keyword.get(options(conn), :send_redirect_uri, true)

    opts =
      if send_redirect_uri do
        [redirect_uri: callback_url(conn), scope: scopes]
      else
        [scope: scopes]
      end

    opts =
      if conn.params["state"], do: Keyword.put(opts, :state, conn.params["state"]), else: opts

    module = option(conn, :oauth2_module)
    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  @doc """
  Handles the callback from PingFed. When there is a failure from PingFed the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from PingFed is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)
    token = apply(module, :get_token!, [[code: code], [options: [insecure: true]]])  # TODO move to config

    if token.access_token == nil do
      set_errors!(conn, [error(token.other_params["error"], token.other_params["error_description"])])
    else
      fetch_user(conn, token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw PingFed response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:pf_user, nil)
    |> put_private(:pf_token, nil)
  end

  @doc """
  Includes the credentials from the PingFed response.
  """
  def credentials(conn) do
    token        = conn.private.pf_token
    scope_string = (token.other_params["scope"] || "")
    scopes       = String.split(scope_string, " ")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :pf_token, token)
    # Will be better with Elixir 1.3 with/else
    case Ueberauth.Strategy.PingFed.OAuth.get(token, "/idp/userinfo.openid") do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])
      {:ok, %OAuth2.Response{status_code: status_code, body: user}} when status_code in 200..399 ->
        require Logger
        Logger.debug "PingFed user ...  #{inspect user}"
        config =
          :ueberauth
          |> Application.fetch_env!(Ueberauth.Strategy.PingFed.OAuth)
        relevant_groups = config |> Keyword.get(:relevant_groups) || []
        Logger.debug "Application Groups ...  #{inspect relevant_groups}"
        ad_groups =  user["member_of"]
        Logger.debug "User is member of ...  #{inspect ad_groups}"
        application_relevant_groups_of_user = for r <- relevant_groups, ad <- ad_groups, ad == r, do: r
        Logger.debug "Application Relevant Groups of User ...  #{inspect application_relevant_groups_of_user}"
        user = Map.put user, :member_of, application_relevant_groups_of_user
        put_private(conn, :pf_user, user)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  @doc """
  Fetches the uid field from the PF response. This defaults to the option `uid_field` which in-turn defaults to `sub`
  """
  def uid(conn) do
    conn |> option(:uid_field) |> to_string() |> fetch_uid(conn)
  end

    @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  This is anexample of structurte coming from PF setup
  %{"name" => "Dough, Joan",
  "objectSid" => <<6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0>>,
  "sub" => "joandough@yourgloriousdomain.com",
  "common_id" => "666-666-666",
  "email" => "JoanDough@yourgloriousdomain.com",
  "family_name" => "Dough, Joan",
  "given_name" => "Xi",
  "member_of" => ["CN=Mobile Access Level 1,OU=Miscellaneous,OU=Resource Groups - Restricted - Identity Engineering,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com", "CN=Rockworld News,OU=Ad-Hoc,OU=Role Groups,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com", "CN=Rockworld Michigan Users,OU=Ad-Hoc,OU=Role Groups,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com" ] }
 
  """
  def info(conn) do
    user = conn.private.pf_user
    %Info{
      name: user["name"],
      description: user["common_id"] <> "::"<> user["objectSid"] ,
      nickname: user["family_name"],
      first_name: user["given_name"],
      email: user["email"],
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the PF callback.
  """
  def extra(conn) do
    %Extra {
      raw_info: %{
        token: conn.private.pf_token,
        user: conn.private.pf_user
      }
    }
  end

  defp fetch_uid("email", %{private: %{pf_user: user} }) do
    # private email will not be available as :email and must be fetched
    fetch_email!(user)
  end

  defp fetch_uid(field, conn) do
    conn.private.pf_user[field]
  end

  defp fetch_email!(user) do
    user["email"]
  end

end
