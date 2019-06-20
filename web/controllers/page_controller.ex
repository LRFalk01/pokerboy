defmodule Pokerboy.PageController do
  use Pokerboy.Web, :controller

  @index_contents File.read!("priv/static/index.html")

  def index(conn, _params) do
    html(conn, @index_contents)
  end
end
