import gleam/erlang/process
import group_registry

pub type ServerState {
  ServerState(
    registry: group_registry.GroupRegistry(ChatMessage),
    chat_subject: process.Subject(ChatMessage),
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
