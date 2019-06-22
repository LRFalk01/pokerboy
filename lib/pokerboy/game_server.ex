defmodule Pokerboy.GameServer do
  @moduledoc """
  The main controller and holder of state for each game
  """

  use GenServer
  alias Pokerboy.Game

  @valid_votes [nil | Application.get_env(:pokerboy, __MODULE__)[:valid_votes]]

  # API
  def valid_votes() do
    %{status: :ok, valid_votes: @valid_votes}
  end

  def user_available?(game_uuid, username) do
    GenServer.call(via_tuple(game_uuid), {:user_available, username})
  end

  def user_join(game_uuid, user) do
    GenServer.call(via_tuple(game_uuid), {:user_join, user})
  end

  def become_admin(game_uuid, user_uuid, password) do
    GenServer.call(via_tuple(game_uuid), {:become_admin, %{user: user_uuid, password: password}})
  end

  def user_promote(game_uuid, admin_uuid, user) do
    GenServer.call(via_tuple(game_uuid), {:user_promote, %{admin: admin_uuid, user: user}})
  end

  def user_vote(game_uuid, user_uuid, vote) do
    GenServer.call(via_tuple(game_uuid), {:user_vote, %{user: user_uuid, vote: vote}})
  end

  def toggle_playing(game_uuid, user_uuid, name) do
    GenServer.call(via_tuple(game_uuid), {:toggle_playing, %{requester: user_uuid, user: name}})
  end

  def kick_player(game_uuid, user_uuid, name) do
    GenServer.call(via_tuple(game_uuid), {:kick_player, %{requester: user_uuid, user: name}})
  end

  def reveal(game_uuid, user_uuid) do
    GenServer.call(via_tuple(game_uuid), {:reveal, user_uuid})
  end

  def reset(game_uuid, user_uuid) do
    GenServer.call(via_tuple(game_uuid), {:reset, user_uuid})
  end

  def leave(game_uuid, user_uuid) do
    GenServer.call(via_tuple(game_uuid), {:leave, user_uuid})
  end

  def get_state(game_uuid) do
    GenServer.call(via_tuple(game_uuid), {:get_state})
  end

  def game_exists?(game_uuid) do
    case :gproc.where({:n, :l, {:game_uuid, game_uuid}}) do
      :undefined -> false
      _ -> true
    end
  end

  # Server
  def init(opts) do
    :timer.send_interval(:timer.seconds(20), self(), :game_check)

    {:ok, Game.new(opts.password)}
  end

  def start_link(opts) do
    # Instead of passing an atom to the `name` option, we send
    # a tuple. Here we extract this tuple to a private method
    # called `via_tuple` that can be reused in every function
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts.uuid))
  end

  defp via_tuple(game_uuid) do
    # And the tuple always follow the same format:
    # {:via, module_name, term}
    {:via, :gproc, {:n, :l, {:game_uuid, game_uuid}}}
  end

  def handle_info(:game_check, state) do
    if Game.time_from_last_action(state, :hours) > 2 do
      {:noreply, Game.remove_all_users!(state)}
    else
      {:noreply, state}
    end
  end

  def handle_call({:user_join, name}, _from, state) do
    {uuid, updated} = Game.add_new_user(state, name)
    {:reply, %{uuid: uuid, state: updated}, updated}
  end

  def handle_call({:user_available, username}, _from, state) do
    {:reply, Game.username_available?(state, username), state}
  end

  def handle_call({:become_admin, %{user: username, password: password}}, _from, state) do
    game_change(state, Game.become_admin(state, password, username))
  end

  def handle_call({:user_promote, %{admin: admin, user: username}}, _from, state) do
    game_change(state, Game.promote_admin(state, admin, username))
  end

  def handle_call({:toggle_playing, %{requester: user_uuid, user: name}}, _from, state) do
    game_change(state, Game.toggle_playing(state, user_uuid, name))
  end

  def handle_call({:kick_player, %{requester: user_uuid, user: name}}, _from, state) do
    game_change(state, Game.kick_user(state, user_uuid, name))
  end

  def handle_call({:reveal, user_uuid}, _from, state) do
    game_change(state, Game.force_reveal(state, user_uuid))
  end

  def handle_call({:reset, user_uuid}, _from, state) do
    game_change(state, Game.reset_votes(state, user_uuid))
  end

  def handle_call({:leave, user_uuid}, _from, state) do
    game_change(state, Game.remove_user_by_id(state, user_uuid))
  end

  def handle_call({:user_vote, %{user: _, vote: vote}}, _from, state)
      when not (vote in @valid_votes) do
    {:reply, %{status: :error, message: "invalid vote"}, state}
  end

  def handle_call({:user_vote, %{user: user_uuid, vote: vote}}, _from, state)
      when vote in @valid_votes do
    game_change(state, Game.vote_for_user_id(state, user_uuid, vote))
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, %{status: :ok, state: state}, state}
  end

  ## Private Functions

  defp game_change(_, {:ok, updated}) do
    {:reply, %{status: :ok, state: updated}, updated}
  end

  defp game_change(state, {:error, reason}) do
    {:reply, %{status: :error, message: reason}, state}
  end
end
