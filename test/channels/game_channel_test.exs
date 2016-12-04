defmodule Pokerboy.GameChannelTest do
  use Pokerboy.ChannelCase, async: true

  describe "joining lobby" do
    setup [:join_lobby]

    test "it's lobby can be joined", %{socket: socket} do
      assert socket.joined
    end  
  end

  describe "creating a game" do
    setup [:join_lobby, :create_game]

    test "it can create a game" do
      assert_push "created", %{uuid: _, password: _}
    end  

    test "it can join game channel" do
      assert_push "created", %{uuid: uuid}
      {_, socket: ref} = join_channel(uuid, %{"name" => "lucas"})
      
      assert ref.joined
      assert ref.assigns.game_id == uuid
      assert ref.assigns.user_id != nil
    end
  end
  
  describe "playing game" do
    setup [:join_lobby, :create_game, :join_game]

    test "it can become admin", %{socket: socket, password: password} do
      push socket, "become_admin", %{"password" => password} 
      assert_broadcast "game_update", %{status: :ok}
    end    

    test "it can promote user", %{socket: socket, password: password} do
      push socket, "become_admin", %{"password" => password} 
      assert_broadcast "game_update", %{status: :ok}

      {_, socket: _} = join_channel(socket.assigns.game_id, %{"name" => "lucas2"})
      
      push socket, "user_promote", %{"user" => "lucas2"}
      assert_broadcast "game_update", %{status: :ok}
    end

    test "it can toggle playing", %{socket: socket, password: password} do
      push socket, "become_admin", %{"password" => password} 
      assert_broadcast "game_update", %{status: :ok}

      {_, socket: _} = join_channel(socket.assigns.game_id, %{"name" => "lucas2"})
      
      push socket, "toggle_playing", %{"user" => "lucas2"}
      assert_broadcast "game_update", %{status: :ok}
    end

    test "it can vote", %{socket: socket, password: _} do
      push socket, "user_vote", %{"vote" => "5"} 
      assert_broadcast "game_update", %{status: :ok}
    end  

    test "it rejects invalid vote", %{socket: socket, password: _} do
      push socket, "user_vote", %{"vote" => ":)"} 
      assert_broadcast "game_update", %{status: :error}
    end  

    test "it does not show user votes", %{socket: socket, password: _} do
      {_, socket: _} = join_channel(socket.assigns.game_id, %{"name" => "lucas2"})
            
      push socket, "user_vote", %{"vote" => "5"} 
      assert_broadcast "game_update", %{status: :ok, state: state}

      assert state.users["lucas2"].vote == false
      assert state.users["lucas"].vote == true
    end

    test "it does show user votes on reveal", %{socket: socket, password: _} do            
      push socket, "user_vote", %{"vote" => "5"} 
      assert_broadcast "game_update", %{status: :ok, state: state}

      assert state.users["lucas"].vote == "5"
    end

    test "it can reveal", %{socket: socket, password: _} do
      push socket, "user_vote", %{"vote" => "5"} 
      assert_broadcast "game_update", %{status: :ok, state: state}
      
      assert state.is_showing? == true
    end  

    test "only admin can force reveal", %{socket: socket, password: _} do
      push socket, "reveal", %{} 
      assert_broadcast "game_update", %{status: :error, message: "invalid requester"}
    end  

    test "admin can force reveal", %{socket: socket, password: password} do
      push socket, "become_admin", %{"password" => password} 
      assert_broadcast "game_update", %{status: :ok}
      
      push socket, "reveal", %{} 
      assert_broadcast "game_update", %{status: :ok, state: state}
      
      assert state.is_showing? == true
    end

    test "only admin can reset", %{socket: socket, password: _} do
      push socket, "reset", %{} 
      assert_broadcast "game_update", %{status: :error, message: "invalid requester"}
    end  

    test "admin can reset", %{socket: socket, password: password} do
      push socket, "become_admin", %{"password" => password} 
      assert_broadcast "game_update", %{status: :ok}
      
      push socket, "user_vote", %{"vote" => "5"} 
      assert_broadcast "game_update", %{status: :ok}
      
      push socket, "reset", %{} 
      assert_broadcast "game_update", %{status: :ok, state: state}
      
      assert Map.values(state.users) |> Enum.all?(fn(x) -> x.vote == nil end)
    end

    test "it leaves on disconnect", %{socket: socket, password: _} do
      {_, socket: user2} = join_channel(socket.assigns.game_id, %{"name" => "lucas2"})
      
      Process.flag(:trap_exit, true)
      close(user2)
      socket_pid = user2.channel_pid
      assert_receive {:EXIT, ^socket_pid, {:shutdown, :closed}}
    
      assert_broadcast "game_update", %{status: :ok, state: state}

      assert !Map.has_key?(state.users, user2.assigns.user_id)
    end  
  end

  defp join_lobby(_), do: join_channel("lobby")

  defp join_channel(channel, params \\ %{}) do
    {:ok, _, socket} =
        socket("", %{})
        |> subscribe_and_join(Pokerboy.GameChannel, "game:" <> channel, params)
    {:ok, socket: socket}
  end

  defp create_game(%{socket: socket}) do
    push socket, "create", %{"name" => "foo"}
    {:ok, socket: socket}
  end

  defp join_game(%{socket: _}) do
    assert_push "created", %{uuid: uuid, password: password}
    {_, socket: user1} = join_channel(uuid, %{"name" => "lucas"})
    {:ok, socket: user1, password: password}
  end
end