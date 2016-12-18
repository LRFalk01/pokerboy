defmodule Pokerboy.Gameserver do
  use GenServer
  defstruct name: nil, users: %{}, password: nil, is_showing: false
  @valid_votes [nil | ~w(0 1 2 3 5 8 13 21 34 55 89 ?)]

  #API
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
       :undefined -> :false
       _ -> :true
     end
  end

  #Server
  def init(opts) do
    {:ok, %__MODULE__{name: opts.name, password: opts.password}}
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
      
  def handle_call({:user_join, name}, _from, state) do
    uuid = Ecto.UUID.generate()
    user = %Pokerboy.Player{id: uuid, name: name}
    state = %{ state | users: Map.put(state.users, uuid, user)} |> decide_reveal
    {:reply, %{uuid: uuid, state: state}, state}
  end
  
  def handle_call({:user_available, username}, _from, state) do
    available = Map.values(state.users) 
      |> Enum.all?(fn(user) -> user.name != username end)
    {:reply, available, state}
  end  

  def handle_call({:become_admin, %{user: user, password: password}}, _from, state) do
    promoteUser = Map.values(state.users) |> Enum.find(fn(x) -> x.name == user end)
    cond do
      state.password != password ->
        {:reply, %{status: :error, message: "invalid password"}, state}
      promoteUser == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        state = put_in(state.users[promoteUser.id].is_admin, true)
        {:reply, %{status: :ok, state: state}, state}
    end
  end    

  def handle_call({:user_promote, %{admin: admin, user: user}}, _from, state) do
    cond do
      !Map.has_key?(state.users, admin) || !state.users[admin].is_admin ->
        {:reply, %{status: :error, message: "invalid admin"}, state}
      true ->
        handle_call({:become_admin, %{user: user, password: state.password}}, {}, state)
    end
  end    
  
  def handle_call({:toggle_playing, %{requester: user_uuid, user: name}}, _from, state) do
    toggleUser = Map.values(state.users) |> Enum.find(fn(x) -> x.name == name end)
    cond do
      !Map.has_key?(state.users, user_uuid) || 
      !(state.users[user_uuid].is_admin || state.users[user_uuid].name == name) ->
        {:reply, %{status: :error, message: "invalid requester"}, state}
      toggleUser == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        state = put_in(state.users[toggleUser.id].is_player, !toggleUser.is_player) |> decide_reveal
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
        users = Map.values(state.users)
          |> Enum.map(fn(x) -> %{x | vote: nil, original_vote: nil} end)
          |> Map.new(fn(x) -> {x.id, x} end)
          
        state = put_in(state.is_showing, false)
        state = put_in(state.users, users) |> decide_reveal
        {:reply, %{status: :ok, state: state}, state}        
    end
  end

  def handle_call({:leave, user_uuid}, _from, state) do
    cond do
      !Map.has_key?(state.users, user_uuid) ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        users = Map.delete(state.users, user_uuid)
        state = put_in(state.users, users) |> decide_reveal
        {:reply, %{status: :ok, state: state}, state}        
    end
  end

  def handle_call({:user_vote, %{user: _, vote: vote}}, _from, state) when not(vote in @valid_votes) do 
    {:reply, %{status: :error, message: "invalid vote"}, state}
  end

  def handle_call({:user_vote, %{user: user_uuid, vote: vote}}, _from, state) when vote in @valid_votes do
    cond do
      !Map.has_key?(state.users, user_uuid) ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        #vote after board is already showing
        if !state.is_showing do
            state = put_in(state.users[user_uuid].original_vote, vote)
        end

        state = put_in(state.users[user_uuid].vote, vote) |> decide_reveal
        {:reply, %{status: :ok, state: state}, state}
    end
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, %{status: :ok, state: state}, state}
  end

  defp decide_reveal(state=%Pokerboy.Gameserver{}) do
    cond do
      !(Map.keys(state.users) |> Enum.any?) ->
        state
      state.is_showing ->
        state
      true ->
        should_reveal? = Map.values(state.users)
          |> Enum.filter(fn(x) -> x.is_player end)
          |> Enum.all?(fn(x) -> x.vote != nil end)
        
        put_in(state.is_showing, should_reveal?)
    end
  end
end