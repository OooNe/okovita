defmodule Okovita.FieldTypes.Url do
  @moduledoc "URL field type — composite %{\"label\" => ..., \"url\" => ...} stored as a JSON map."
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def value_type, do: :map

  @impl true
  def list_compatible?, do: true

  @impl true
  def cast(%{"url" => url} = value) when is_map(value) and is_binary(url),
    do: {:ok, normalize(value)}

  def cast(nil), do: {:ok, nil}
  def cast(%{}), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, _options) do
    # Normalize URL (add https:// if missing) before running format check.
    changeset =
      case get_field(changeset, field_name) do
        value when is_map(value) -> put_change(changeset, field_name, normalize(value))
        _ -> changeset
      end

    validate_change(changeset, field_name, fn _, value ->
      url = Map.get(value, "url", "")

      if url == "" or Regex.match?(~r/^https?:\/\//, url) do
        []
      else
        [{field_name, "must be a valid URL"}]
      end
    end)
  end

  @impl true
  def merge_validate_params(field_name, params, current_data) do
    case Map.get(params, field_name) do
      value when is_map(value) -> Map.put(current_data, field_name, normalize(value))
      _ -> current_data
    end
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp normalize(%{"url" => url} = value) when is_binary(url) do
    trimmed = String.trim(url)

    normalized_url =
      cond do
        trimmed == "" -> ""
        String.starts_with?(trimmed, ["http://", "https://"]) -> trimmed
        true -> "https://#{trimmed}"
      end

    Map.put(value, "url", normalized_url)
  end

  defp normalize(value), do: value
end
