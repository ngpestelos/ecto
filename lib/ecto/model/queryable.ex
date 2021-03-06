defmodule Ecto.Model.Queryable do
  @moduledoc """
  Defines a model as queryable.

  In order to create queries in Ecto, you need to pass a queryable
  data structure as argument. By using `Ecto.Model.Queryable` in
  your model, it imports the `queryable/2` macro.

  Assuming you have an entity named `Weather.Entity`, you can associate
  it with a model via:

      defmodule Weather do
        use Ecto.Model
        queryable "weather", Weather.Entity
      end

  Since this is a common pattern, Ecto allows developers to define an entity
  inlined in a model:

      defmodule Weather do
        use Ecto.Model

        queryable "weather" do
          field :city,    :string
          field :temp_lo, :integer
          field :temp_hi, :integer
          field :prcp,    :float, default: 0.0
        end
      end

  By making it queryable, three functions are added to the model:

  * `new/0` - simply delegates to `entity.new/0`
  * `new/1` - simply delegates to `entity.new/1`
  * `__model__/1` - reflection functions about the source and entity

  This module also automatically imports `from/1` and `from/2`
  from `Ecto.Query` as a convenience.

  ## Entity defaults

  When using the block syntax, the created entity uses the usual default
  of a primary key named `:id`, of type `:integer`. This can be customized
  by passing `primary_key: false` to queryable:

      queryable "weather", primary_key: false do
        ...
      end

  Or by passing a tuple in the format `{ field, type, opts }`:

      queryable "weather", primary_key: { :custom_field, :string, [] } do
        ...
      end

  Global defaults can be specified via the `@queryable_defaults` attribute.
  This is useful if you want to use a different default primary key
  through your entire application.

  The supported options are:

  * `primary_key` - either `false`, or a `{ field, type, opts }` tuple
  * `foreign_key_type` - sets the type for any belongs_to associations.
                         This can be overrided using the `:type` option
                         to the `belongs_to` statement. Defaults to
                         type `:integer`

  Example:

      defmodule MyApp.Model do
        defmacro __using__(_) do
          quote do
            @queryable_defaults primary_key: { :uuid, :string, [] },
                                foreign_key_type: :string
            use Ecto.Model
          end
        end
      end

      defmodule MyApp.Post do
        use MyApp.Model
        queryable "posts" do
          has_many :comments, MyApp.Comment
        end
      end

      defmodule MyApp.Comment do
        use MyApp.Model
        queryable "comments" do
          belongs_to :post, MyApp.Comment
        end
      end

  By using `MyApp.Model`, any `MyApp.Post` and `MyApp.Comment` entities
  will get the `:uuid` field, with type `:string` as the primary key.

  The `belongs_to` association on `MyApp.Comment` will also now require
  that `:post_id` be of `:string` type to reference the `:uuid` of a
  `MyApp.Post` entity.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Ecto.Query, only: [from: 2]
      import unquote(__MODULE__)
    end
  end

  @doc """
  Defines a queryable name and its entity.

  The source and entity can be accessed during the model compilation
  via `@ecto_source` and `@ecto_entity`.

  ## Example

      defmodule Post do
        use Ecto.Model
        queryable "posts", Post.Entity
      end

  """
  defmacro queryable(source, entity)

  @doc """
  Defines a queryable name and the entity definition inline. `opts` will be
  given to the `use Ecto.Entity` call, see `Ecto.Entity`.

  ## Examples

      # The two following Model definitions are equivalent
      defmodule Post do
        use Ecto.Model

        queryable "posts" do
          field :text, :string
        end
      end

      defmodule Post do
        use Ecto.Model

        defmodule Entity do
          use Ecto.Entity, model: Post
          field :text, :string
        end

        queryable "posts", Entity
      end

  """
  defmacro queryable(source, opts // [], do: block)

  defmacro queryable(source, opts, [do: block]) do
    quote do
      opts =
        (Module.get_attribute(__MODULE__, :queryable_defaults) || [])
        |> Keyword.merge(unquote(opts))
        |> Keyword.put(:model, __MODULE__)

      defmodule Entity do
        use Ecto.Entity, opts
        unquote(block)
      end

      queryable(unquote(source), Entity)
    end
  end

  defmacro queryable(source, [], entity) do
    quote do
      @ecto_source unquote(source)
      @ecto_entity unquote(entity)

      @doc "Delegates to #{@ecto_entity}.new/0"
      def new(), do: @ecto_entity.new()

      @doc "Delegates to #{@ecto_entity}.new/1"
      def new(params), do: @ecto_entity.new(params)

      @doc false
      def __model__(:source), do: @ecto_source
      def __model__(:entity), do: @ecto_entity

      @doc false
      def __queryable__,
        do: Ecto.Query.Query[from: { @ecto_source, @ecto_entity, __MODULE__ }]
    end
  end
end
