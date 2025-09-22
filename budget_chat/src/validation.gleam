import gleam/list
import gleam/string

pub fn validate_name(name: String) -> Bool {
  case string.length(name) {
    0 -> False
    _ -> {
      name
      |> string.to_utf_codepoints
      |> list.all(fn(codepoint) {
        let code = string.utf_codepoint_to_int(codepoint)
        // a-z: 97-122, A-Z: 65-90, 0-9: 48-57
        { code >= 97 && code <= 122 }
        || { code >= 65 && code <= 90 }
        || { code >= 48 && code <= 57 }
      })
    }
  }
}
