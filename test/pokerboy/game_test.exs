defmodule Pokerboy.GameTest do
  use ExUnit.Case, async: true
  alias Pokerboy.{Game, Player}

  @password "thepassword"
  @player %{Player.new("player") | is_player: true, vote: "1", original_vote: "1"}
  @admin %{Player.new("admin") | is_admin: true}
  @another %{Player.new("another") | is_player: true}
  @users %{@player.id => @player, @admin.id => @admin, @another.id => @another}

  setup _ do
    {:ok, game: Game.new(@password)}
  end

  def load_some_players(%{game: game}) do
    {:ok, game: put_in(game.users, @users)}
  end

  def last_action_3_hours_ago(%{game: game}) do
    {:ok, game: put_in(game.last_action, DateTime.utc_now() |> DateTime.add(-60 * 60 * 3))}
  end

  describe "time_from_last_action/2" do
    setup :last_action_3_hours_ago

    test "can return granularity in hours", %{game: game} do
      assert 3 = Game.time_from_last_action(game, :hours)
    end

    test "can return granularity in minutes", %{game: game} do
      assert 180 = Game.time_from_last_action(game, :minutes)
    end

    test "can return granularity in seconds", %{game: game} do
      assert 180 * 60 == Game.time_from_last_action(game, :seconds)
    end
  end

  describe "add_new_user/2" do
    test "first user added is an admin", %{game: game} do
      {:ok, id, updated_game} = Game.add_new_user(game, "sinister")
      assert %Player{is_admin: true, name: "sinister"} = updated_game.users[id]
    end

    test "only first user added is an admin", %{game: game} do
      {:ok, _, first_update} = Game.add_new_user(game, "sinister")
      {:ok, id, second_update} = Game.add_new_user(first_update, "spock")
      assert %Player{is_admin: false, name: "spock"} = second_update.users[id]
    end

    test "attempting to add the same username twice fails", %{game: game} do
      {:ok, _, update} = Game.add_new_user(game, "sinister")
      assert {:error, "username unavailable"} = Game.add_new_user(update, "sinister")
    end
  end

  describe "kick_user/3" do
    setup :load_some_players

    test "an admin can kick another user", %{game: game} do
      {:ok, %{users: users}} = Game.kick_user(game, @admin.id, @player.name)
      refute users[@player.id]
    end

    test "an admin can't kick a non-found user", %{game: game} do
      assert {:error, "invalid user"} = Game.kick_user(game, @admin.id, "roflcopter")
    end

    test "a non-admin can't kick anyone", %{game: game} do
      assert {:error, "invalid requester"} = Game.kick_user(game, @player.id, @another.name)
    end
  end

  describe "promote_admin/3" do
    setup :load_some_players

    test "an admin may promote another user to admin", %{game: game} do
      refute game.users[@player.id].is_admin
      assert {:ok, %{users: users}} = Game.promote_admin(game, @admin.id, @player.name)
      assert users[@player.id].is_admin
    end

    test "a non-admin may not promote another user", %{game: game} do
      {:error, "invalid admin"} = Game.promote_admin(game, @another.id, @player.name)
    end
  end

  describe "become_admin/3" do
    setup :load_some_players

    test "any user may join with the password", %{game: game} do
      refute game.users[@player.id].is_admin
      {:ok, %{users: users}} = Game.become_admin(game, @password, @player.name)
      assert users[@player.id].is_admin
    end

    test "bad password errors", %{game: game} do
      assert {:error, "invalid password"} = Game.become_admin(game, "roflcopter", @player.name)
    end
  end

  describe "remove_user_by_id/2" do
    setup :load_some_players

    test "removing a user blocking vote showing reveals votes", %{game: game} do
      refute game.is_showing
      assert {:ok, updated} = Game.remove_user_by_id(game, @another.id)
      assert updated.is_showing
      refute updated.users[@another.id]
    end

    test "errors with invalid id", %{game: game} do
      assert {:error, "invalid user"} = Game.remove_user_by_id(game, "wat")
    end
  end

  describe "force_reveal/2" do
    setup :load_some_players

    test "an admin can force showing", %{game: game} do
      refute game.is_showing
      {:ok, updated} = Game.force_reveal(game, @admin.id)
      assert updated.is_showing
    end

    test "a normal user cannot force reveal", %{game: game} do
      assert {:error, "invalid requester"} = Game.force_reveal(game, @player.id)
    end
  end

  describe "reset_votes/2" do
    setup :load_some_players

    test "an admin can reset votes", %{game: game} do
      assert game.users[@player.id].vote
      assert game.users[@player.id].original_vote
      showing = %{game | is_showing: true}
      {:ok, updated} = Game.reset_votes(showing, @admin.id)
      refute updated.users[@player.id].vote
      refute updated.users[@player.id].original_vote
      refute updated.is_showing
    end

    test "a normal user cannot reset votes", %{game: game} do
      assert {:error, "invalid requester"} = Game.reset_votes(game, @player.id)
    end
  end

  describe "vote_for_user_id/3" do
    setup :load_some_players

    test "will automatically reveal for last vote", %{game: game} do
      refute game.is_showing
      {:ok, updated} = Game.vote_for_user_id(game, @another.id, "3")
      assert updated.is_showing
    end

    test "updates both vote and orginal vote if game isn't showing", %{game: game} do
      refute game.is_showing
      {:ok, updated} = Game.vote_for_user_id(game, @player.id, "3")
      refute updated.is_showing
      assert updated.users[@player.id].vote == "3"
      assert updated.users[@player.id].original_vote == "3"
    end

    test "only updates vote if game is showing", %{game: game} do
      showing = %{game | is_showing: true}
      {:ok, updated} = Game.vote_for_user_id(showing, @player.id, "3")
      assert updated.users[@player.id].vote == "3"
      assert updated.users[@player.id].original_vote == "1"
    end

    test "errors on invalid user id", %{game: game} do
      assert {:error, "invalid user"} = Game.vote_for_user_id(game, "wat", "3")
    end
  end

  describe "toggle_playing/3" do
    setup :load_some_players

    test "any player can toggle themself", %{game: game} do
      assert game.users[@player.id].is_player
      {:ok, updated} = Game.toggle_playing(game, @player.id, @player.name)
      refute updated.users[@player.id].is_player
    end

    test "a non admin cannot toggle another player", %{game: game} do
      {:error, "invalid requester"} = Game.toggle_playing(game, @player.id, @another.name)
    end

    test "an admin may toggle another player", %{game: game} do
      assert game.users[@player.id].is_player
      {:ok, updated} = Game.toggle_playing(game, @admin.id, @player.name)
      refute updated.users[@player.id].is_player
    end

    test "reveals votes if toggled player was remaing player unvoted", %{game: game} do
      refute game.is_showing
      {:ok, updated} = Game.toggle_playing(game, @another.id, @another.name)
      assert updated.is_showing
    end
  end
end
