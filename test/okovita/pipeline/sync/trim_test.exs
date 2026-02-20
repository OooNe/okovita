defmodule Okovita.Pipeline.Sync.TrimTest do
  use ExUnit.Case, async: true

  alias Okovita.Pipeline.Sync.Trim

  describe "apply/2" do
    test "trims whitespace from strings" do
      assert {:ok, "hello"} = Trim.apply("  hello  ", %{})
      assert {:ok, "world"} = Trim.apply("\n\tworld\t\n", %{})
      assert {:ok, ""} = Trim.apply("   ", %{})
    end

    test "passes through non-string values" do
      assert {:ok, 42} = Trim.apply(42, %{})
      assert {:ok, nil} = Trim.apply(nil, %{})
      assert {:ok, true} = Trim.apply(true, %{})
    end
  end
end
