defmodule EctoFlaggableEnum do
  @moduledoc """
  Provides `defenumf/2` macro for defining an Flaggable Enum Ecto type.
  """

  @doc """
  Defines an enum custom `Ecto.Type`.

  It can be used like any other `Ecto.Type` by passing it to a field in your model's
  schema block. For example:

      import EctoFlaggableEnum
      defenumf PropertiesEnum, poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8

      defmodule Package do
        use Ecto.Model

        schema "packages" do
          field :properties, PropertiesEnum
        end
      end

  In the above example, the `:properties` will behave like an flaggable enum and will allow you to
  pass an integer and enumerable of `atom`, `string` or `integer` to it. This applies to saving the model,
  invoking `Ecto.Changeset.cast/3`, or performing a query on the properties field. Let's
  do a few examples:

      iex> package = Repo.insert!(%Package{properties: 1})
      iex> Repo.get(Package, package.id).properties
      :registered

      iex> %{changes: changes} = cast(%Package{}, %{"properties" => ["poisonous"]}, ~w(properties), [])
      iex> changes.properties
      #MapSet<[:poisonous]>

      iex> from(p in Package, where: p.properties == [:poisonous]) |> Repo.all() |> length
      1

  Passing a value that the custom Enum type does not recognize will result in an error.

      iex> Repo.insert!(%Package{properties: [:none]})
      ** (Elixir.EctoFlaggableEnum.Error) :none is not a valid enum value

  The enum type `PropertiesEnum` will also have a reflection function for inspecting the
  enum map in runtime.

      iex> PropertiesEnum.__enum_map__()
      [poisonous: 1, explosive: 2, radioactive: 4, dangerous: 7, packaged: 8]
  """

  use Bitwise

  defmacro defenumf(module, enum) when is_list(enum) do
    quote do
      kw = unquote(enum) |> Macro.escape

      defmodule unquote(module) do
        @behaviour Ecto.Type

        @atom_int_kw kw
        @atom_int_map kw |> Enum.into(%{})
        @int_atom_map for {atom, int} <- kw, into: %{}, do: {int, atom}
        @string_int_map for {atom, int} <- kw, into: %{}, do: {Atom.to_string(atom), int}
        @string_atom_map for {atom, int} <- kw, into: %{}, do: {Atom.to_string(atom), atom}
        @valid_values Keyword.values(@atom_int_kw) ++ Keyword.keys(@atom_int_kw) ++ Map.keys(@string_int_map)

        def type, do: :integer

        def cast(term) do
          EctoFlaggableEnum.Type.cast(term, @int_atom_map, @string_atom_map)
        end

        def load(int) when is_integer(int) do
          {:ok, EctoFlaggableEnum.Type.int_to_set(@int_atom_map, int)}
        end

        def dump(term) do
          case EctoFlaggableEnum.Type.dump(term, @atom_int_map, @int_atom_map, @string_atom_map) do
            :error ->
              msg = "`#{inspect term}` is not a valid enum value for `#{inspect __MODULE__}`. " <>
                "Valid enum values are list or set of values `#{inspect __valid_values__()}`, or integer representing a sum of integer enum values."
              raise Ecto.ChangeError,
                message: msg
            value ->
              value
          end
        end

        # Reflection
        def __enum_map__(), do: @atom_int_kw
        def __valid_values__(), do: @valid_values
      end
    end
  end

  defmodule Type do
    @spec cast(list | integer | MapSet.t, map, map) :: {:ok, [MapSet.t]} | :error
    def cast(list, int_atom_map, string_atom_map) when is_list(list) do
      do_cast(list, [], int_atom_map, string_atom_map)
    end
    def cast(set = %MapSet{}, int_enum_map, string_atom_map) do
      cast(set |> MapSet.to_list, int_enum_map, string_atom_map)
    end
    def cast(int, int_atom_map, _) when is_integer(int) do
      {:ok, int_to_set(int_atom_map, int)}
    end
    def cast(_, _ ,_), do: :error

    defp do_cast([string | rest], casted, int_to_atom, string_to_atom) when is_binary(string) do
      if string_to_atom[string] do
        do_cast(rest, [string_to_atom[string] | casted], int_to_atom, string_to_atom)
      else
        :error
      end
    end
    defp do_cast([atom | rest], casted, int_to_atom, string_to_atom) when is_atom(atom) do
      if atom in (string_to_atom |> Map.values) do
        do_cast(rest, [atom | casted], int_to_atom, string_to_atom)
      else
        :error
      end
    end
    defp do_cast([int | rest], casted, int_to_atom, string_to_atom) when is_integer(int) do
      if int_to_atom[int] do
        do_cast(rest, [int_to_atom[int] | casted], int_to_atom, string_to_atom)
      else
        :error
      end
    end
    defp do_cast([], casted, _, _) do
      {:ok, MapSet.new(casted)}
    end

    @spec dump(any, map, map, map) :: {:ok, integer} | :error
    def dump(val, atom_to_int, int_to_atom, string_to_atom) do
      case cast(val, int_to_atom, string_to_atom) do
        {:ok, set} -> {:ok, set_to_int(set, atom_to_int)}
        :error -> :error
      end
    end

    def int_to_set(enum_map, int) do
      enum_map
      |> Enum.filter_map(
      fn {aint, _atom} -> (aint &&& int) == aint end,
      fn {_, atom} -> atom end)
      |> MapSet.new
    end

    def set_to_int(set, atom_to_int) do
      set
      |> Enum.map(fn
        key -> atom_to_int[key]
      end)
      |> Enum.reduce(0, fn(v, acc) -> acc ||| v end)
    end
  end
end
