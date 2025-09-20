import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import gleam/option.{None}

import glisten.{Packet}

fn listener(
  state: Nil,
  msg: glisten.Message(a),
  conn: glisten.Connection(a),
) -> glisten.Next(Nil, glisten.Message(a)) {
  io.println("Got message")
  let assert Packet(msg) = msg
  let assert Ok(_) = glisten.send(conn, bytes_tree.from_bit_array(msg))
  glisten.continue(state)
}

pub fn main() -> Nil {
  io.println("Starting listener...")
  let assert Ok(_) =
    glisten.new(fn(_conn) { #(Nil, None) }, listener)
    |> glisten.bind("0.0.0.0")
    |> glisten.start(33_337)

  process.sleep_forever()
}
