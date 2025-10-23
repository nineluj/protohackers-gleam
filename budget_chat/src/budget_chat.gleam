import budget_chat/server
import budget_chat/user_tracker
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import glisten
import group_registry
import logging.{Info}

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Info)
  logging.log(Info, "Starting server...")

  // Here's how the message flow works:
  // 1. group_registry creates a "chat room" that processes can join
  // 2. When a connection is established, the connection process joins the chat room
  //    using group_registry.join(), which returns a Subject for receiving chat messages
  // 3. This chat Subject is added to a Selector so the connection can receive both:
  //    - TCP packets from the client (handled by Glisten automatically)
  //    - Chat messages from other users (User messages in the handler)
  // 4. When a user sends a message, we broadcast it to all members of the chat room
  //    using group_registry.members() to get all the Subjects, then process.send()
  //    to each one (except the sender to avoid echo)
  // 5. Each connection process receives the chat message through its Selector
  //    and forwards it to the TCP client
  // 6. group_registry automatically cleans up when processes terminate
  // Useful links:
  // - https://github.com/rawhat/glisten/issues/23#issuecomment-2438887228
  // - https://hexdocs.pm/group_registry/index.html
  // - https://hexdocs.pm/gleam_erlang/gleam/erlang/process.html#Selector

  let registry_name = process.new_name("chat_registry")
  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(group_registry.supervised(registry_name))
    |> supervisor.start()

  let registry = group_registry.get_registry(registry_name)
  let user_query_subject = user_tracker.register(registry)

  let assert Ok(_) =
    glisten.new(
      server.create_on_init(registry, user_query_subject),
      server.handler,
    )
    |> glisten.with_close(server.on_close)
    |> glisten.bind("0.0.0.0")
    |> glisten.start(33_337)

  process.sleep_forever()
}
