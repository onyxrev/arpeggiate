defmodule Arpeggiate do
  defstruct steps: []

  defmacro __using__(_opts) do
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

      def validate(state, params) do
        result = unquote(fun).(params)

        case result.valid? do
          true  ->
            {:ok, result.changes}
          false ->
            {:error, result}
        end
      end

      def invalid(state, params) do
        state
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
    # allow folks to define steps with either state and params
    # (step/2) or just state arguments (step/1)
    result = apply_step_with_params(module, step, state, params) ||
             apply_step_without_params(module, step, state, params) ||
             raise "#{module} processing hit step :#{step.name} but it is undefined"

    case result do
      {:ok, new_state} ->
        {:ok, new_state}
      {:error, error_state} ->
        process_error(module, step, params, error_state)
      {:error, _state, _name} ->
        result
    end
  end

  defp process_step(_module, _step, _params, failed_tuple = {:error, _failed_step_name, _state}) do
    failed_tuple
  end

  defp apply_step_with_params(module, step, state, params) do
    if function_exported?(module, step.name, 2) do
      apply(module, step.name, [state, params])
    end
  end

  defp apply_step_without_params(module, step, state, _params) do
    if function_exported?(module, step.name, 1) do
      apply(module, step.name, [state])
    end
  end

  defp process_error(_module, %Arpeggiate.Step{error: nil}, _params, error_state) do
    {:ok, error_state}
  end

  defp process_error(module, %Arpeggiate.Step{name: name, error: error}, params, error_state) do
    result = process_error_with_params(module, error, error_state, params) ||
             process_error_without_params(module, error, error_state, params) ||
             raise "#{module} error handler :#{error} specified but it is undefined"

    {:error, result, name}
  end

  defp process_error_with_params(module, error, error_state, params) do
    if function_exported?(module, error, 2) do
      apply(module, error, [error_state, params])
    end
  end

  defp process_error_without_params(module, error, error_state, _params) do
    if function_exported?(module, error, 1) do
      apply(module, error, [error_state])
    end
  end
end
