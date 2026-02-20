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

  describe "changeset/2" do
    test "returns a changeset struct" do
      data = %{"title" => "Post", "body" => "Body", "status" => "draft"}
      cs = DynamicChangeset.changeset(@blog_schema, data)
      assert %Ecto.Changeset{} = cs
      assert cs.valid?
    end

    test "returns invalid changeset on validation failure" do
      cs = DynamicChangeset.changeset(@blog_schema, %{})
      refute cs.valid?
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
