defmodule EctoEnumTest do
  use ExUnit.Case

  import EctoEnum
  defenum(StatusEnum, registered: 0, active: 1, inactive: 2, archived: 3)

  defmodule User do
    use Ecto.Schema

    schema "users" do
      field(:status, StatusEnum)
    end
  end

  alias Ecto.Integration.TestRepo

  test "accepts int, atom and string on save" do
    user = TestRepo.insert!(%User{status: 0})
    user = TestRepo.get(User, user.id)
    assert user.status == :registered

    user = Ecto.Changeset.change(user, status: :active)
    user = TestRepo.update!(user)
    assert user.status == :active

    user = Ecto.Changeset.change(user, status: "inactive")
    user = TestRepo.update!(user)
    assert user.status == "inactive"

    user = TestRepo.get(User, user.id)
    assert user.status == :inactive

    TestRepo.insert!(%User{status: :archived})
    user = TestRepo.get_by(User, status: :archived)
    assert user.status == :archived
  end

  test "casts int and binary to atom" do
    %{changes: changes} = Ecto.Changeset.cast(%User{}, %{"status" => "active"}, [:status])
    assert changes.status == :active

    %{changes: changes} = Ecto.Changeset.cast(%User{}, %{"status" => 3}, [:status])
    assert changes.status == :archived

    %{changes: changes} = Ecto.Changeset.cast(%User{}, %{"status" => :inactive}, [:status])
    assert changes.status == :inactive
  end

  test "raises when input is not in the enum map" do
    error = {:status, {"is invalid", [type: EctoEnumTest.StatusEnum, validation: :cast]}}

    changeset = Ecto.Changeset.cast(%User{}, %{"status" => "retroactive"}, [:status])
    assert error in changeset.errors

    changeset = Ecto.Changeset.cast(%User{}, %{"status" => :retroactive}, [:status])
    assert error in changeset.errors

    changeset = Ecto.Changeset.cast(%User{}, %{"status" => 4}, [:status])
    assert error in changeset.errors

    assert_raise Ecto.ChangeError, error_msg("retroactive"), fn ->
      TestRepo.insert!(%User{status: "retroactive"})
    end

    assert_raise Ecto.ChangeError, error_msg(:retroactive), fn ->
      TestRepo.insert!(%User{status: :retroactive})
    end

    assert_raise Ecto.ChangeError, error_msg(5), fn ->
      TestRepo.insert!(%User{status: 5})
    end
  end

  test "reflection" do
    assert StatusEnum.__enum_map__() == [registered: 0, active: 1, inactive: 2, archived: 3]

    assert StatusEnum.__valid_values__() == [
             0,
             1,
             2,
             3,
             :registered,
             :active,
             :inactive,
             :archived,
             "active",
             "archived",
             "inactive",
             "registered"
           ]
  end

  test "defenum/2 can accept variables" do
    x = 0
    defenum(TestEnum, zero: x)
  end

  def error_msg(value) do
    "value `#{inspect(value)}` for `EctoEnumTest.User.status` in `insert` does not match type EctoEnumTest.StatusEnum"
  end
end
