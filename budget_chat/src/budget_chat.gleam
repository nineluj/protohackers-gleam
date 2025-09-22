import gleam/erlang/process
import glisten
import logging.{Info}
import server
import types

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Debug)
  logging.log(Info, "Starting server...")

  // I haven't figured this out yet. Here's my brain-dump of how
  // I think that it works.
  // 1. A Subject is a value that processes can use to send
  // and receive messages to and from each other in a well typed way.
  // 2. A Selector is a type that enables a process to wait for messages
  // from multiple Subjects at the same time, returning whichever message arrives first.
  // 3. Glisten will create a selector from this subject, and a subject that triggers
  // messages based on received TCP packets.
  // 4. Passing the subject to each actor will allow them to send messages to each other.
  // Useful links:
  // - https://github.com/rawhat/glisten/issues/23#issuecomment-2438887228
  // - https://hexdocs.pm/gleam_erlang/gleam/erlang/process.html#Selector
  let subj = process.new_subject()
  let selector = process.new_selector() |> process.select(subj)

  let assert Ok(_) =
    glisten.new(server.create_on_init(subj, selector), server.handler)
    |> glisten.with_close(server.on_close)
    |> glisten.bind("0.0.0.0")
    |> glisten.start(33_337)

  // 10,000ms = 20s
  logging.log(logging.Critical, "Waiting to send admin message...")
  process.sleep(10_000)
  logging.log(logging.Critical, "Sending Admin message!")
  process.send(subj, types.SendMessage("Admin", "Hello my dear users"))
  process.sleep_forever()
}
