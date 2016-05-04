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
  pass an integer and enumerable of `atom` or `string` to it. This applies to saving the model,
  invoking `Ecto.Changeset.cast/4`, or performing a query on the properties field. Let's
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

  defmodule Error do
    defexception [:message]

    def exception(value) do
      msg = "#{inspect value} is not a valid enum value"
      %__MODULE__{message: msg}
    end
  end

  defmacro defenumf(module, enum_kw) when is_list(enum_kw) do
    enum_map = for {atom, int} <- enum_kw, into: %{}, do: {int, atom}
    enum_map = Macro.escape(enum_map)
    enum_map_string = for {atom, int} <- enum_kw, into: %{}, do: {Atom.to_string(atom), int}
    enum_map_string = Macro.escape(enum_map_string)

    quote do
      defmodule unquote(module) do
        @behaviour Ecto.Type

        def type, do: :integer

        def cast(term) do
          check_value!(term)
          EctoFlaggableEnum.cast(term, unquote(enum_map))
        end

        def load(int) when is_integer(int) do
          {:ok, EctoFlaggableEnum.int_to_set(unquote(enum_map), int)}
        end

        def dump(term) do
          check_value!(term)
          EctoFlaggableEnum.dump(term, unquote(enum_kw), unquote(enum_map_string))
        end

        # Reflection
        def __enum_map__(), do: unquote(enum_kw)


        defp check_value!(list) when is_list(list) do
          check_value!(MapSet.new(list))
        end
        defp check_value!(set = %MapSet{}) do
          set |> Enum.each(&check_single_value!/1)
        end
        defp check_value!(int) when is_integer(int) do
        end

        defp check_single_value!(atom) when is_atom(atom) do
          unless unquote(enum_kw)[atom] do
            raise EctoFlaggableEnum.Error, atom
          end
        end
        defp check_single_value!(string) when is_binary(string) do
          unless unquote(enum_map_string)[string] do
            raise EctoFlaggableEnum.Error, string
          end
        end
        defp check_single_value!(val) do
          raise EctoFlaggableEnum.Error, val
        end
      end
    end
  end

  def cast(list, enum_map) when is_list(list), do: cast(list |> MapSet.new, enum_map)

  def cast(set = %MapSet{}, _enum_map) do
    vals =
      set |> Enum.into(%MapSet{}, fn
        val when is_atom(val) -> val
        val when is_binary(val) -> String.to_atom(val)
      end)
    {:ok, vals}
  end

  def cast(int, enum_map) when is_integer(int) do
    {:ok, int_to_set(enum_map, int)}
  end

  def cast(_term), do: :error

  def dump(int, _enum_kw, _enum_map_string) when is_integer(int) do
    {:ok, int}
  end

  def dump(list, enum_kw, enum_map_string) when is_list(list) do
    dump(MapSet.new(list), enum_kw, enum_map_string)
  end

  def dump(%MapSet{} = set, enum_kw, enum_map_string) do
    {:ok, set_to_int(set, enum_kw, enum_map_string)}
  end

  def dump(_), do: :error

  def int_to_set(enum_map, int) do
    enum_map
    |> Enum.filter_map(
    fn {aint, _atom} -> (aint &&& int) == aint end,
    fn {_, atom} -> atom end)
    |> MapSet.new
  end

  def set_to_int(set, enum_kw, enum_map_string) do
    set
    |> Enum.map(fn
      key when is_binary(key) -> enum_map_string[key]
      key when is_atom(key) -> enum_kw[key]
    end)
    |> Enum.reduce(0, fn(v, acc) -> acc ||| v end)
  end
end
