[![Build Status](https://semaphoreci.com/api/v1/onyxrev/arpeggiate/branches/master/badge.svg)](https://semaphoreci.com/onyxrev/arpeggiate)

# Arpeggiate

Write step operations with input validation, type casting, and error handling.

## Steps

Quite often in software you want to perform a series of steps towards an end result while gracefully handling error conditions. This is the goal of arpeggiate. With arpeggiate, you can define any number of steps to perform. Each step hands its state to the next step in a functional way using `{:ok, state}`. Error handlers can be defined for each step to facilitate cleanup or other such error-handling activities. Triggering the error state is as simple as returning an `{:error, state}` tuple. Error handlers are optional. Steps without error handlers will proceed to the next step regardless of their outcome.

Generally you want to work with step state, but occasionally directly accessing the raw params as passed into the operation is useful. As such, steps may be either arity 1 `(state)` or, if you require access to the params in a step or error handler, arity 2 `(state, params)` is also supported.

## Schema

Arpeggiate leverages many of the robust casting and validation features of the Ecto project to process each operation's input parameters. Arpeggiate's operation state is an `Ecto.Changeset`, which provides a familiar interface for changing the state and handling error messages.

The schema of the operation state is defined by passing a `schema` block.

## Loading

Typically input parameters are cast to the state struct and validation is optionally run. We do this by defining a load method that receives the params and converts it into state.

## Processing

To run the operation, we call `process` with the input parameters. If the whole operation succeeds, an `{:ok, state}` tuple is returned, with state being the state returned by the last step. In the error case, the step sequence is halted, an `{:error, state, validation_step}` tuple is returned, with state being the state returned by the failing step's error handler and `validation_step` being the name of the step that failed (represented as an atom).

If you need validation, call `validate` right away and pass the result to the steps. If you don't need validation, you can call `step` directly.

## Example

Let's say we want to take some money from Sam in exchange for baking him a pie. If baking the pie fails, we want to clean up by sending Sam a refund and an apology email.

```elixir
defmodule PayForPie do
  use Arpeggiate

  schema do
    field :email, :string
    field :pie_type, :string
    field :credit_card_number, :integer

    # let's say we have a Payment struct defined in our app, we can cast the
    # result of payment into a Payment struct using Ecto embedding
    embeds_one :payment, Payment
  end

  load fn params ->
    # you can use any Ecto validation you want here, including any custom
    # validators you have written
    params_to_struct(params)
    |> cast(params, [:email, :pie_type, :credit_card_number])
    |> validate_required([:email, :pie_type, :credit_card_number])
  end

  def process(params) do
    validate()
    |> step(:run_credit_card, error: :payment_failed)
    |> step(:bake_pie, error: :baking_failed)
    |> run(params)
  end

  # --- step 1

  # steps can be defined with arity 1 or arity 2, taking either (state, params)
  # arguments, or just (state) if params aren't needed for the particular step
  def run_credit_card(state, params) do
    {status, payment} = CreditCard.charge(state.credit_card_number)

    # if the result of CreditCard.charge is an {:ok, payment} tuple, the
    # operation will continue to the next step with the updated state. if the
    # result is an {:error, payment} tuple, the operation will halt and run the
    # error handler specified for the step. in either case we want to cast the
    # payment into the state
    {status, state |> cast_embed(:payment, payment)}
  end

  def payment_failed(state) do
    # no need for a status tuple since this is always an error condition
    :payment_failed
  end

  # --- step 2

  # here's an example of an arity 1 step where params aren't used
  def bake_pie(state) do
    # if Pie.bake returns an {:ok, pie} tuple, the operation will return the
    # pie. if Pie.bake returns an {:error, _something_else} tuple, the
    # operation will run the error handler specified for the step
    Pie.bake(state.pie_type)
  end

  def baking_failed(state) do
    {:ok, refund} = CreditCard.refund(payment.id)
    {:ok, email} = Mailer.send_apology(state.email)
    {:error, state}
  end
end
```

With this operation, you'd call it like so:

```elixir
case PayForPie.process(
  %{
    "email" => "sam@example.org",
    "pie_type" => "cherry",
    "credit_card_number" => "4242424242424242"
  }
) do
  {:ok, pie} ->
    # everything succeeded!
  {:error, :payment_failed, :run_credit_card} ->
    # uh oh
end
```
