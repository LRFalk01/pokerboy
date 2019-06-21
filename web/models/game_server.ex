defmodule Pokerboy.Gameserver do
  @moduledoc """
  The main controller and holder of state for each game
  """

  use GenServer
  defstruct users: %{}, password: nil, is_showing: false, last_action: Timex.now()
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

    {:ok, %__MODULE__{password: opts.password}}
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
    inactive_hours = Timex.diff(Timex.now(), state.last_action, :hours)

    state =
      if inactive_hours > 2 do
        put_in(state.users, %{})
      else
        state
      end

    {:noreply, state}
  end

  def handle_call({:user_join, name}, _from, state) do
    uuid = Ecto.UUID.generate()
    user = %Pokerboy.Player{id: uuid, name: name}

    # first player to join is admin
    user =
      if state.users |> Map.keys() |> Enum.count() == 0 do
        put_in(user.is_admin, true)
      else
        user
      end

    state = %{state | users: Map.put(state.users, uuid, user)} |> decide_reveal
    {:reply, %{uuid: uuid, state: state}, state}
  end

  def handle_call({:user_available, username}, _from, state) do
    available =
      state.users
      |> Map.values()
      |> Enum.all?(fn user -> user.name != username end)

    {:reply, available, state}
  end

  def handle_call({:become_admin, %{user: user, password: password}}, _from, state) do
    promote_user = state.users |> Map.values() |> Enum.find(fn x -> x.name == user end)

    cond do
      state.password != password ->
        {:reply, %{status: :error, message: "invalid password"}, state}

      promote_user == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}

      true ->
        state = put_in(state.users[promote_user.id].is_admin, true)
        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:user_promote, %{admin: admin, user: user}}, _from, state) do
    if Map.has_key?(state.users, admin) || !state.users[admin].is_admin do
      handle_call({:become_admin, %{user: user, password: state.password}}, {}, state)
    else
      {:reply, %{status: :error, message: "invalid admin"}, state}
    end
  end

  def handle_call({:toggle_playing, %{requester: user_uuid, user: name}}, _from, state) do
    toggle_user = state.users |> Map.values() |> Enum.find(fn x -> x.name == name end)

    cond do
      !Map.has_key?(state.users, user_uuid) ||
          !(state.users[user_uuid].is_admin || state.users[user_uuid].name == name) ->
        {:reply, %{status: :error, message: "invalid requester"}, state}

      toggle_user == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}

      true ->
        state =
          decide_reveal(put_in(state.users[toggle_user.id].is_player, !toggle_user.is_player))

        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:kick_player, %{requester: user_uuid, user: name}}, _from, state) do
    toggle_user = state.users |> Map.values() |> Enum.find(fn x -> x.name == name end)

    cond do
      !Map.has_key?(state.users, user_uuid) ||
          !state.users[user_uuid].is_admin ->
        {:reply, %{status: :error, message: "invalid requester"}, state}

      toggle_user == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}

      true ->
        users = Map.delete(state.users, toggle_user.id)

        state = decide_reveal(put_in(state.users, users))
        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:reveal, user_uuid}, _from, state) do
    cond do
      !Map.has_key?(state.users, user_uuid) ->
        {:reply, %{status: :error, message: "invalid user"}, state}

      state.users[user_uuid].is_admin == false ->
        {:reply, %{status: :error, message: "invalid requester"}, state}

      true ->
        state = put_in(state.is_showing, true)
        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:reset, user_uuid}, _from, state) do
    cond do
      !Map.has_key?(state.users, user_uuid) ->
        {:reply, %{status: :error, message: "invalid user"}, state}

      state.users[user_uuid].is_admin == false ->
        {:reply, %{status: :error, message: "invalid requester"}, state}

      true ->
        users =
          state.users
          |> Map.values()
          |> Enum.map(fn x -> %{x | vote: nil, original_vote: nil} end)
          |> Map.new(fn x -> {x.id, x} end)

        state = decide_reveal(%{state | is_showing: false, users: users})
        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:leave, user_uuid}, _from, state) do
    if Map.has_key?(state.users, user_uuid) do
      users = Map.delete(state.users, user_uuid)
      state = decide_reveal(%{state | users: users})
      {:reply, %{status: :ok, state: state}, state}
    else
      {:reply, %{status: :error, message: "invalid user"}, state}
    end
  end

  def handle_call({:user_vote, %{user: _, vote: vote}}, _from, state)
      when not (vote in @valid_votes) do
    {:reply, %{status: :error, message: "invalid vote"}, state}
  end

  def handle_call({:user_vote, %{user: user_uuid, vote: vote}}, _from, state)
      when vote in @valid_votes do
    if Map.has_key?(state.users, user_uuid) do
      state =
        if state.is_showing do
          state
        else
          put_in(state.users[user_uuid].original_vote, vote)
        end

      state = decide_reveal(put_in(state.users[user_uuid].vote, vote))
      {:reply, %{status: :ok, state: state}, state}
    else
      {:reply, %{status: :error, message: "invalid user"}, state}
    end
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, %{status: :ok, state: state}, state}
  end

  defp decide_reveal(%Pokerboy.Gameserver{} = state) do
    state = put_in(state.last_action, Timex.now())

    cond do
      !(state.users |> Map.values() |> Enum.filter(fn x -> x.is_player end) |> Enum.any?()) ->
        state

      state.is_showing ->
        state

      true ->
        should_reveal? =
          state.users
          |> Map.values()
          |> Enum.filter(fn x -> x.is_player end)
          |> Enum.all?(fn x -> x.vote != nil end)

        put_in(state.is_showing, should_reveal?)
    end
  end
end
