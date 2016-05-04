defmodule EctoFlaggableEnumTest do
  use ExUnit.Case

  import Ecto.Changeset
  import EctoFlaggableEnum
  defenumf PropertiesEnum, poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8

  defmodule Package do
    use Ecto.Model

    schema "packages" do
      field :properties, PropertiesEnum
    end
  end

  alias Ecto.Integration.TestRepo

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(TestRepo)
    :ok
  end

  test "accepts int or enum of atom and string on save" do
    package = TestRepo.insert!(%Package{properties: 3})
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive])

    package = TestRepo.update!(%{package|properties: [:radioactive]})
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:radioactive])

    package = TestRepo.update!(%{package|properties: ["dangerous"]})
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive, :radioactive, :dangerous])

    package = TestRepo.update!(%{package|properties: [:poisonous, "dangerous"]})
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive, :radioactive, :dangerous])
  end

  test "accepts list of enums in query" do
    TestRepo.insert!(%Package{properties: [:packaged]})
    package = TestRepo.get_by(Package, properties: [:packaged])
    assert package.properties == MapSet.new([:packaged])

    TestRepo.insert!(%Package{properties: [:dangerous]})
    package = TestRepo.get_by(Package, properties: [:dangerous, :poisonous])
    assert package.properties == MapSet.new([:poisonous, :explosive, :radioactive, :dangerous])
  end

  test "casts enum of binary to enum of atom" do
    %{changes: changes} = cast(%Package{}, %{"properties" => ["poisonous"]}, ~w(properties), [])
    assert changes.properties == MapSet.new([:poisonous])

    %{changes: changes} = cast(%Package{}, %{"properties" => [:packaged]}, ~w(properties), [])
    assert changes.properties == MapSet.new([:packaged])
  end

  test "casts int to enum of atom" do
    %{changes: changes} = cast(%Package{}, %{"properties" => 3}, ~w(properties), [])
    assert changes.properties == MapSet.new([:poisonous, :explosive])
  end

  test "raises when input is not in the enum map" do
    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      cast(%Package{}, %{"properties" => ["retroactive"]}, ~w(properties), [])
    end

    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      cast(%Package{}, %{"properties" => [:retroactive]}, ~w(properties), [])
    end

    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      cast(%Package{}, %{"properties" => [4]}, ~w(properties), [])
    end

    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      TestRepo.insert!(%Package{properties: ["retroactive"]})
    end

    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      TestRepo.insert!(%Package{properties: [:retroactive]})
    end

    assert_raise Elixir.EctoFlaggableEnum.Error, fn ->
      TestRepo.insert!(%Package{properties: [4]})
    end
  end

  test "reflection" do
    assert PropertiesEnum.__enum_map__() == [poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8]
  end
end
