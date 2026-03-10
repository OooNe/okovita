defmodule Okovita.Content.DynamicChangesetTest do
  use ExUnit.Case, async: true

  alias Okovita.Content.DynamicChangeset

  @blog_schema %{
    "title" => %{
      "field_type" => "text",
      "label" => "Title",
      "required" => true,
      "max_length" => 200
    },
    "body" => %{
      "field_type" => "textarea",
      "label" => "Body",
      "required" => true
    },
    "views" => %{
      "field_type" => "integer",
      "label" => "Views",
      "required" => false,
      "min" => 0
    },
    "status" => %{
      "field_type" => "enum",
      "label" => "Status",
      "required" => true,
      "one_of" => ["draft", "published", "archived"]
    },
    "featured" => %{
      "field_type" => "boolean",
      "label" => "Featured",
      "required" => false
    },
    "published_at" => %{
      "field_type" => "date",
      "label" => "Published At",
      "required" => false
    }
  }

  describe "build/2" do
    test "returns validated data for valid input" do
      data = %{
        "title" => "My First Post",
        "body" => "Hello World",
        "status" => "draft",
        "views" => 10,
        "featured" => true,
        "published_at" => "2026-02-19"
      }

      assert {:ok, result} = DynamicChangeset.build(@blog_schema, data)
      assert result.title == "My First Post"
      assert result.body == "Hello World"
      assert result.status == "draft"
      assert result.views == 10
      assert result.featured == true
      assert result.published_at == ~D[2026-02-19]
    end

    test "returns error changeset for missing required fields" do
      data = %{"views" => 5}

      assert {:error, changeset} = DynamicChangeset.build(@blog_schema, data)
      refute changeset.valid?

      errors = changeset_errors(changeset)
      assert "can't be blank" in errors[:title]
      assert "can't be blank" in errors[:body]
      assert "can't be blank" in errors[:status]
    end

    test "returns error for max_length violation" do
      data = %{
        "title" => String.duplicate("x", 201),
        "body" => "ok",
        "status" => "draft"
      }

      assert {:error, changeset} = DynamicChangeset.build(@blog_schema, data)
      errors = changeset_errors(changeset)
      assert length(errors[:title]) > 0
    end

    test "returns error for min/max number violations" do
      data = %{
        "title" => "Post",
        "body" => "Body",
        "status" => "draft",
        "views" => -5
      }

      assert {:error, changeset} = DynamicChangeset.build(@blog_schema, data)
      errors = changeset_errors(changeset)
      assert length(errors[:views]) > 0
    end

    test "returns error for invalid enum value" do
      data = %{
        "title" => "Post",
        "body" => "Body",
        "status" => "invalid_status"
      }

      assert {:error, changeset} = DynamicChangeset.build(@blog_schema, data)
      errors = changeset_errors(changeset)
      assert length(errors[:status]) > 0
    end

    test "handles optional fields being nil" do
      data = %{
        "title" => "Post",
        "body" => "Body",
        "status" => "published"
      }

      assert {:ok, result} = DynamicChangeset.build(@blog_schema, data)
      assert is_nil(result[:views])
      assert is_nil(result[:featured])
      assert is_nil(result[:published_at])
    end

    test "raises on unknown field type in schema_definition" do
      bad_schema = %{
        "field" => %{"field_type" => "unknown_type", "label" => "X", "required" => false}
      }

      assert_raise ArgumentError, ~r/Unknown field type/, fn ->
        DynamicChangeset.build(bad_schema, %{"field" => "value"})
      end
    end
  end

  describe "custom validation" do
    test "regex validation on text field - match" do
      schema = %{
        "code" => %{
          "field_type" => "text",
          "label" => "Code",
          "required" => true,
          "validation_regex" => "^[A-Z]{2}-\\d{4}$"
        }
      }

      assert {:ok, result} = DynamicChangeset.build(schema, %{"code" => "AB-1234"})
      assert result.code == "AB-1234"
    end

    test "regex validation on text field - no match" do
      schema = %{
        "code" => %{
          "field_type" => "text",
          "label" => "Code",
          "required" => true,
          "validation_regex" => "^[A-Z]{2}-\\d{4}$"
        }
      }

      assert {:error, changeset} = DynamicChangeset.build(schema, %{"code" => "invalid"})
      errors = changeset_errors(changeset)
      assert "does not match the required pattern" in errors[:code]
    end

    test "regex on url supplements built-in https check" do
      schema = %{
        "site" => %{
          "field_type" => "url",
          "label" => "Site",
          "required" => true,
          "validation_regex" => "\\.example\\.com"
        }
      }

      # Valid: passes both https and custom regex
      assert {:ok, _} = DynamicChangeset.build(schema, %{"site" => "https://www.example.com/page"})

      # Invalid: passes https but fails custom regex
      assert {:error, cs} = DynamicChangeset.build(schema, %{"site" => "https://other.com"})
      errors = changeset_errors(cs)
      assert "does not match the required pattern" in errors[:site]

      # Invalid: fails https check (custom regex irrelevant)
      assert {:error, cs2} = DynamicChangeset.build(schema, %{"site" => "ftp://example.com"})
      errors2 = changeset_errors(cs2)
      assert "must be a valid URL" in errors2[:site]
    end

    test "min_length validation on text field" do
      schema = %{
        "name" => %{
          "field_type" => "text",
          "label" => "Name",
          "required" => true,
          "min_length" => 5
        }
      }

      assert {:error, changeset} = DynamicChangeset.build(schema, %{"name" => "abc"})
      errors = changeset_errors(changeset)
      assert length(errors[:name]) > 0

      assert {:ok, _} = DynamicChangeset.build(schema, %{"name" => "abcde"})
    end

    test "max_length validation on textarea" do
      schema = %{
        "desc" => %{
          "field_type" => "textarea",
          "label" => "Description",
          "required" => true,
          "max_length" => 10
        }
      }

      assert {:error, _} = DynamicChangeset.build(schema, %{"desc" => String.duplicate("x", 11)})
      assert {:ok, _} = DynamicChangeset.build(schema, %{"desc" => "short"})
    end

    test "date min/max range validation" do
      schema = %{
        "event_date" => %{
          "field_type" => "date",
          "label" => "Event Date",
          "required" => true,
          "min" => "2026-01-01",
          "max" => "2026-12-31"
        }
      }

      # Too early
      assert {:error, cs} = DynamicChangeset.build(schema, %{"event_date" => "2025-12-31"})
      errors = changeset_errors(cs)
      assert length(errors[:event_date]) > 0

      # Too late
      assert {:error, _} = DynamicChangeset.build(schema, %{"event_date" => "2027-01-01"})

      # In range
      assert {:ok, _} = DynamicChangeset.build(schema, %{"event_date" => "2026-06-15"})

      # Boundary values
      assert {:ok, _} = DynamicChangeset.build(schema, %{"event_date" => "2026-01-01"})
      assert {:ok, _} = DynamicChangeset.build(schema, %{"event_date" => "2026-12-31"})
    end

    test "datetime min/max range validation" do
      schema = %{
        "starts_at" => %{
          "field_type" => "datetime",
          "label" => "Starts At",
          "required" => true,
          "min" => "2026-01-01T00:00:00Z",
          "max" => "2026-12-31T23:59:59Z"
        }
      }

      assert {:error, _} =
               DynamicChangeset.build(schema, %{"starts_at" => "2025-12-31T23:59:59Z"})

      assert {:ok, _} = DynamicChangeset.build(schema, %{"starts_at" => "2026-06-15T12:00:00Z"})
    end

    test "invalid regex pattern does not crash" do
      schema = %{
        "field" => %{
          "field_type" => "text",
          "label" => "Field",
          "required" => true,
          "validation_regex" => "[invalid"
        }
      }

      assert {:error, changeset} = DynamicChangeset.build(schema, %{"field" => "value"})
      errors = changeset_errors(changeset)
      assert "has an invalid validation pattern configured" in errors[:field]
    end

    test "optional empty field skips regex validation" do
      schema = %{
        "code" => %{
          "field_type" => "text",
          "label" => "Code",
          "required" => false,
          "validation_regex" => "^[A-Z]{2}-\\d{4}$"
        }
      }

      # Empty/nil value should not trigger regex check
      assert {:ok, result} = DynamicChangeset.build(schema, %{})
      assert is_nil(result[:code])
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

