/// The user tracker is responsible for recording the users that join and leave,
/// and providing that information through a query subject so that each new client
/// can be made aware of all the existing users.
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
  let message_subject = process.new_subject()

  // use the selector so that the actor can listen to query requests
  // and UserChatMessages
  let selector =
    process.new_selector()
    |> process.select(query_subject)
    |> process.select_map(message_subject, types.UserChatMessage)

  let assert Ok(user_tracker_actor) =
    actor.new([])
    |> actor.on_message(handler)
    // this needs an actor.Initialised, so it doesn't work at the moment
    |> actor.selecting(selector)
    |> actor.start()

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
