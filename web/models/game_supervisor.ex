defmodule Pokerboy.Gamesupervisor do
    use Supervisor
    def start_link do
        # We are now registering our supervisor process with a name
        # so we can reference it in the `start_game/1` function
        Supervisor.start_link(__MODULE__, [], name: :game_supervisor)
    end

    def start_game(opts) do
        # And we use `start_child/2` to start a new Pokerboy.Gameserver process
        Supervisor.start_child(:game_supervisor, [opts])
    end

    def init(_) do
        children = [
            worker(Pokerboy.Gameserver, [])
        ]
        # We also changed the `strategty` to `simple_one_for_one`.
        # With this strategy, we define just a "template" for a child,
        # no process is started during the Supervisor initialization,
        # just when we call `start_child/2`
        supervise(children, strategy: :simple_one_for_one)
    end
end