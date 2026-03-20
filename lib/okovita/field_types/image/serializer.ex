defmodule Okovita.FieldTypes.Image.Serializer do
  @moduledoc """
  Serializer for the Image field type.
  Constructs a standard JSON object containing UUID, URL and basic metadata for an Image object.
  """

  def format(%Okovita.Content.Media{} = media, _options) do
    media_json(media)
  end

  def format(id, _options) when is_binary(id) do
    %{"id" => id}
  end

  def format(other, _options), do: other

  import OkovitaWeb.FormatHelpers, only: [proxy_url: 2]

  defp media_json(media) do
    %{
      "id" => media.id,
      "url" => proxy_url(media, w: 1600),
      "original_url" => media.url,
      "file_name" => media.file_name,
      "mime_type" => media.mime_type,
      "width" => media.width,
      "height" => media.height
    }
  end
end
