defmodule Okovita.FieldTypes.ImageGallery.Serializer do
  @moduledoc """
  Serializer for the ImageGallery field type.
  Translates lists of maps representing images inside the system to user-facing lists
  of correctly formatted media JSONs.
  """

  def format(gallery, _options) when is_list(gallery) do
    Enum.map(gallery, fn
      %{"media" => %Okovita.Content.Media{} = media} = item ->
        Map.drop(item, ["media"]) |> Map.merge(media_json(media))

      item ->
        item
    end)
  end

  def format(other, _options), do: other

  defp media_json(media) do
    %{
      "id" => media.id,
      "url" => media.url,
      "file_name" => media.file_name,
      "mime_type" => media.mime_type
    }
  end
end
