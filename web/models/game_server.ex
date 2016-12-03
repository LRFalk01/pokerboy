defmodule Pokerboy.Gameserver do
  use GenServer
  defstruct name: nil, users: %{}, password: nil

  #API
  def get_name(game_uuid) do
    GenServer.call(via_tuple(game_uuid), :get_name)
  end

  def users_get(game_uuid) do
    GenServer.call(via_tuple(game_uuid), :user_get)
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

  def toggle_playing(game_uuid, user_uuid, name) do
    GenServer.call(via_tuple(game_uuid), {:toggle_playing, %{requester: user_uuid, user: name}})
  end

  def is_password?(game_uuid, password) do
    GenServer.call(via_tuple(game_uuid), {:is_password, password})
  end

  def users_leave(game_uuid, user) do
    GenServer.cast(via_tuple(game_uuid), {:user_part, user})
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
    state = %{ state | users: Map.put(state.users, uuid, user)}
    {:reply, uuid, state}
  end
  
  def handle_call(:user_get, _from, state) do
    {:reply, state.users, state}
  end 
  
  def handle_call({:user_available, username}, _from, state) do
    available = Map.values(state.users) 
      |> Enum.all?(fn(user) -> user.name != username end)
    {:reply, available, state}
  end    
  
  def handle_call({:is_password, password}, _from, state) do
    {:reply, state.password == password, state}
  end    

  def handle_call({:become_admin, %{user: user, password: password}}, _from, state) do
    promoteUser = Map.values(state.users) |> Enum.find(fn(x) -> x.name == user end)
    cond do
      state.password != password ->
        {:reply, %{status: :error, message: "invalid password"}, state}
      promoteUser == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        state = put_in(state.users[promoteUser.id].is_admin?, true)
        {:reply, %{status: :ok, message: state.users}, state}
    end
  end    

  def handle_call({:user_promote, %{admin: admin, user: user}}, _from, state) do
    cond do
      !Map.has_key?(state.users, admin) || !state.users[admin].is_admin? ->
        {:reply, %{status: :error, message: "invalid admin"}, state}
      true ->
        handle_call({:become_admin, %{user: user, password: state.password}}, {}, state)
    end
  end    
  
  def handle_call({:toggle_playing, %{requester: user_uuid, user: name}}, _from, state) do
    toggleUser = Map.values(state.users) |> Enum.find(fn(x) -> x.name == name end)
    cond do
      !Map.has_key?(state.users, user_uuid) || 
      !(state.users[user_uuid].is_admin? || state.users[user_uuid].name == name) ->
        {:reply, %{status: :error, message: "invalid requester"}, state}
      toggleUser == nil ->
        {:reply, %{status: :error, message: "invalid user"}, state}
      true ->
        state = put_in(state.users[toggleUser.id].is_player?, !toggleUser.is_player?)
        {:reply, %{status: :ok, message: state.users}, state}
    end
  end    

  def handle_call(:get_name, _from, state) do
    {:reply, state.name, state}
  end
  
  def handle_cast({:user_part, user}, state) do
    {:noreply, %{ state | users: List.delete(state.users, user)}}
  end    
end