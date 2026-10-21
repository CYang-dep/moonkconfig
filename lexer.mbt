///|
/// Tokens keep the original UTF-16 offset for diagnostics.
pub(all) struct Token {
  text : String
  quoted : Bool
  offset : Int32
} derive(Eq, Debug)

///|
fn whitespace(c : UInt16) -> Bool {
  c == 32 || c == 9 || c == 13 || c == 10
}

///|
pub fn identifier(text : String) -> Bool {
  if text.is_empty() {
    return false
  }
  for i in 0..<text.length() {
    let c = text[i].to_int()
    if !((c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      (c >= 48 && c <= 57) ||
      c == 95) {
      return false
    }
  }
  true
}

///|
/// Lex one logical line. Limits prevent accidentally loading unbounded inputs.
pub fn tokenize(text : String) -> Array[Token] raise ConfigError {
  if text.length() > 65536 {
    raise Invalid("logical line exceeds 65536 units")
  }
  for i in 0..<text.length() {
    if text[i] < 32 && text[i] != 9 {
      raise Invalid("control characters are unsupported in logical lines")
    }
  }
  let tokens : Array[Token] = []
  let mut i = 0
  while i < text.length() {
    if whitespace(text[i]) {
      i += 1
      continue
    }
    if text[i] == 35 {
      break
    }
    let start = i
    if text[i] == 34 || text[i] == 39 {
      let quote = text[i]
      i += 1
      let mut value = ""
      let mut closed = false
      while i < text.length() {
        if text[i] == quote {
          i += 1
          closed = true
          break
        }
        if text[i] == 92 {
          i += 1
          if i >= text.length() {
            raise Invalid("dangling quote escape")
          }
        }
        value += text[i:i + 1].to_owned()
        i += 1
      }
      if !closed {
        raise Invalid("unclosed quote at \{start}")
      }
      tokens.push({ text: value, quoted: true, offset: start, })
    } else if text[i] == 38 || text[i] == 124 {
      let c = text[i]
      i += 1
      if i >= text.length() || text[i] != c {
        raise Invalid("expected doubled logical operator")
      }
      i += 1
      tokens.push({
        text: text[start:i].to_owned(),
        quoted: false,
        offset: start,
      })
    } else if text[i] == 33 || text[i] == 61 || text[i] == 60 || text[i] == 62 {
      i += 1
      if i < text.length() && text[i] == 61 {
        i += 1
      }
      tokens.push({
        text: text[start:i].to_owned(),
        quoted: false,
        offset: start,
      })
    } else if text[i] == 40 || text[i] == 41 {
      i += 1
      tokens.push({
        text: text[start:i].to_owned(),
        quoted: false,
        offset: start,
      })
    } else {
      while i < text.length() &&
            !whitespace(text[i]) &&
            text[i] != 35 &&
            text[i] != 34 &&
            text[i] != 39 &&
            text[i] != 38 &&
            text[i] != 124 &&
            text[i] != 33 &&
            text[i] != 61 &&
            text[i] != 60 &&
            text[i] != 62 &&
            text[i] != 40 &&
            text[i] != 41 {
        if text[i] == 36 {
          raise Invalid("macro expansion is unsupported")
        }
        i += 1
      }
      if i == start {
        raise Invalid("invalid token at \{i}")
      }
      tokens.push({
        text: text[start:i].to_owned(),
        quoted: false,
        offset: start,
      })
    }
    if tokens.length() > 4096 {
      raise Invalid("too many tokens")
    }
  }
  tokens
}

///|
/// Escape strings in .config, prompts and generated C string constants.
pub fn quote_string(text : String) -> String raise ConfigError {
  for i in 0..<text.length() {
    if text[i] < 32 || text[i] == 127 {
      raise Invalid("control characters cannot be exported")
    }
  }
  let mut out = "\""
  for i in 0..<text.length() {
    if text[i] == 92 || text[i] == 34 {
      out += "\\"
    }
    out += text[i:i + 1].to_owned()
  }
  out + "\""
}

///|
#deprecated
pub extend Token with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Token with Eq::{equal, not_equal}
