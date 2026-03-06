defmodule OkovitaWeb.FormatHelpers do
  @moduledoc """
  Generic presentation helpers for formatting values in templates.
  """

  @doc "Formats a byte size into a human-readable string (B / KB / MB)."
  def format_size(nil), do: "0 B"
  def format_size(size) when size < 1_024, do: "#{size} B"
  def format_size(size) when size < 1_048_576, do: "#{Float.round(size / 1_024, 1)} KB"
  def format_size(size), do: "#{Float.round(size / 1_048_576, 2)} MB"

  @doc """
  Generates a proxy URL for a given media item (containing `file_name`)
  or string URL, with optional processing parameters.

  Example:
      proxy_url(item, w: 200, fit: "cover")
      proxy_url("http://s3.../bucket/file.jpg", w: 200)
  """
  def proxy_url(subject, opts \\ [])

  def proxy_url(%{file_name: file_name}, opts) do
    bucket = Application.get_env(:okovita, :s3_bucket, "okovita-content")
    path = "/media/#{bucket}/#{file_name}"
    build_proxy_url(path, opts)
  end

  def proxy_url(url, opts) when is_binary(url) do
    uri = URI.parse(url)

    path =
      if String.starts_with?(uri.path || "", "/media") do
        uri.path
      else
        "/media" <> (uri.path || "")
      end

    build_proxy_url(path, opts)
  end

  def proxy_url(nil, _opts), do: nil

  defp build_proxy_url(path, opts) do
    base_url = OkovitaWeb.Endpoint.url()
    query = URI.encode_query(opts)

    if query == "" do
      "#{base_url}#{path}"
    else
      "#{base_url}#{path}?#{query}"
    end
  end
end
