import gleam/erlang/process
import gleam/option
import group_registry
import message_buffer.{type MessageBuffer}

pub type ServerState {
  ServerState(
    // todo: move the first three into ServerMessaging type
    registry: group_registry.GroupRegistry(ChatMessage),
    chat_subject: process.Subject(ChatMessage),
    user_query_subject: process.Subject(UserTrackerMessage),
    message_buffer: MessageBuffer(String, String),
    remote_address: String,
    // todo: move this into a separate AppState type, so that the protocol doesn't
    // get exposed to the server specifics
    connection_state: ConnectionState,
  )
}

pub type ConnectionState {
  UnregisteredConnection
  RegisteredUserConnection(username: String)
}

pub type ChatMessage {
  UserMessage(sender: String, message: String)
  UserJoined(username: String)
  UserLeft(username: String)
}

pub type HandlerResponse {
  HandlerResponse(
    new_state: ServerState,
    message_to_send: option.Option(String),
  )
}

pub type UserTrackerMessage {
  UserChatMessage(message: ChatMessage)
  QueryUsers(process.Subject(List(String)))
}
