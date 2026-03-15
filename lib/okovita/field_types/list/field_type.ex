defmodule Okovita.FieldTypes.List do
  @moduledoc """
  List field type. Stores an array of strings.

  ## Configuration

      %{
        "tags" => %{
          "field_type"   => "list",
          "label"        => "Tags",
          "required"     => false,
          "list_subtype" => "text",     # "text" | "textarea" | "url"
          "min_items"    => 0,
          "max_items"    => 10,
          "min_length"   => 2,          # per-item validation
          "max_length"   => 100,        # per-item validation
          "validation_regex" => nil     # per-item validation
        }
      }
  """
  use Okovita.FieldTypes.Base

  import Ecto.Changeset

  @impl true
  def primitive_type, do: {:array, :string}

  @impl true
  def cast(nil), do: {:ok, []}
  def cast([]), do: {:ok, []}

  def cast(value) when is_list(value) do
    cleaned =
      value
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn
        s when is_binary(s) -> String.trim(s)
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
    if Map.has_key?(params, field_name) do
      Map.put(current_data, field_name, Map.get(params, field_name, []))
    else
      current_data
    end
  end

  @impl true
  def default_value, do: []

  # --- private ---

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

  defp validate_item(item, options) do
    []
    |> check_min_length(item, options)
    |> check_max_length(item, options)
    |> check_regex(item, options)
  end

  defp check_min_length(errors, item, %{"min_length" => min}) when is_integer(min) do
    if String.length(item) < min do
      ["must be at least #{min} characters" | errors]
    else
      errors
    end
  end

  defp check_min_length(errors, _item, _options), do: errors

  defp check_max_length(errors, item, %{"max_length" => max}) when is_integer(max) do
    if String.length(item) > max do
      ["must be at most #{max} characters" | errors]
    else
      errors
    end
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
