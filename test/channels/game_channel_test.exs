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
      assert_push "created", %{uuid: _}
    end  

    test "it can join game channel" do
      assert_push "created", %{uuid: uuid}
      {_, socket: ref} = join_channel(uuid, %{"name" => "lucas"})
      assert ref.joined
      assert ref.assigns.game_id == uuid
      assert ref.assigns.user_id != nil
    end

    test "it can become admin" do
      assert_push "created", %{uuid: uuid, password: password}
      {_, socket: ref} = join_channel(uuid, %{"name" => "lucas"})
      assert ref.joined
      push ref, "become_admin", %{"password" => password} 
      assert_push "user_authenticated", %{status: :ok}
    end

    test "it can promote user" do
      assert_push "created", %{uuid: uuid, password: password}

      {_, socket: user1} = join_channel(uuid, %{"name" => "lucas"})
      assert user1.joined
      push user1, "become_admin", %{"password" => password} 
      assert_push "user_authenticated", %{status: :ok}

      {_, socket: _} = join_channel(uuid, %{"name" => "lucas2"})
      
      push user1, "user_promote", %{"user" => "lucas2"}
      assert_push "user_authenticated", %{status: :ok}
    end

    test "it can toggle playing" do
      assert_push "created", %{uuid: uuid, password: password}

      {_, socket: user1} = join_channel(uuid, %{"name" => "lucas"})
      assert user1.joined
      push user1, "become_admin", %{"password" => password} 
      assert_push "user_authenticated", %{status: :ok}

      {_, socket: _} = join_channel(uuid, %{"name" => "lucas2"})
      
      push user1, "toggle_playing", %{"user" => "lucas2"}
      assert_push "user_toggled", %{status: :ok}
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
    :ok
  end
end