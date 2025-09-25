/// The user tracker is responsible for recording the users that join and leave,
/// and providing that information through a query subject so that each new client
/// can be made aware of all the existing users.
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/string
import group_registry
import logging
import protocol
import types.{type UserTrackerMessage}

pub fn register(
  registry: group_registry.GroupRegistry(types.ChatMessage),
) -> process.Subject(UserTrackerMessage) {
  let assert Ok(started) =
    // based on example from here:
    // https://github.com/lustre-labs/lustre/blob/d4eb9334a9e67a645c9f9dd19c6207b7576dc9f1/src/lustre/runtime/server/runtime.gleam#L62
    actor.new_with_initialiser(500, fn(self) {
      let pid = process.self()
      let chat_subject = group_registry.join(registry, protocol.chat_room, pid)

      logging.log(logging.Info, "UserTracker joined chat room")

      let selector =
        process.new_selector()
        |> process.select(self)
        |> process.select_map(chat_subject, types.UserChatMessage)

      actor.initialised([])
      |> actor.selecting(selector)
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(handler)
    |> actor.start()

  started.data
}

pub fn handler(state: List(String), message: UserTrackerMessage) {
  logging.log(
    logging.Debug,
    "UserTracker: " <> string.inspect(message) <> " received",
  )
  let new_state = case message {
    types.QueryUsers(reply) -> {
      actor.send(reply, state)
      state
    }
    types.UserChatMessage(user_message) -> {
      case user_message {
        types.UserJoined(username:) -> [username, ..state]
        types.UserLeft(username:) -> list.filter(state, fn(s) { s != username })
        // user messages don't matter
        types.UserMessage(_, _) -> state
      }
    }
  }
  actor.continue(new_state)
}
