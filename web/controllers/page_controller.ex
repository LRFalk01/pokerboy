defmodule Pokerboy.PageController do
  use Pokerboy.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
