pub type AppState {
  AppState(left_over_buffer: String, remote_address: String)
}

pub type NumberValue {
  IntValue(Int)
  FloatValue(Float)
}

pub type MethodNumberRequest {
  MethodNumberRequest(method: String, number: NumberValue)
}
