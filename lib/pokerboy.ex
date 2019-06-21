defmodule Pokerboy do
  @moduledoc false
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      # supervisor(Pokerboy.Repo, []),
      # Start the endpoint when the application starts
      supervisor(Pokerboy.Endpoint, []),
      # Start your own worker by calling: Pokerboy.Worker.start_link(arg1, arg2, arg3)
      # worker(Pokerboy.Worker, [arg1, arg2, arg3]),
      supervisor(Pokerboy.Gamesupervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pokerboy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Pokerboy.Endpoint.config_change(changed, removed)
    :ok
  end
end
