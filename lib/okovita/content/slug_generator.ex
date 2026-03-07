defmodule Okovita.Content.SlugGenerator do
  @moduledoc """
  Dedykowany moduł odpowiedzialny za generowanie bazowych oraz
  unikalnych identyfikatorów (slugów) przydzielanych do wpisów
  dla zachowania prawidłowej architektury (SRP).
  """

  import Ecto.Query
  alias Okovita.Repo
  alias Okovita.Content.Entry
  alias Okovita.Pipeline.Sync.Slugify

  @doc """
  Buduje i ewentualnie agreguje (jeśli potrzeba unikalności) ostateczny
  adres w oparciu o przypisane cechy i zasady konkretnego modelu wpisu.
  """
  @spec build(map(), map(), map(), String.t()) :: String.t()
  def build(attrs, data, model, prefix) do
    if model.slug_field do
      target_value =
        Map.get(data, model.slug_field) || Map.get(data, String.to_atom(model.slug_field)) || ""

      {:ok, base_slug} = Slugify.apply(to_string(target_value), nil)
      generate_unique(model.id, base_slug, prefix)
    else
      Map.get(attrs, :slug) || Map.get(attrs, "slug")
    end
  end

  # --- Prywatne

  defp generate_unique(model_id, base_slug, prefix) do
    effective_base = get_effective_base(base_slug)

    if slug_exists?(model_id, effective_base, prefix) do
      append_next_suffix(model_id, effective_base, prefix)
    else
      effective_base
    end
  end

  defp get_effective_base(base_slug) when base_slug in ["", nil], do: "entry"
  defp get_effective_base(base_slug), do: base_slug

  defp slug_exists?(model_id, slug, prefix) do
    query =
      from e in Entry,
        where: e.model_id == ^model_id and e.slug == ^slug,
        select: 1,
        limit: 1

    Repo.one(query, prefix: prefix) != nil
  end

  defp append_next_suffix(model_id, base_slug, prefix) do
    pattern = "^#{base_slug}-([0-9]+)$"

    query =
      from e in Entry,
        where: e.model_id == ^model_id and fragment("? ~ ?", e.slug, ^pattern),
        select: max(fragment("substring(? from ?)::integer", e.slug, ^pattern))

    max_suffix = Repo.one(query, prefix: prefix) || 0

    "#{base_slug}-#{max_suffix + 1}"
  end
end
