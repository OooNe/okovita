defmodule Okovita.FileCache do
  @moduledoc """
  A generic, system-wide file-based caching module.
  Used internally for optimizing expensive generation operations like image processing.
  """

  @doc """
  Attempts to retrieve a file from the given directory by key.
  If the file doesn't exist, it executes the provided `generator_fn`,
  saves the binary result to disk, and returns it.

  The generator function is expected to return `{:ok, binary}` on success,
  or an `{:error, reason}` tuple.
  """
  def get_or_create(dir, key, generator_fn) do
    File.mkdir_p!(dir)
    cache_path = Path.join(dir, key)

    if File.exists?(cache_path) do
      {:ok, File.read!(cache_path)}
    else
      case generator_fn.() do
        {:ok, binary} ->
          File.write!(cache_path, binary)
          {:ok, binary}

        error ->
          error
      end
    end
  end
end
