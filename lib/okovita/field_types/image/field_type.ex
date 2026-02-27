defmodule Okovita.FieldTypes.Image do
  @moduledoc """
  Image field type. Stores a UUID reference to a media record.
  """
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: :string

  @impl true
  def cast(value) when is_binary(value) do
    cleaned = String.trim(value)
    if cleaned == "", do: {:ok, nil}, else: {:ok, cleaned}
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset =
      validate_change(changeset, field_name, fn _, value ->
        if Ecto.UUID.cast(value) == :error do
          [{field_name, "is not a valid media reference"}]
        else
          []
        end
      end)

    if max_length = options["max_length"] do
      validate_length(changeset, field_name, max: max_length)
    else
      changeset
    end
  end

  @impl true
  def upload_config, do: {1, ~w(.jpg .jpeg .png .gif .webp)}

  @impl true
  def form_assigns(field_name, _field_def, assigns) do
    raw = Map.get(assigns.data, field_name)
    field_atom = String.to_existing_atom(field_name)

    %{
      upload: Map.get(assigns[:uploads] || %{}, field_atom),
      media_value: %{
        id: extract_id(raw),
        url: extract_url(raw)
      }
    }
  end

  # ── Normalization helpers ─────────────────────────────────────────────────────

  @doc """
  Extracts a media ID from a raw image field value.

  Accepts atom-key maps (from `populate_media`), string-key maps (from picker),
  or a bare UUID string (legacy).

  ## Examples

      iex> Okovita.FieldTypes.Image.extract_id(%{id: "uuid-123", url: "https://..."})
      "uuid-123"

      iex> Okovita.FieldTypes.Image.extract_id(%{"id" => "uuid-123"})
      "uuid-123"

      iex> Okovita.FieldTypes.Image.extract_id("uuid-123")
      "uuid-123"

      iex> Okovita.FieldTypes.Image.extract_id(nil)
      nil
  """
  @spec extract_id(any()) :: String.t() | nil
  def extract_id(%{"id" => id}) when is_binary(id) and id != "", do: id
  def extract_id(id) when is_binary(id) and id != "", do: id
  def extract_id(_), do: nil

  @doc """
  Extracts a display URL from a raw image field value.

  Returns the URL string, or `nil` if no URL is present.
  """
  @spec extract_url(any()) :: String.t() | nil
  def extract_url(%{"url" => url}) when is_binary(url) and url != "", do: url
  def extract_url(_), do: nil
end
