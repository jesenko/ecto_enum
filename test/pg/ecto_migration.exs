defmodule Ecto.Integration.Migration do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :status, :integer
    end

    execute "CREATE TYPE status AS ENUM ('registered', 'active', 'inactive', 'archived')"
    create table(:users_pg) do
      add :status, :status
    end
    create table(:packages) do
      add :properties, :integer
    end
  end
end
