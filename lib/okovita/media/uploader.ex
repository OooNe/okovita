defmodule Okovita.Media.Uploader do
  @moduledoc """
  Service for uploading files securely to AWS S3 / Localstack.
  """

  @doc """
  Uploads a temporary file to S3 and returns the public URL.
  """
  def upload(path, client_name, client_type) do
    file_ext = Path.extname(client_name)
    file_name = "#{Ecto.UUID.generate()}#{file_ext}"
    bucket = Application.get_env(:okovita, :s3_bucket, "okovita-content")

    file_binary = File.read!(path)

    # Upload to S3
    case ExAws.S3.put_object(bucket, file_name, file_binary,
           content_type: client_type,
           acl: :public_read
         )
         |> ExAws.request() do
      {:ok, _} ->
        ex_aws_config = ExAws.Config.new(:s3)
        scheme = ex_aws_config[:scheme] || "https://"

        public_host =
          if Application.get_env(:okovita, :env) == :dev ||
               System.get_env("MIX_ENV") == "dev",
             do: "localhost",
             else: ex_aws_config[:host] || "s3.amazonaws.com"

        port = if ex_aws_config[:port], do: ":#{ex_aws_config[:port]}", else: ""

        url = "#{scheme}#{public_host}#{port}/#{bucket}/#{file_name}"

        {:ok,
         %{url: url, file_name: file_name, size: byte_size(file_binary), mime_type: client_type}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an object from S3.
  """
  def delete(file_name) do
    bucket = Application.get_env(:okovita, :s3_bucket, "okovita-content")

    case ExAws.S3.delete_object(bucket, file_name) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
