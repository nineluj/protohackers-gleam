pub type ServerState {
  ServerState(
    remote_address: String,
    left_over_bytes: BitArray,
    app_state: AppState,
  )
}

pub type RegisteredUser {
  RegisteredUser(user_name: String)
}

pub type Client {
  Registered(user: RegisteredUser)
  Anonymous
}

pub type UserAction {
  UserLeave(user: RegisteredUser)
  UserJoin(user: RegisteredUser)
  // maybe I need to have a list here, since a client could
  // theoretically send many messages in one packet
  UserMessage(user: RegisteredUser, message: String)
}

pub type AppState {
  AppState(client: Client)
}
