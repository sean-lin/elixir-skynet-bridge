defmodule Skynet.Coder.Helper do
  defmacro combine_type(t, v) do
    t = Macro.expand_once(t, __CALLER__)
    v = Macro.expand_once(v, __CALLER__)
  
    bin = combine_type_dynamic(t, v)
    quote do
      unquote(bin)
    end
  end

  def combine_type_dynamic(t, v) do
    <<v::5, t::3>>
  end
end

defmodule Skynet.Coder do
  require Skynet.Coder.Helper, as: Helper
  
  defmodule DecodeError do
    @moduledoc """
    Error raised when the request body cannot be parsed.
    """

    defexception message:  "decode error"
  end

  @type_nil 0
  @type_boolean 1
  # hibits 0 false 1 true
  
  @type_number 2
  # hibits 0 : 0 , 1: byte, 2:word, 4: dword, 6: qword, 8 : double

  @type_number_zero 0
  @type_number_byte 1
  @type_number_word 2
  @type_number_dword 4
  @type_number_qword 6
  @type_number_real 8

  #@type_userdata 3
  @type_short_string 4
  # hibits 0~31 : len
  
  @type_long_string 5
  @type_table 6

  @max_cookie 32

  def encode(msg) when is_tuple(msg) do
    msg
    |> Tuple.to_list
    |> Enum.map(&encode_one/1)
  end
  def encode(msg) do
    encode_one(msg)
  end

  def decode(msg, opt \\ false) do
    decode_loop(msg, 0, [], opt)
  end
  
  defp decode_loop(<<>>, 0, [], _) do
    nil
  end
  defp decode_loop(<<>>, 1, [v], _) do
    v
  end
  defp decode_loop(<<>>, _n, acc, _) do
    acc
    |> :lists.reverse
    |> List.to_tuple
  end
  defp decode_loop(rest, n, acc, opt) do
    {v, rest} = decode_one(rest, opt)
    decode_loop(rest, n + 1, [v|acc], opt)
  end

  defp decode_one(<<v::5, t::3, rest::binary>>, opt) do
    decode_one(t, v, rest, opt)
  end
  
  defp decode_one(@type_nil, 0, rest, _opt) do
    {nil, rest}
  end
  defp decode_one(@type_boolean, 1, rest, _) do
    {true, rest}
  end
  defp decode_one(@type_boolean, 0, rest, _) do
    {false, rest}
  end
  defp decode_one(@type_number, @type_number_zero, rest, _) do
    {0, rest}
  end
  defp decode_one(@type_number, @type_number_byte, <<v::8, rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_number, @type_number_word, <<v::16, rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_number, @type_number_dword, <<v::size(32)-signed, rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_number, @type_number_qword, <<v::size(64)-signed, rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_number, @type_number_real, <<v::float-size(64), rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_short_string, len, rest, _) do
    <<v::binary-size(len), rest::binary>> = rest
    {v, rest}
  end
  defp decode_one(@type_long_string, 2, <<len::16, v::binary-size(len), rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_long_string, 4, <<len::32, v::binary-size(len), rest::binary>>, _) do
    {v, rest}
  end
  defp decode_one(@type_table, 0, rest, opt) do
    decode_map(rest, [], opt)
  end
  defp decode_one(@type_table, @max_cookie - 1, <<len::16, rest::binary>>, opt) do
    decode_list(rest, len, [], opt)
  end
  defp decode_one(@type_table, len, rest, opt) do
    decode_list(rest, len, [], opt)
  end
     
  defp decode_map(<<0, rest::binary>>, acc, _) do
    {:maps.from_list(acc), rest}
  end
  defp decode_map(rest, acc, opt) do
    {k, rest} = decode_one(rest, opt)
    k = if opt and is_binary(k) do
      String.to_existing_atom(k)
    else
      k
    end
    {v, rest} = decode_one(rest, opt)
    decode_map(rest, [{k, v}|acc], opt)
  end

  defp decode_list(<<0, rest::binary>>, 0, acc, _) do
    {:lists.reverse(acc), rest}
  end
  defp decode_list(_rest, 0, _acc, _opt) do
    raise DecodeError
  end
  defp decode_list(rest, n, acc, opt) do
    {i, rest} = decode_one(rest, opt)
    decode_list(rest, n - 1,  [i | acc], opt)
  end
  
  defp encode_one(nil) do
    Helper.combine_type(@type_nil, 0)  
  end
  defp encode_one(v) when is_integer(v) do
    encode_integer(v)
  end
  defp encode_one(v) when is_float(v) do
    encode_real(v)
  end
  defp encode_one(v) when is_boolean(v) do
    encode_bool(v)
  end
  defp encode_one(v) when is_atom(v) do
    bin = Atom.to_string(v)
    encode_binary(bin, byte_size(bin))
  end
  defp encode_one(v) when is_binary(v) do
    encode_binary(v, byte_size(v))
  end
  defp encode_one(v) when is_list(v) do
    encode_list(v)
  end
  defp encode_one(v) when is_map(v) do
    encode_map(v)
  end

  defp encode_integer(0) do
    Helper.combine_type(@type_number, @type_number_zero)
  end
  defp encode_integer(v) when -0x80000000 > v or v > 0x7fffffff do
    <<
    Helper.combine_type(@type_number, @type_number_qword)::binary,
    v::size(64)
    >>
  end
  defp encode_integer(v) when v < 0 do
    <<
    Helper.combine_type(@type_number, @type_number_dword)::binary,
    v::size(32)
    >>
  end
  defp encode_integer(v) when v < 0x100 do
    <<
    Helper.combine_type(@type_number, @type_number_byte)::binary,
    v::size(8)
    >>
  end
  defp encode_integer(v) when v < 0x10000 do
    <<
    Helper.combine_type(@type_number, @type_number_word)::binary,
    v::size(16)
    >>
  end
  defp encode_integer(v) do
    <<
    Helper.combine_type(@type_number, @type_number_dword)::binary,
    v::size(32)
    >>
  end

  defp encode_real(v) do
    <<
    Helper.combine_type(@type_number, @type_number_real)::binary,
    v::float-size(64)
    >>
  end

  defp encode_bool(true) do
    Helper.combine_type(@type_boolean, 1)
  end
  defp encode_bool(false) do
    Helper.combine_type(@type_boolean, 0)
  end

  defp encode_binary(binary, size) when size < @max_cookie do
    [
      Helper.combine_type_dynamic(@type_short_string, size),
      binary
    ]  
  end
  defp encode_binary(binary, size) when size < 0x10000 do
    [
      Helper.combine_type_dynamic(@type_long_string, 2),
      <<size::size(16)>>,
      binary
    ]  
  end
  defp encode_binary(binary, size) do
    [
      Helper.combine_type_dynamic(@type_long_string, 4),
      <<size::size(32)>>,
      binary
    ]  
  end

  defp encode_map(map) do
    part = :maps.fold(fn(nil, _v, _acc) -> raise DecodeError       # key 不能是nil
      (k, v, acc) ->
        [encode_one(v), encode_one(k)|acc]
    end,
    [Helper.combine_type(@type_table, 0)],
    map)
  [<<0>>|part] |> :lists.reverse
  end

  defp encode_list(l) do
    body = encode_list_loop(l, [])
    len = length(l)

    if len >= @max_cookie - 1 do
      [
        Helper.combine_type_dynamic(@type_table, @max_cookie - 1),
        encode_integer(len) |body
      ]
    else
      [Helper.combine_type_dynamic(@type_table, len) | body]
    end 
  end

  defp encode_list_loop([], acc) do
    [<<0>>|acc] |> :lists.reverse
  end
  defp encode_list_loop([h|rest], acc) do
    encode_list_loop(rest, [encode_one(h) | acc])
  end
end
