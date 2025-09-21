import gleam/option.{type Option, None, Some}
import types.{
  type AppState, type RegisteredUser, type UserAction, UserJoin, UserLeave,
  UserMessage,
}

pub fn handle_message(
  message: String,
  state: AppState,
) -> #(AppState, Option(Int)) {
  todo
}

fn format_user_action_message(user: RegisteredUser, action: String) {
  "* " <> user.user_name <> " has " <> action <> "\n"
}

/// Returns a String that should be displayed to the user
/// based on the processed action.
pub fn handle_user_action(state: AppState, action: UserAction) -> Option(String) {
  // TODO: handle anonymous users later
  let assert types.Registered(current_user) = state.client
  case action {
    UserJoin(user:) -> {
      case user == current_user {
        True -> None
        False -> Some(format_user_action_message(user, "entered the room"))
      }
    }
    UserLeave(user:) -> {
      case user == current_user {
        True -> None
        False -> Some(format_user_action_message(user, "left the room"))
      }
    }
    UserMessage(user:, message:) -> {
      case user == current_user {
        True -> None
        False -> Some("[" <> user.user_name <> "] " <> message <> "\n")
      }
    }
  }
}
