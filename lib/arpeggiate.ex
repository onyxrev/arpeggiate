defmodule Arpeggiate do
  defstruct steps: []

  defmacro __using__(__) do
    quote do
      use Ecto.Schema

      import Ecto
      import Ecto.Changeset
      import Arpeggiate

      @primary_key false
    end
  end

  defmacro run(operation, params) do
    quote do
      iterate_over_steps(__MODULE__, unquote(operation), unquote(params))
    end
  end

  defmacro params_to_struct(params) do
    quote do
      struct(__MODULE__, unquote(params))
    end
  end

  defmacro schema(do: block) do
    quote do
      schema("", do: unquote(block))
    end
  end

  defmacro load(fun) do
    quote do
      def validate do
        step(:validate, error: :invalid)
      end

      def validate(operation) do
        step(operation, :validate, error: :invalid)
      end

      def validate(params, state) do
        result = unquote(fun).(params)

        case result.valid? do
          true  ->
            {:ok, result.changes}
          false ->
            {:error, result}
        end
      end

      def invalid(params, state) do
        {:ok, state}
      end
    end
  end

  def step(name, clauses) when is_atom(name) do
    %Arpeggiate{}
    |> add_step(name, clauses)
  end

  def step(operation, name) do
    operation
    |> add_step(name, [])
  end

  def step(name) do
    %Arpeggiate{}
    |> add_step(name, [])
  end

  def step(operation, name, clauses) do
    operation
    |> add_step(name, clauses)
  end

  defp add_step(operation, name, clauses) do
    steps = operation
    |> Map.get(:steps)

    step = step_clauses_to_step(name, clauses)

    operation
    |> Map.put(:steps, steps ++ [step])
  end

  defp step_clauses_to_step(name, [error: error]) do
    %Arpeggiate.Step{name: name, error: error}
  end

  defp step_clauses_to_step(name, []) do
    %Arpeggiate.Step{name: name}
  end

  def iterate_over_steps(module, operation, params) do
    Enum.reduce(operation.steps, {:ok, nil}, fn step, memo ->
      process_step(module, step, params, memo)
    end)
  end

  defp process_step(module, step, params, {:ok, state}) do
    case apply(module, step.name, [params, state]) do
      {:ok, new_state} ->
        {:ok, new_state}
      {:error, error_state} ->
        process_error(module, step, params, error_state)
      result = {:error, _state, _name} ->
        result
    end
  end

  defp process_step(_module, _step, _params, failed_tuple = {:error, _failed_step_name, _state}) do
    failed_tuple
  end

  defp process_error(_module, %Arpeggiate.Step{error: nil}, _params, error_state) do
    {:ok, error_state}
  end

  defp process_error(module, %Arpeggiate.Step{name: name, error: error}, params, error_state) do
    {_status, state} = apply(module, error, [params, error_state])
    {:error, state, name}
  end
end
