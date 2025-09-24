import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import group_registry
import protocol
import types.{type UserTrackerMessage}

pub fn register(
  registry: group_registry.GroupRegistry(types.ChatMessage),
) -> process.Subject(UserTrackerMessage) {
  let query_subject = process.new_subject()

  let assert Ok(user_tracker_actor) =
    actor.new([])
    |> actor.on_message(handler)
    |> actor.start()

  // the type sent here is not UserTrackerMessage since messages come from
  // the server actors that only send ChatMessage. Can we use a selector
  // to accept either?
  group_registry.join(registry, protocol.chat_room, user_tracker_actor.pid)

  query_subject
}

pub fn handler(state: List(String), message: UserTrackerMessage) {
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
