import gleam/list
import gleam/otp/actor
import types.{type UserTrackerMessage}

pub fn user_tracker_handler(state: List(String), message: UserTrackerMessage) {
  let new_state = case message {
    types.QueryUsers(reply) -> {
      actor.send(reply, state)
      state
    }
    types.UserChatMessage(user_message) -> {
      case user_message {
        types.UserJoined(username:) -> [username, ..state]
        types.UserLeft(username:) -> list.filter(state, fn(s) { s != username })
        // messages don't matter
        types.UserMessage(_, _) -> state
      }
    }
  }
  actor.continue(new_state)
}
