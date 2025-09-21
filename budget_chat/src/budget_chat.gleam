import gleam/erlang/process
import glisten
import logging.{Info}
import server

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Debug)

  logging.log(Info, "Starting listener...")
  let assert Ok(_) =
    glisten.new(server.on_init, server.listener)
    |> glisten.with_close(server.on_close)
    |> glisten.bind("0.0.0.0")
    |> glisten.start(33_337)

  process.sleep_forever()
}
