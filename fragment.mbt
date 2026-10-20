///|
/// Validated user requests; the resolver may constrain them by visibility.
pub struct Fragment {
  priv entries : Array[(String, Value)]
}

///|
pub fn Fragment::new() -> Fragment {
  { entries: [], }
}

///|
pub fn Fragment::values(self : Fragment) -> Map[String, Value] {
  let out = Map([])
  for (name, value) in self.entries {
    out[name] = value
  }
  out
}

///|
pub fn Schema::request(
  self : Schema,
  requests : Fragment,
  name : String,
  value : Value,
) -> Unit raise ConfigError {
  if value is Text(s) {
    ignore(quote_string(s))
  }
  let kind = self.kind(name)
  if !kind.accepts(value) {
    raise Invalid("invalid request type for " + name)
  }
  if kind == Hex && value is Number(n) && n < 0L {
    raise Invalid("hex request must be nonnegative")
  }
  for i, entry in requests.entries {
    if entry.0 == name {
      for j in i..<(requests.entries.length() - 1) {
        requests.entries[j] = requests.entries[j + 1]
      }
      ignore(requests.entries.pop())
      break
    }
  }
  requests.entries.push((name, value))
}

///|
/// Rightmost fragment wins. Returned fragments never alias input arrays.
pub fn merge_fragments(fragments : Array[Fragment]) -> Fragment {
  let out = Fragment::new()
  for fragment in fragments {
    for entry in fragment.entries {
      for i, previous in out.entries {
        if previous.0 == entry.0 {
          for j in i..<(out.entries.length() - 1) {
            out.entries[j] = out.entries[j + 1]
          }
          ignore(out.entries.pop())
          break
        }
      }
      out.entries.push(entry)
    }
  }
  out
}

///|
fn config_value(kind : Kind, raw : String) -> Value raise ConfigError {
  match kind {
    Boolean | Tristate => {
      let v = Logic(parse_tri(raw))
      if !kind.accepts(v) {
        raise Invalid("m is not valid for a boolean")
      }
      v
    }
    StringType => {
      let ts = tokenize(raw)
      if ts.length() != 1 || !ts[0].quoted {
        raise Invalid("string assignment must be quoted")
      }
      Text(ts[0].text)
    }
    Integer | Hex => {
      if kind == Integer && (raw.contains("x") || raw.contains("X")) {
        raise Invalid("integer assignments require decimal digits")
      }
      let value = if kind == Hex { parse_hex(raw) } else { parse_number(raw) }
      if kind == Hex && value < 0L {
        raise Invalid("hex assignment must be nonnegative")
      }
      Number(value)
    }
  }
}

///|
/// Strict .config reader: unknown symbols and duplicates are actionable errors.
pub fn Schema::parse_config(
  self : Schema,
  text : String,
) -> Fragment raise ConfigError {
  if text.length() > 4194304 {
    raise Invalid("config input exceeds size limit")
  }
  let out = Fragment::new()
  let seen : Map[String, Bool] = Map([])
  for line_no, physical in text.split("\n").to_array() {
    let line = physical.trim().to_owned()
    if line.is_empty() {
      continue
    }
    try {
      let (name, value) = if line.has_prefix("# CONFIG_") &&
        line.has_suffix(" is not set") {
        let name = line[9:line.length() - 11].to_owned()
        let kind = self.kind(name)
        if kind != Boolean && kind != Tristate {
          raise Invalid("unset syntax needs logical symbol")
        }
        (name, Logic(N))
      } else if line.has_prefix("#") {
        continue
      } else {
        let pieces = line.split("=").to_array()
        if pieces.length() < 2 || !pieces[0].has_prefix("CONFIG_") {
          raise Invalid("expected CONFIG_NAME=value")
        }
        let name = pieces[0][7:].to_owned()
        let start = pieces[0].length() + 1
        (name, config_value(self.kind(name), line[start:].to_owned()))
      }
      if seen.contains(name) {
        raise Invalid("duplicate assignment " + name)
      }
      seen[name] = true
      self.request(out, name, value)
    } catch {
      Invalid(msg) =>
        raise Invalid(".config:" + (line_no + 1).to_string() + ": " + msg)
    }
  }
  out
}
