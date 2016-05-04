defmodule Ecto.Integration.Migration do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :status, :integer
    end
    create table(:packages) do
      add :properties, :integer
    end
  end
end
