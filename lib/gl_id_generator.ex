defmodule GLIDGenerator do
  @seed_div 100_000

  def init(mod) do
    ref = :atomics.new(1, signed: false)
    :persistent_term.put({mod, :ref}, ref)
  end

  def seed(mod) do
    ref = :persistent_term.get({mod, :ref})
    :atomics.add_get(ref, 1, 1) |> rem(@seed_div)
  end

  @doc """

  ## Example
      iex> GLIDGenerator.make(Test,0)
      {:error, "block_id must be in the range (0,100)"}

      iex> GLIDGenerator.make(Test,100)
      {:error, "block_id must be in the range (0,100)"}

      iex> GLIDGenerator.init(Test)
      iex> GLIDGenerator.make(Test,1,0)
      {:ok, 7001_010_000_000_100_001}

  """
  def make(mod, block_id, unixtime \\ System.os_time(:second)) do
    with true <- validate_block_id(block_id),
         {:ok, dt} <- validate_datetime(unixtime) do
      seed = seed(mod)
      {:ok, gen_id(dt, block_id, seed)}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_block_id(block_id) do
    if block_id > 0 and block_id < 100 do
      true
    else
      {:error, "block_id must be in the range (0,100)"}
    end
  end

  defp validate_datetime(unixtime) do
    with true <- is_integer(unixtime),
         {:ok, datetime} <- DateTime.from_unix(unixtime, :second),
         %{year: year, month: month, day: day, hour: hour, minute: minute, second: second} <-
           datetime do
      {:ok, {{year, month, day}, {hour, minute, second}}}
    else
      _ ->
        {:error, "unixtime is invalid"}
    end
  end

  @doc """
  Decodes a previously encoded entry.

  ## Example
      iex> GLIDGenerator.gen_id({{1,1, 1}, {1, 1, 1}},1,1)
      101_010_101_010_100_001
      iex> GLIDGenerator.gen_id({{1,1, 1}, {1, 1, 1}},1,2)
      101_010_101_010_100_002

      iex> GLIDGenerator.gen_id({{23, 11, 11}, {11, 11, 11}},11,1)
      2_311_111_111_111_100_001

      iex> GLIDGenerator.gen_id({{1,1, 1}, {1, 1, 1}},99,1)
      101_010_101_019_900_001

      iex> GLIDGenerator.gen_id({{1,1, 1}, {1, 1, 1}},100,1)
      101_010_101_010_000_001

  """
  @spec gen_id(
          {{integer(), number(), number()}, {number(), number(), number()}},
          integer(),
          integer()
        ) ::
          number()
  def gen_id({{year, month, day}, {hour, minute, second}}, block_id, seed) when year > 0 do
    year = rem(year, 100)
    block_id = block_id |> rem(100)

    year * 100_000_000_000_000_000 +
      month * 1_000_000_000_000_000 +
      day * 10_000_000_000_000 +
      hour * 100_000_000_000 +
      minute * 1_000_000_000 +
      second * 10_000_000 +
      block_id * 100_000 +
      seed
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      def init_generator(), do: GLIDGenerator.init(__MODULE__)

      def make_id(block_id, unixtime),
        do: GLIDGenerator.make(__MODULE__, block_id, unixtime)

      def gen_id(dt, block_id), do: GLIDGenerator.gen_id(dt, block_id, seed())
      defp seed(), do: GLIDGenerator.seed(__MODULE__)
    end
  end
end
