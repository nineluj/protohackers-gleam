import gleam/erlang/process
import gleam/list
import gleam/option.{None}
import group_registry
import logging
import types.{
  type ChatMessage, type HandlerResponse, type ServerState, HandlerResponse,
  RegisteredUserConnection, ServerState, UnregisteredConnection, UserJoined,
  UserLeft, UserMessage,
}
import validation.{validate_name}

pub const chat_room = "main_chat"

fn broadcast_to_others(
  registry: group_registry.GroupRegistry(ChatMessage),
  sender_subject: process.Subject(ChatMessage),
  message: ChatMessage,
) {
  group_registry.members(registry, chat_room)
  |> list.filter(fn(member) { member != sender_subject })
  |> list.each(fn(member) { process.send(member, message) })
}

pub fn handle_name_setting(
  state: ServerState,
  msg: String,
) -> Result(HandlerResponse, String) {
  let requested_name = msg

  logging.log(logging.Debug, "Got name: [" <> requested_name <> "]")
  case validate_name(requested_name) {
    True -> {
      // todo, display existing client names
      logging.log(
        logging.Debug,
        "Accepted name " <> "[" <> requested_name <> "]",
      )
      logging.log(
        logging.Info,
        "User "
          <> "["
          <> requested_name
          <> "] connected from "
          <> state.remote_address,
      )

      broadcast_to_others(
        state.registry,
        state.chat_subject,
        UserJoined(requested_name),
      )

      Ok(HandlerResponse(
        ServerState(
          state.registry,
          state.chat_subject,
          state.remote_address,
          RegisteredUserConnection(requested_name),
        ),
        None,
      ))
    }
    False -> {
      logging.log(
        logging.Info,
        "Rejecting invalid name " <> "[" <> requested_name <> "]",
      )
      Error("Invalid username provided: " <> "[" <> requested_name <> "]")
    }
  }
}

pub fn on_close(state: types.ServerState) {
  // If user was registered, broadcast that they left
  case state.connection_state {
    RegisteredUserConnection(username) -> {
      broadcast_to_others(
        state.registry,
        state.chat_subject,
        UserLeft(username),
      )
    }
    UnregisteredConnection -> Nil
  }
}

/// Handle a message from a user
pub fn handle_packet_message(
  state: ServerState,
  msg: String,
) -> Result(HandlerResponse, String) {
  case state.connection_state {
    UnregisteredConnection -> {
      handle_name_setting(state, msg)
    }
    RegisteredUserConnection(username:) -> {
      logging.log(
        logging.Info,
        "User [" <> username <> "] sent message: " <> msg,
      )
      broadcast_to_others(
        state.registry,
        state.chat_subject,
        UserMessage(username, msg),
      )
      Ok(HandlerResponse(state, None))
    }
  }
}

/// Handle a message created by another actor
pub fn handle_chat_message(
  state: ServerState,
  cmd: ChatMessage,
) -> Result(HandlerResponse, String) {
  case state.connection_state {
    UnregisteredConnection -> Ok(HandlerResponse(state, None))
    RegisteredUserConnection(_) -> {
      let response_message = case cmd {
        UserMessage(sender, msg) -> "[" <> sender <> "] " <> msg <> "\n"
        UserJoined(user) -> "* " <> user <> " has entered the room\n"
        UserLeft(user) -> "* " <> user <> " has left the room\n"
      }
      Ok(HandlerResponse(state, option.Some(response_message)))
    }
  }
}
