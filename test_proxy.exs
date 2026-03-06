defmodule TestProxy do
  def run do
    conn = %Plug.Conn{
      params: %{"bucket" => "okovita-content", "filename" => "blah", "w" => "100"},
      query_params: %{"w" => "100"}
    }
    
    proc_params = Map.drop(conn.params, ["bucket", "filename"])
    IO.inspect(proc_params, label: "Dropped params")
    IO.puts("Size: #{map_size(proc_params)}")
  end
end
TestProxy.run()
