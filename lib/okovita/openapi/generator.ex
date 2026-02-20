defmodule Okovita.OpenAPI.Generator do
  @moduledoc """
  Generates an OpenAPI 3.0 specification from a tenant's content models.
  """

  @doc "Builds the complete OpenAPI map."
  def generate(tenant, models) do
    %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => "Okovita API — #{tenant.name}",
        "description" => "Dynamic Content API for tenant #{tenant.name}",
        "version" => "1.0.0"
      },
      "servers" => [
        %{
          "url" => "/api/v1",
          "description" => "Current API Version"
        }
      ],
      "tags" =>
        Enum.map(models, fn m ->
          %{"name" => m.name, "description" => "Endpoints for #{m.name}"}
        end),
      "paths" => build_paths(models),
      "components" => %{
        "securitySchemes" => %{
          "ApiKeyAuth" => %{
            "type" => "apiKey",
            "in" => "header",
            "name" => "x-api-key"
          }
        },
        "schemas" => build_schemas(models)
      },
      "security" => [
        %{"ApiKeyAuth" => []}
      ]
    }
  end

  defp build_schemas(models) do
    base_schemas = %{
      "Error" => %{
        "type" => "object",
        "properties" => %{
          "errors" => %{
            "type" => "object",
            "additionalProperties" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            }
          }
        }
      },
      "EntryBase" => %{
        "type" => "object",
        "properties" => %{
          "slug" => %{"type" => "string"},
          "model_id" => %{"type" => "string", "format" => "uuid"},
          "inserted_at" => %{"type" => "string", "format" => "date-time"},
          "updated_at" => %{"type" => "string", "format" => "date-time"}
        },
        "required" => ["slug", "model_id", "inserted_at", "updated_at"]
      }
    }

    Enum.reduce(models, base_schemas, fn model, acc ->
      acc
      |> Map.put("#{model.slug}_Data", build_model_schema(model))
      |> Map.put("#{model.slug}_Entry", %{
        "type" => "object",
        "properties" => %{
          "metadata" => %{"$ref" => "#/components/schemas/EntryBase"},
          "data" => %{"$ref" => "#/components/schemas/#{model.slug}_Data"}
        },
        "required" => ["metadata", "data"]
      })
    end)
  end

  defp build_model_schema(model) do
    properties =
      Enum.reduce(model.schema_definition, %{}, fn {key, def}, acc ->
        Map.put(acc, key, map_field_type(def))
      end)
      |> Map.put("id", %{"type" => "string", "format" => "uuid"})

    required_fields =
      model.schema_definition
      |> Enum.filter(fn {_key, def} -> def["required"] == true end)
      |> Enum.map(fn {key, _def} -> key end)
      |> List.insert_at(0, "id")

    %{
      "type" => "object",
      "properties" => properties,
      "required" => required_fields
    }
  end

  defp map_field_type(%{"field_type" => "text"}), do: %{"type" => "string"}
  defp map_field_type(%{"field_type" => "textarea"}), do: %{"type" => "string"}
  defp map_field_type(%{"field_type" => "number"}), do: %{"type" => "number"}
  defp map_field_type(%{"field_type" => "integer"}), do: %{"type" => "integer"}
  defp map_field_type(%{"field_type" => "boolean"}), do: %{"type" => "boolean"}
  # Could parse options if added later
  defp map_field_type(%{"field_type" => "enum"}), do: %{"type" => "string"}
  defp map_field_type(%{"field_type" => "date"}), do: %{"type" => "string", "format" => "date"}

  defp map_field_type(%{"field_type" => "datetime"}),
    do: %{"type" => "string", "format" => "date-time"}

  defp map_field_type(%{"field_type" => "relation", "target_model" => target})
       when is_binary(target),
       do: %{
         "oneOf" => [
           %{"type" => "string", "format" => "uuid"},
           %{"$ref" => "#/components/schemas/#{target}_Entry"}
         ]
       }

  defp map_field_type(%{"field_type" => "relation"}),
    do: %{"type" => "string", "format" => "uuid"}

  defp map_field_type(_), do: %{"type" => "string"}

  defp build_paths(models) do
    Enum.reduce(models, %{}, fn model, paths ->
      paths
      |> Map.put("/models/#{model.slug}/entries", collection_operations(model))
      |> Map.put("/models/#{model.slug}/entries/{id}", item_operations(model))
    end)
  end

  defp collection_operations(model) do
    %{
      "get" => %{
        "tags" => [model.name],
        "summary" => "List entries for #{model.name}",
        "parameters" => [
          %{
            "name" => "withMetadata",
            "in" => "query",
            "description" => "Include system metadata wrapper",
            "required" => false,
            "schema" => %{"type" => "boolean", "default" => false}
          }
        ],
        "responses" => %{
          "200" => %{
            "description" => "List of entries",
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "type" => "array",
                  "items" => %{
                    "oneOf" => [
                      %{"$ref" => "#/components/schemas/#{model.slug}_Data"},
                      %{"$ref" => "#/components/schemas/#{model.slug}_Entry"}
                    ]
                  }
                }
              }
            }
          }
        }
      },
      "post" => %{
        "tags" => [model.name],
        "summary" => "Create a new entry for #{model.name}",
        "parameters" => [
          %{
            "name" => "withMetadata",
            "in" => "query",
            "description" => "Include system metadata wrapper in response",
            "required" => false,
            "schema" => %{"type" => "boolean", "default" => false}
          }
        ],
        "requestBody" => %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "slug" => %{"type" => "string"},
                  "data" => %{"$ref" => "#/components/schemas/#{model.slug}_Data"}
                }
              }
            }
          }
        },
        "responses" => %{
          "201" => %{
            "description" => "Created entry",
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "oneOf" => [
                    %{"$ref" => "#/components/schemas/#{model.slug}_Data"},
                    %{"$ref" => "#/components/schemas/#{model.slug}_Entry"}
                  ]
                }
              }
            }
          },
          "422" => %{
            "description" => "Validation error",
            "content" => %{
              "application/json" => %{
                "schema" => %{"$ref" => "#/components/schemas/Error"}
              }
            }
          }
        }
      }
    }
  end

  defp item_operations(model) do
    parameters = [
      %{
        "name" => "id",
        "in" => "path",
        "required" => true,
        "schema" => %{"type" => "string"}
      },
      %{
        "name" => "withMetadata",
        "in" => "query",
        "description" => "Include system metadata wrapper in response",
        "required" => false,
        "schema" => %{"type" => "boolean", "default" => false}
      }
    ]

    %{
      "get" => %{
        "tags" => [model.name],
        "summary" => "Get entry for #{model.name}",
        "parameters" => parameters,
        "responses" => %{
          "200" => %{
            "description" => "Entry data",
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "oneOf" => [
                    %{"$ref" => "#/components/schemas/#{model.slug}_Data"},
                    %{"$ref" => "#/components/schemas/#{model.slug}_Entry"}
                  ]
                }
              }
            }
          },
          "404" => %{"description" => "Not found"}
        }
      },
      "put" => %{
        "tags" => [model.name],
        "summary" => "Update entry for #{model.name}",
        "parameters" => parameters,
        "requestBody" => %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "slug" => %{"type" => "string"},
                  "data" => %{"$ref" => "#/components/schemas/#{model.slug}_Data"}
                }
              }
            }
          }
        },
        "responses" => %{
          "200" => %{
            "description" => "Updated entry",
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "oneOf" => [
                    %{"$ref" => "#/components/schemas/#{model.slug}_Data"},
                    %{"$ref" => "#/components/schemas/#{model.slug}_Entry"}
                  ]
                }
              }
            }
          },
          "422" => %{
            "description" => "Validation error",
            "content" => %{
              "application/json" => %{
                "schema" => %{"$ref" => "#/components/schemas/Error"}
              }
            }
          },
          "404" => %{"description" => "Not found"}
        }
      },
      "delete" => %{
        "tags" => [model.name],
        "summary" => "Delete entry for #{model.name}",
        "parameters" => parameters,
        "responses" => %{
          "200" => %{
            "description" => "Deleted entry"
          },
          "404" => %{"description" => "Not found"}
        }
      }
    }
  end
end
