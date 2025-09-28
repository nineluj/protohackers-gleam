import gleam/bit_array
import gleam/list
import gleam/option

pub type Split(a) {
  Split(message: option.Option(a), remaining: BitArray)
}

pub type Splitter(a, b) =
  fn(BitArray) -> Result(Split(a), b)

pub opaque type MessageBuffer(a, b) {
  MessageBuffer(buffer: BitArray, splitter: Splitter(a, b))
}

pub fn new(splitter: Splitter(a, b)) {
  MessageBuffer(<<>>, splitter)
}

pub fn do_split(
  mb: MessageBuffer(a, b),
  data: BitArray,
) -> Result(#(MessageBuffer(a, b), List(a)), b) {
  // prepend the existing buffer data
  let data = bit_array.append(mb.buffer, data)
  // use the splitter as many times as possible
  case split_recur(mb.splitter, data, []) {
    Ok(#(result_list, remain)) -> {
      Ok(#(MessageBuffer(remain, mb.splitter), result_list))
    }
    Error(e) -> Error(e)
  }
}

fn split_recur(
  splitter: Splitter(a, b),
  data: BitArray,
  acc: List(a),
) -> Result(#(List(a), BitArray), b) {
  case splitter(data) {
    Ok(Split(msg, remain)) -> {
      case msg {
        option.None -> Ok(#(list.reverse(acc), remain))
        option.Some(msg) -> split_recur(splitter, remain, [msg, ..acc])
      }
    }
    Error(e) -> Error(e)
  }
}
