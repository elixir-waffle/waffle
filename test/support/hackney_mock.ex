defmodule WaffleTest.Support.HackneyMock do
  @moduledoc """
  Shared helper for simulating hackney 4.5.2's `{async, :once}` message
  sequence in tests, used by both `WaffleTest.HTTPClient.Hackney` and
  `WaffleTest.Actions.Store`.

  In `{async, :once}` mode, hackney pushes `{:status, ...}` and
  `{:headers, ...}` (or a single `{:redirect, ...}`/`{:see_other, ...}`)
  unconditionally as soon as the response is parsed -- no `stream_next/1`
  call is needed to receive them. Only body chunks (and the trailing
  `:done`/`{:error, _}`) require an explicit `stream_next/1` call per item.

  `mock_hackney_messages/1` takes the full sequence of messages a real
  connection would send and splits it into:

    * `send_auto` - simulates the messages hackney pushes automatically;
      invoke from the `:hackney.get/4` mock.
    * `send_next` - simulates what a `stream_next/1` call releases, popping
      one queued message per call; invoke from the `:hackney.stream_next/1`
      mock.
  """

  @doc """
  Returns `{ref, send_auto, send_next}` for the given message sequence.
  """
  def mock_hackney_messages(messages) do
    ref = make_ref()
    test_pid = self()
    {auto, rest} = Enum.split_while(messages, &auto_message?/1)
    {:ok, agent} = Agent.start_link(fn -> rest end)

    send_auto = fn ->
      Enum.each(auto, &send(test_pid, {:hackney_response, ref, &1}))
    end

    send_next = fn ->
      case Agent.get_and_update(agent, fn
             [next | rest] -> {next, rest}
             [] -> {nil, []}
           end) do
        nil -> :ok
        msg -> send(test_pid, {:hackney_response, ref, msg})
      end
    end

    {ref, send_auto, send_next}
  end

  defp auto_message?({:status, _, _}), do: true
  defp auto_message?({:headers, _}), do: true
  defp auto_message?({:redirect, _, _}), do: true
  defp auto_message?({:see_other, _, _}), do: true
  defp auto_message?(_), do: false
end
