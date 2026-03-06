defmodule OkovitaWeb.MediaProxyController do
  use OkovitaWeb, :controller

  def show(conn, %{"bucket" => bucket, "filename" => filename} = params) do
    proc_params = extract_proc_params(params)

    if proc_params == :empty do
      # No processing parameters -> redirect directly to S3
      public_s3_url = build_s3_url(bucket, filename, :public)
      redirect(conn, external: public_s3_url)
    else
      id_part = Path.rootname(filename)
      internal_s3_url = build_s3_url(bucket, filename, :internal)

      case Okovita.Content.ImageProcessor.get_or_process_image(
             id_part,
             internal_s3_url,
             proc_params
           ) do
        {:ok, binary, mime_type} ->
          conn
          |> put_resp_header("cache-control", "public, max-age=31536000")
          |> put_resp_content_type(mime_type)
          |> send_resp(200, binary)

        {:error, :bad_request, reason} ->
          send_resp(conn, 400, "Bad request: #{reason}")

        {:error, :fetch_failed} ->
          send_resp(conn, 404, "Original image not found")

        {:error, _reason} ->
          send_resp(conn, 500, "Internal server error")
      end
    end
  end

  defp build_s3_url(bucket, filename, type) do
    s3_config = Application.get_env(:ex_aws, :s3, [])

    # ExAws configuration usually defines "scheme" as "https://" or "http://"
    scheme_str = Keyword.get(s3_config, :scheme, "https://")
    scheme = String.replace(scheme_str, "://", "")

    %URI{
      scheme: scheme,
      host: resolve_host(type, s3_config),
      port: Keyword.get(s3_config, :port),
      path: "/#{bucket}/#{filename}"
    }
    |> URI.to_string()
  end

  defp resolve_host(:public, config) do
    if Okovita.dev?() do
      "localhost"
    else
      resolve_host(:internal, config)
    end
  end

  defp resolve_host(:internal, config) do
    Keyword.get(config, :host) || Application.get_env(:okovita, :s3_host)
  end

  defp extract_proc_params(params) do
    # Only pick parameters that actually matter for image processing
    proc_params = Map.take(params, ["w", "h", "q", "blur", "fit"])

    # If none of the processing parameters were provided (or all are empty strings/nil)
    is_empty? = Enum.all?(proc_params, fn {_k, v} -> v == "" or is_nil(v) end)

    if map_size(proc_params) == 0 or is_empty? do
      :empty
    else
      proc_params
    end
  end
end
