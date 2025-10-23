/// The user tracker is responsible for recording the users that join and leave,
/// and providing that information through a query subject so that each new client
/// can be made aware of all the existing users.
import budget_chat/protocol
import budget_chat/types.{type ChatMessage, type UserTrackerMessage}
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/string
import group_registry
import logging

type State {
  State(
    users: Dict(process.Pid, String),
    registry: group_registry.GroupRegistry(ChatMessage),
    chat_subject: process.Subject(ChatMessage),
  )
}

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
        |> process.select_monitors(types.UserProcessDown)

      actor.initialised(State(
        users: dict.new(),
        registry: registry,
        chat_subject: chat_subject,
      ))
      |> actor.selecting(selector)
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(handler)
    |> actor.start()

  started.data
}

fn broadcast_to_others(
  state: State,
  message: ChatMessage,
  exclude_pid: process.Pid,
) {
  group_registry.members(state.registry, protocol.chat_room)
  |> list.filter(fn(member) {
    case process.subject_owner(member) {
      Ok(pid) -> member != state.chat_subject && pid != exclude_pid
      Error(_) -> False
    }
  })
  |> list.each(fn(member) { process.send(member, message) })
}

fn handler(state: State, message: UserTrackerMessage) {
  logging.log(
    logging.Debug,
    "UserTracker: " <> string.inspect(message) <> " received",
  )
  let new_state = case message {
    types.QueryUsers(reply) -> {
      let usernames = dict.values(state.users)
      actor.send(reply, usernames)
      state
    }
    types.UserChatMessage(user_message) -> {
      case user_message {
        types.UserJoined(username:, pid:) -> {
          // Monitor the process so we can clean up when it terminates
          let _monitor = process.monitor(pid)
          logging.log(
            logging.Debug,
            "Monitoring process "
              <> string.inspect(pid)
              <> " for user "
              <> username,
          )
          State(..state, users: dict.insert(state.users, pid, username))
        }
        types.UserLeft(username:) -> {
          // Find and remove the user by username
          let new_users =
            state.users
            |> dict.filter(fn(_pid, name) { name != username })
          State(..state, users: new_users)
        }
        // user messages don't matter
        types.UserMessage(_, _) -> state
      }
    }
    types.UserProcessDown(down) -> {
      case down {
        process.ProcessDown(monitor: _monitor, pid: pid, reason: reason) -> {
          case dict.get(state.users, pid) {
            Ok(username) -> {
              logging.log(
                logging.Info,
                "Process "
                  <> string.inspect(pid)
                  <> " for user ["
                  <> username
                  <> "] terminated with reason: "
                  <> string.inspect(reason)
                  <> ", cleaning up and broadcasting UserLeft",
              )
              // Broadcast UserLeft message to notify other users
              broadcast_to_others(state, types.UserLeft(username), pid)

              State(..state, users: dict.delete(state.users, pid))
            }
            Error(_) -> {
              logging.log(
                logging.Debug,
                "Received ProcessDown for unknown pid " <> string.inspect(pid),
              )
              state
            }
          }
        }
        process.PortDown(_, _, _) -> state
      }
    }
  }
  actor.continue(new_state)
}
