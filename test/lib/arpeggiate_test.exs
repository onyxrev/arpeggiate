defmodule Arpeggiate.PaidUserOperation do
  use Arpeggiate

  schema do
    field :name, :string
    field :credit_card_number, :integer
  end

  load fn params ->
    params_to_struct(params)
    |> cast(params, [:name, :credit_card_number])
    |> validate_required([:name, :credit_card_number])
  end

  def process(params) do
    validate()
    |> step(:run_credit_card, error: :bad_payment_method)
    |> step(:save_user)
    |> run(params)
  end

  def run_credit_card(params, state) do
    case params["credit_card_number"] do
      4242424242424242 ->
        {:ok, state}
      _ ->
        {:error, state}
    end
  end

  def bad_payment_method(_params, _state) do
    :payment_failed
  end

  def save_user(_params, state) do
    {:ok, Map.put(state, :id, "abc123")}
  end
end

defmodule ArpeggiateTest do
  use ExUnit.Case, async: false

  test "it runs steps and runs the error condition, returning the name of the failed step and the resulting error state" do
    result = Arpeggiate.PaidUserOperation.process(%{"name" => nil, "credit_card_number" => nil})
    {:error, changeset, :validate} = result

    errors = changeset.errors
    assert errors == [name: {"can't be blank", [validation: :required]},
                     credit_card_number: {"can't be blank", [validation: :required]}]

    result = Arpeggiate.PaidUserOperation.process(%{"name" => "Sally", "credit_card_number" => 4444000044440000})
    assert result == {:error, :payment_failed, :run_credit_card}
  end

  test "it runs steps, accumulating state, which it returns" do
    result = Arpeggiate.PaidUserOperation.process(%{"name" => "Sally", "credit_card_number" => 4242424242424242})
    assert result == {:ok, %{id: "abc123", name: "Sally", credit_card_number: 4242424242424242}}
  end
end
