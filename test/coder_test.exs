defmodule SkynetCoderTest do
  use ExUnit.Case
  alias Skynet.Coder
 
  @m %{
    a: nil,
    b: true,
    c: false,
    d: 1,
    e: 0xab,
    e1: 0xabcd,
    e2: 0xabcdef,
    e3: 0xabcdefabcd,
    f4: -1,
    g: 1.1,
    h: "hello",
    i: "1234567890123456789012345678901234567890",
    j: [1, 2, 3, "a", "b", "c"],
    k: %{
      1=> 1,
      2=> 3,
    }
  }

  test "code map" do
    encodedecode(@m)
  end

  test "code single" do
    Enum.map(@m, fn {_k, v} -> encodedecode(v) end)
  end

  test "code tuple" do
    encodedecode({@m, @m, 1, nil, 3})
  end

  defp encodedecode(v) do
    data = Coder.encode(v) |> :erlang.iolist_to_binary
    assert v == Coder.decode(data, true)
  end
end
