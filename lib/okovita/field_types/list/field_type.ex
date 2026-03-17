defmodule Okovita.FieldTypes.List do
  @moduledoc """
  List field type. Stores an array of strings (text/textarea) or maps (url subtype).

  ## Configuration

      %{
        "tags" => %{
          "field_type"   => "list",
          "label"        => "Tags",
          "required"     => false,
          "list_subtype" => "text",     # "text" | "textarea" | "url"
          "min_items"    => 0,
          "max_items"    => 10,
          "min_length"   => 2,          # per-item validation (string subtypes only)
          "max_length"   => 100,        # per-item validation (string subtypes only)
          "validation_regex" => nil     # per-item validation (string subtypes only)
        }
      }
  """
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def value_type, do: {:array, :string}

  # When subtype is "url", items are %{"label" => ..., "url" => ...} maps.
  @impl true
  def value_type(%{"list_subtype" => "url"}), do: {:array, :map}
  def value_type(_), do: {:array, :string}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast([]), do: {:ok, []}

  def cast(value) when is_list(value) do
    cleaned =
      value
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn
        s when is_binary(s) -> String.trim(s)
        m when is_map(m) -> m
        _ -> nil
      end)
      |> Enum.reject(&(&1 == "" or is_nil(&1)))

    {:ok, cleaned}
  end

  def cast(_), do: :error

  @impl true
  def validate(changeset, field_name, options) do
    changeset
    |> maybe_validate_min_items(field_name, options)
    |> maybe_validate_max_items(field_name, options)
    |> validate_items(field_name, options)
  end

  @impl true
  def form_assigns(field_name, field_def, assigns) do
    %{
      value: Map.get(assigns.data, field_name) || [],
      subtype: field_def["list_subtype"] || "text"
    }
  end

  @impl true
  def merge_validate_params(field_name, params, current_data) do
    case Map.get(params, field_name) do
      # URL subtype: Plug produces a string-indexed map like %{"0" => %{...}, "1" => %{...}}
      value when is_map(value) ->
        items =
          value
          |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
          |> Enum.map(fn {_, v} -> v end)
          |> Enum.reject(&url_item_empty?/1)

        Map.put(current_data, field_name, items)

      # Text/textarea subtype: plain list
      value when is_list(value) ->
        cleaned = Enum.reject(value, &(&1 == "" or is_nil(&1)))
        Map.put(current_data, field_name, cleaned)

      nil ->
        current_data
    end
  end

  @impl true
  def default_value, do: []

  # ── Private ─────────────────────────────────────────────────────────────────

  defp url_item_empty?(%{"label" => label, "url" => url}),
    do: (label == "" or is_nil(label)) and (url == "" or is_nil(url))

  defp url_item_empty?(_), do: false

  defp maybe_validate_min_items(changeset, field_name, options) do
    case options["min_items"] do
      nil -> changeset
      min when is_integer(min) -> validate_length(changeset, field_name, min: min)
      _ -> changeset
    end
  end

  defp maybe_validate_max_items(changeset, field_name, options) do
    case options["max_items"] do
      nil -> changeset
      max when is_integer(max) -> validate_length(changeset, field_name, max: max)
      _ -> changeset
    end
  end

  defp validate_items(changeset, field_name, options) do
    validate_change(changeset, field_name, fn _, items ->
      items
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {item, index} ->
        case validate_item(item, options) do
          [] -> []
          errors -> Enum.map(errors, fn msg -> {field_name, "item #{index}: #{msg}"} end)
        end
      end)
    end)
  end

  # URL map items — validate the url portion only
  defp validate_item(%{"url" => url}, _options) when is_binary(url) do
    if url == "" or Regex.match?(~r/^https?:\/\//, url),
      do: [],
      else: ["must be a valid URL"]
  end

  defp validate_item(item, options) when is_binary(item) do
    []
    |> check_min_length(item, options)
    |> check_max_length(item, options)
    |> check_regex(item, options)
  end

  defp validate_item(_, _), do: []

  defp check_min_length(errors, item, %{"min_length" => min}) when is_integer(min) do
    if String.length(item) < min,
      do: ["must be at least #{min} characters" | errors],
      else: errors
  end

  defp check_min_length(errors, _item, _options), do: errors

  defp check_max_length(errors, item, %{"max_length" => max}) when is_integer(max) do
    if String.length(item) > max,
      do: ["must be at most #{max} characters" | errors],
      else: errors
  end

  defp check_max_length(errors, _item, _options), do: errors

  defp check_regex(errors, item, %{"validation_regex" => pattern})
       when is_binary(pattern) and pattern != "" do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        if Regex.match?(regex, item),
          do: errors,
          else: ["does not match the required pattern" | errors]

      {:error, _} ->
        errors
    end
  end

  defp check_regex(errors, _item, _options), do: errors
end
