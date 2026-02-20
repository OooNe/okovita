defmodule Okovita.Content.Models do
  @moduledoc """
  Sub-context for managing content models within a tenant schema.
  """

  alias Ecto.Multi
  alias Okovita.Repo
  alias Okovita.Content.Model
  alias Okovita.Timeline.Auditor

  import Ecto.Query

  @doc "Creates a content model in the tenant schema."
  @spec create_model(map(), String.t(), binary() | nil) ::
          {:ok, Model.t()} | {:error, Ecto.Changeset.t()}
  def create_model(attrs, prefix, actor_id \\ nil) do
    result =
      Multi.new()
      |> Multi.insert(:model, Model.changeset(%Model{}, attrs), prefix: prefix)
      |> Auditor.insert_audit(
        "model",
        "create",
        actor_id,
        fn %{model: model} ->
          {
            model.id,
            nil,
            %{
              slug: model.slug,
              name: model.name,
              schema_definition: model.schema_definition
            }
          }
        end,
        prefix: prefix
      )
      |> Repo.transaction()

    case result do
      {:ok, %{model: model}} -> {:ok, model}
      {:error, :model, changeset, _} -> {:error, changeset}
    end
  end

  @doc "Updates a content model in the tenant schema."
  @spec update_model(binary(), map(), String.t(), binary() | nil) ::
          {:ok, Model.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_model(model_id, attrs, prefix, actor_id \\ nil) do
    case get_model(model_id, prefix) do
      nil ->
        {:error, :not_found}

      model ->
        before_data = %{
          slug: model.slug,
          name: model.name,
          schema_definition: model.schema_definition
        }

        result =
          Multi.new()
          |> Multi.update(:model, Model.changeset(model, attrs), prefix: prefix)
          |> Auditor.insert_audit(
            "model",
            "update",
            actor_id,
            fn %{model: updated_model} ->
              {
                model.id,
                before_data,
                %{
                  slug: updated_model.slug,
                  name: updated_model.name,
                  schema_definition: updated_model.schema_definition
                }
              }
            end,
            prefix: prefix
          )
          |> Repo.transaction()

        case result do
          {:ok, %{model: model}} -> {:ok, model}
          {:error, :model, changeset, _} -> {:error, changeset}
        end
    end
  end

  @doc "Gets a content model by ID."
  def get_model(id, prefix) do
    Repo.get(Model, id, prefix: prefix)
  end

  @doc "Gets a content model by slug."
  def get_model_by_slug(slug, prefix) do
    Repo.one(from(m in Model, where: m.slug == ^slug), prefix: prefix)
  end

  @doc "Lists all content models."
  def list_models(prefix) do
    Repo.all(from(m in Model, order_by: [asc: m.name]), prefix: prefix)
  end
end
