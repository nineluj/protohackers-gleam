import gleam/erlang/process
import gleam/option
import group_registry

pub type ServerState {
  ServerState(
    registry: group_registry.GroupRegistry(ChatMessage),
    chat_subject: process.Subject(ChatMessage),
    user_query_subject: process.Subject(UserTrackerMessage),
    remote_address: String,
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
