import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import glisten
import logging.{Info}
import server
import types

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Info)

  logging.log(Info, "Starting listener...")
  let assert Ok(_) =
    glisten.new(server.on_init, server.listener)
    |> glisten.with_close(server.on_close)
    |> glisten.bind("0.0.0.0")
    |> glisten.start(33_337)

  process.sleep_forever()
}
