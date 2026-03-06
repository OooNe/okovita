defmodule Okovita.Content.ImageProcessor do
  @moduledoc """
  Module responsible for performing image processing operations using Vix/Image.
  Mainly used by the media proxy to apply transformations like resize, blur and change quality.
  """

  @allowed_widths [100, 200, 300, 400, 600, 800, 1200, 1600]
  @allowed_heights [100, 200, 300, 400, 600, 800, 1200, 1600]
  @allowed_qualities [50, 60, 70, 80, 90, 100]

  @cache_dir "priv/static/cache/media"

  @type image_opts :: %{
          optional(:w) => pos_integer() | nil,
          optional(:h) => pos_integer() | nil,
          optional(:q) => pos_integer(),
          optional(:blur) => pos_integer() | nil,
          optional(:fit) => String.t()
        }

  @doc """
  Gets a processed image from cache or processes from URL if it's not cached.
  Also performs validation on the raw parameters.
  """
  @spec get_or_process_image(String.t(), String.t(), map()) ::
          {:ok, binary(), String.t()} | {:error, atom(), String.t()} | {:error, any()}
  def get_or_process_image(id, url, raw_params) do
    with {:ok, opts} <- validate_params(raw_params),
         cache_key <- build_cache_key(id, opts),
         {:ok, binary} <-
           Okovita.FileCache.get_or_create(@cache_dir, cache_key, fn ->
             process_from_url(url, opts)
           end) do
      {:ok, binary, mime_from_path(cache_key)}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, :bad_request, reason}

      error ->
        error
    end
  end

  @spec process_from_url(String.t(), image_opts()) :: {:ok, binary()} | {:error, any()}
  defp process_from_url(url, opts) do
    with {:ok, image} <- fetch_and_open_image(url),
         {:ok, processed_image} <- process_image(image, opts),
         {:ok, binary} <- Image.write(processed_image, :memory, suffix: ".webp", quality: opts.q) do
      {:ok, binary}
    end
  end

  @spec fetch_and_open_image(String.t()) :: {:ok, Vix.Vips.Image.t()} | {:error, :fetch_failed}
  defp fetch_and_open_image(url) do
    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Image.from_binary(body)

      _ ->
        {:error, :fetch_failed}
    end
  end

  @spec process_image(Vix.Vips.Image.t(), image_opts()) :: {:ok, Vix.Vips.Image.t()}
  defdelegate process_image(image, opts), to: Okovita.Content.ImageTransformer

  @spec validate_params(map()) :: {:ok, image_opts()} | {:error, String.t()}
  defp validate_params(params) do
    types = %{
      w: :integer,
      h: :integer,
      q: :integer,
      blur: :integer,
      fit: :string
    }

    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_inclusion(:w, @allowed_widths)
      |> Ecto.Changeset.validate_inclusion(:h, @allowed_heights)
      |> Ecto.Changeset.validate_inclusion(:q, @allowed_qualities)
      |> Ecto.Changeset.validate_number(:blur,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 100
      )
      |> Ecto.Changeset.validate_inclusion(:fit, ["contain", "cover"])

    if changeset.valid? do
      opts = Ecto.Changeset.apply_changes(changeset)
      opts = Map.merge(%{q: 80, fit: "contain"}, opts)
      {:ok, opts}
    else
      [{field, {msg, _meta}} | _] = changeset.errors

      {:error, "Invalid parameter '#{field}' - #{msg}"}
    end
  end

  defp build_cache_key(id, opts) do
    parts = [
      id,
      "w#{opts.w || "nil"}",
      "h#{opts.h || "nil"}",
      "q#{opts.q}",
      "b#{opts.blur || "0"}",
      "f#{opts.fit}"
    ]

    "#{Enum.join(parts, "_")}.webp"
  end

  defp mime_from_path(path) do
    if String.ends_with?(path, ".webp"), do: "image/webp", else: "image/jpeg"
  end
end
