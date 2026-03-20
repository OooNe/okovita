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
    base_properties =
      Enum.reduce(model.schema_definition, %{}, fn {key, def}, acc ->
        Map.put(acc, key, map_field_type(def))
      end)

    base_required_fields =
      model.schema_definition
      |> Enum.filter(fn {_key, def} -> def["required"] == true end)
      |> Enum.map(fn {key, _def} -> key end)

    {properties, required_fields} =
      if model.is_component do
        {base_properties, base_required_fields}
      else
        {
          Map.put(base_properties, "id", %{"type" => "string", "format" => "uuid"}),
          List.insert_at(base_required_fields, 0, "id")
        }
      end

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

  defp map_field_type(%{"field_type" => type, "target_model" => target}) do
    if Okovita.FieldTypes.Registry.targets_entry?(type) and is_binary(target) do
      %{
        "oneOf" => [
          %{"type" => "string", "format" => "uuid"},
          %{"$ref" => "#/components/schemas/#{target}_Entry"}
        ]
      }
    else
      %{"type" => "string"}
    end
  end

  defp map_field_type(%{"field_type" => type}) do
    if Okovita.FieldTypes.Registry.targets_entry?(type) do
      %{"type" => "string", "format" => "uuid"}
    else
      %{"type" => "string"}
    end
  end

  defp map_field_type(_), do: %{"type" => "string"}

  defp build_paths(models) do
    base_paths = %{}

    Enum.reduce(models, base_paths, fn model, paths ->
      relations_paths =
        Enum.reduce(models, %{}, fn child_model, sub_paths ->
          targets_parent? =
            child_model.schema_definition
            |> Enum.any?(fn {_key, def} ->
              Okovita.FieldTypes.Registry.targets_entry?(def["field_type"]) and
                def["target_model"] == model.slug
            end)

          if targets_parent? do
            Map.put(
              sub_paths,
              "/models/#{model.slug}/entries/{id}/#{child_model.slug}",
              nested_operations(model, child_model.slug)
            )
          else
            sub_paths
          end
        end)

      # If it's a component, generate /components/{slug} paths
      # If it's a collection, generate standard entry paths
      paths =
        if model.is_component do
          component_path = "/components/#{model.slug}"
          Map.put(paths, component_path, component_operations(model))
        else
          paths
          |> Map.put("/models/#{model.slug}/entries", collection_operations(model))
          |> Map.put("/models/#{model.slug}/entries/by-slug/{slug}", item_by_slug_operations(model))
          |> Map.put("/models/#{model.slug}/entries/{id}", item_operations(model))
        end

      paths
      |> Map.merge(relations_paths)
    end)
  end

  defp component_operations(model) do
    parameters = [
      %{
        "name" => "withMetadata",
        "in" => "query",
        "description" => "Include system metadata wrapper in response",
        "required" => false,
        "schema" => %{"type" => "boolean", "default" => false}
      }
    ]

    get_parameters =
      parameters ++
        [
          %{
            "name" => "populate",
            "in" => "query",
            "description" => "Comma-separated list of relation keys to populate, or * for all",
            "required" => false,
            "schema" => %{"type" => "string"}
          }
        ]

    %{
      "get" => %{
        "tags" => [model.name],
        "summary" => "Get item for component #{model.name}",
        "parameters" => get_parameters,
        "responses" => %{
          "200" => %{
            "description" => "Component data",
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
        "summary" => "Update item for component #{model.name}",
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
            "description" => "Updated component item",
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
      }
    }
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
          },
          %{
            "name" => "populate",
            "in" => "query",
            "description" => "Comma-separated list of relation keys to populate, or * for all",
            "required" => false,
            "schema" => %{"type" => "string"}
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

  defp item_by_slug_operations(model) do
    get_parameters = [
      %{
        "name" => "slug",
        "in" => "path",
        "required" => true,
        "description" => "Entry slug (human-readable identifier)",
        "schema" => %{"type" => "string", "pattern" => "^[a-z0-9][a-z0-9_-]*$"}
      },
      %{
        "name" => "withMetadata",
        "in" => "query",
        "description" => "Include system metadata wrapper in response",
        "required" => false,
        "schema" => %{"type" => "boolean", "default" => false}
      },
      %{
        "name" => "populate",
        "in" => "query",
        "description" => "Comma-separated list of relation keys to populate, or * for all",
        "required" => false,
        "schema" => %{"type" => "string"}
      }
    ]

    %{
      "get" => %{
        "tags" => [model.name],
        "summary" => "Get entry by slug for #{model.name}",
        "description" => "Retrieve an entry using its human-readable slug instead of UUID. Useful for creating clean, SEO-friendly URLs.",
        "parameters" => get_parameters,
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
          "404" => %{
            "description" => "Entry not found with the provided slug in this model"
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

    get_parameters =
      parameters ++
        [
          %{
            "name" => "populate",
            "in" => "query",
            "description" => "Comma-separated list of relation keys to populate, or * for all",
            "required" => false,
            "schema" => %{"type" => "string"}
          }
        ]

    %{
      "get" => %{
        "tags" => [model.name],
        "summary" => "Get entry for #{model.name}",
        "parameters" => get_parameters,
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

  defp nested_operations(parent_model, target_slug) do
    %{
      "get" => %{
        "tags" => [parent_model.name],
        "summary" => "List nested #{target_slug} entries for #{parent_model.name}",
        "parameters" => [
          %{
            "name" => "id",
            "in" => "path",
            "required" => true,
            "schema" => %{"type" => "string"}
          },
          %{
            "name" => "withMetadata",
            "in" => "query",
            "description" => "Include system metadata wrapper",
            "required" => false,
            "schema" => %{"type" => "boolean", "default" => false}
          },
          %{
            "name" => "populate",
            "in" => "query",
            "description" => "Comma-separated list of relation keys to populate, or * for all",
            "required" => false,
            "schema" => %{"type" => "string"}
          }
        ],
        "responses" => %{
          "200" => %{
            "description" => "List of nested entries",
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "type" => "array",
                  "items" => %{
                    "oneOf" => [
                      %{"$ref" => "#/components/schemas/#{target_slug}_Data"},
                      %{"$ref" => "#/components/schemas/#{target_slug}_Entry"}
                    ]
                  }
                }
              }
            }
          },
          "404" => %{"description" => "Parent entry or model not found"}
        }
      }
    }
  end
end
