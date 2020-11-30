# Compares the Humio Plug to the Plug.Logger.
# It's a bit naive in that it uses a Test Conn,
# which might not be representative of the Conn object
# which it will be processing in a given application.

use Plug.Test
alias Logger.Backend.Humio

opts = Humio.Plug.init([])
conn = conn(:get, "/")
Logger.remove_backend(:console)

Benchee.run(%{
  Logger.Backend.Humio.Plug => fn ->
    conn
    |> Humio.Plug.call(opts)
    |> send_resp(200, "response_body")
  end,
  Plug.Logger => fn ->
    conn
    |> Plug.Logger.call(:info)
    |> send_resp(200, "response_body")
  end
})
