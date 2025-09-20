import gleam/int
import gleam/list
import glisten

pub fn get_client_source_string(conn: glisten.Connection(a)) -> String {
  let combine_with_sep = fn(xs, transform, sep) {
    let max_index = list.length(xs) - 1
    list.index_fold(xs, "", fn(acc: String, num, index) {
      let sep = case index {
        n if n == max_index -> ""
        _ -> sep
      }
      acc <> transform(num) <> sep
    })
  }
  case glisten.get_client_info(conn) {
    Ok(address) -> {
      let ip_str = case address.ip_address {
        glisten.IpV4(a, b, c, d) ->
          combine_with_sep([a, b, c, d], int.to_string, ".") <> ":"
        glisten.IpV6(a, b, c, d, e, f, g, h) ->
          // for IPv6, parts that are 0 can be omitted,
          // but I'm too lazy to add that
          "["
          <> combine_with_sep([a, b, c, d, e, f, g, h], int.to_base16, ":")
          <> "]"
          <> ":"
      }
      ip_str <> int.to_string(address.port)
    }
    Error(_) -> " from unknown address"
  }
}
