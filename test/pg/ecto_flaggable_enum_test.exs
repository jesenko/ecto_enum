defmodule EctoFlaggableEnumTest do
  use ExUnit.Case

  import EctoFlaggableEnum
  defenumf PropertiesEnum, poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8

  defmodule Package do
    use Ecto.Schema

    schema "packages" do
      field :properties, PropertiesEnum
    end
  end

  alias Ecto.Integration.TestRepo

  test "accepts int or enum of atom and string on save" do
    package = TestRepo.insert!(%Package{properties: 3})
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive])

    package = Ecto.Changeset.change(package, properties: [:radioactive])
    package = TestRepo.update!(package)
    assert package.properties == [:radioactive]
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:radioactive])

    package = Ecto.Changeset.change(package, properties: ["dangerous"])
    package = TestRepo.update!(package)
    assert package.properties == ["dangerous"]
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive, :radioactive, :dangerous])

    package = Ecto.Changeset.change(package, properties: [:poisonous, "dangerous"])
    package = TestRepo.update!(package)
    assert package.properties == [:poisonous, "dangerous"]
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous, :explosive, :radioactive, :dangerous])

    package = Ecto.Changeset.change(package, properties: [1])
    package = TestRepo.update!(package)
    assert package.properties == [1]
    package = TestRepo.get(Package, package.id)
    assert package.properties == MapSet.new([:poisonous])
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
    %{changes: changes} = Ecto.Changeset.cast(%Package{}, %{"properties" => ["poisonous"]}, ~w(properties))
    assert changes.properties == MapSet.new([:poisonous])

    %{changes: changes} = Ecto.Changeset.cast(%Package{}, %{"properties" => [:packaged]}, ~w(properties))
    assert changes.properties == MapSet.new([:packaged])
  end

  test "casts int to enum of atom" do
    %{changes: changes} = Ecto.Changeset.cast(%Package{}, %{"properties" => 3}, ~w(properties))
    assert changes.properties == MapSet.new([:poisonous, :explosive])
  end

  test "raises when input is not in the enum map" do
    error = {:properties, {"is invalid", [type: EctoFlaggableEnumTest.PropertiesEnum, validation: :cast]}}

    changeset = Ecto.Changeset.cast(%Package{}, %{"properties" => ["retroactive"]}, ~w(properties))
    assert error in changeset.errors

    changeset = Ecto.Changeset.cast(%Package{}, %{"properties" => [:retroactive]}, ~w(properties))
    assert error in changeset.errors

    changeset = Ecto.Changeset.cast(%Package{}, %{"properties" => [5]}, ~w(properties))
    assert error in changeset.errors

    assert_raise Ecto.ChangeError, custom_error_msg("retroactive"), fn ->
      TestRepo.insert!(%Package{properties: ["retroactive"]})
    end

    assert_raise Ecto.ChangeError, custom_error_msg(:retroactive), fn ->
      TestRepo.insert!(%Package{properties: [:retroactive]})
    end

    assert_raise Ecto.ChangeError, custom_error_msg(5), fn ->
      TestRepo.insert!(%Package{properties: [5]})
    end
  end

  test "reflection" do
    assert PropertiesEnum.__enum_map__() == [poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8]
  end

  def custom_error_msg(value) do
    "`[#{inspect value}]` is not a valid enum value for `EctoFlaggableEnumTest.PropertiesEnum`." <>
    " Valid enum values are list or set of values `[1, 2, 4, 7, 8, :poisonous, :explosive, :radioactive, :dangerous, :packaged, \"dangerous\", \"explosive\", \"packaged\", \"poisonous\", \"radioactive\"]`, or integer representing a sum of integer enum values."
  end
end
