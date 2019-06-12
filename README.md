# Überauth Ping Federate

> Ping Federate OAuth2 strategy for Überauth.

Shamelessly copied from https://github.com/ueberauth/ueberauth_github. Huge thanks to üeberauth team: https://github.com/ueberauth! for all the work done

## Installation

1. Setup your application at PingFederate.

I have used this manual:
  https://github.com/SilentCircle/sso-integration-doc/blob/master/PingFederate-Integration-Customer-Responsibilities.md
  Huge thanks to the author: https://github.com/efine !!!

My setup of PingFederate returns this structure:

```elixir
%{"name" => "Dough, Joan",
  "objectSid" => <<6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0>>,
  "sub" => "joandough@yourgloriousdomain.com",
  "common_id" => "666-666-666",
  "email" => "JoanDough@yourgloriousdomain.com",
  "family_name" => "Dough, Joan",
  "given_name" => "Xi",
  "member_of" => ["CN=Mobile Access Level 1,OU=Miscellaneous,OU=Resource Groups - Restricted - Identity Engineering,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com", "CN=Rockworld News,OU=Ad-Hoc,OU=Role Groups,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com", "CN=Rockworld Michigan Users,OU=Ad-Hoc,OU=Role Groups,OU=Groups,DC=mi,DC=corp,DC=yourgloriousdomain,DC=com" ] }
```

Customize the transformation here:


1. Add `:ueberauth_pingfed` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [ ... ,
      {:ueberauth_pingfed, git: "https://github.com/borodark/ueberauth_pingfed.git"},
      ... ]
    end
    ```

1. Add the strategy to your applications:

    ```elixir
    def application do
      [applications: [:ueberauth_pingfed]]
    end
    ```

1. Add Pingfed to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        pingfed: {Ueberauth.Strategy.Pingfed, []}
      ]
    ```

1.  Update your provider configuration:

    ```elixir

    config :ueberauth, Ueberauth.Strategy.Pingfed.OAuth,
      site: System.get_env("PINGFED_SITE"),
      client_id: System.get_env("PINGFED_CLIENT_ID"),
      client_secret: System.get_env("PINGFED_CLIENT_SECRET"),
      
      relevant_groups: [ "CN=Team Awesome,OU=Ad-Hoc,OU=Role Groups,OU=Groups,DC=it,DC=yourgloriousdomain,DC=com", ...]
    
    ```

1.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller

      pipeline :browser do
        plug Ueberauth
        ...
       end
    end
    ```

1.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

1. Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initiate the request through:
 
    /auth/pingfed

Or with options:

    /auth/pingfed?scope=openid
    
By default the requested scope is "openid". This provides both read and write access to the Pingfed user profile details and public repos. For a read-only scope, either use "user:email" or an empty scope "". See more at [Pingfed's OAuth Documentation](https://documentation.pingidentity.com/pingfederate/pf83/#adminGuide/concept/scopes.html). Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    pingfed: {Ueberauth.Strategy.Pingfed, [default_scope: "openid"]}
  ]
```

It is also possible to disable the sending of the `redirect_uri` to Pingfed. This is particularly useful
when your production application sits behind a proxy that handles SSL connections. In this case,
the `redirect_uri` sent by `Ueberauth` will start with `http` instead of `https`, and if you configured
your Pingfed OAuth application's callback URL to use HTTPS, Pingfed will throw an `uri_missmatch` error.

To prevent `Ueberauth` from sending the `redirect_uri`, you should add the following to your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    pingfed: {Ueberauth.Strategy.Pingfed, [send_redirect_uri: false]}
  ]
```

### Improvements for the future

**PRs are welcome!**

The `relevant_groups` list is the literal value of the Active Directory Group name that application may care about to establish the Application Specific roles. The list of all  users AD groups, coming from Ping Federate, will be filtered using this list. Only one matched will be left in `memeber_of` list. 

TODO Change the design To have `relevant_groups` as _map_ of the `Application Role` => `List of groups the user has to belong to`:

```elixir
[ admin: [
    "CN=ThisAppAdmin,OU=Role Groups,OU=Groups,DC=yourgloriousdomain,DC=com", 
    "CN=Admin,OU=Role Groups,OU=Groups,DC=it,DC=yourgloriousdomain,DC=com"
    ], 
 sales: [
    "CN=Sales,OU=Role Groups,OU=Groups,DC=yourgloriousdomain,DC=com",
    "CN=Sales Manager,OU=West,OU=Role Groups,OU=Groups,DC=it,DC=yourgloriousdomain,DC=com"
   ]
]
```
The logic has to change here: 
https://github.com/borodark/ueberauth_pingfed/blob/master/lib/ueberauth/strategy/pingfed.ex#L164 

This way the aplication specific roles can be calculated at the succesfull login.



## License

Please see [LICENSE](https://pingfed.com/ueberauth/ueberauth_pingfed/blob/master/LICENSE) for licensing details.
