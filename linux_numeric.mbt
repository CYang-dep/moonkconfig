///|
fn valid_linux_number(raw : String, kind : Kind) -> Bool {
  if raw.is_empty() {
    return false
  }
  let mut i = 0
  if kind == Integer && raw[0] == 45 {
    i = 1
  }
  if kind == Hex && (raw.has_prefix("0x") || raw.has_prefix("0X")) {
    i = 2
  }
  if i == raw.length() {
    return false
  }
  if kind == Integer && raw[i] == 48 && i + 1 < raw.length() {
    return false
  }
  for j in i..<raw.length() {
    let c = raw[j]
    if !((c >= 48 && c <= 57) ||
      (kind == Hex && ((c >= 65 && c <= 70) || (c >= 97 && c <= 102)))) {
      return false
    }
  }
  true
}

///|
fn linux_initial(kind : Kind) -> Value {
  match kind {
    Integer => RawNumber("0", Integer)
    Hex => RawNumber("0x0", Hex)
    _ => kind.initial()
  }
}

///|
// Parse the C oracle's numeric comparison domain with explicit overflow checks.
// The result carries unsigned bits; signed conversion is deferred until both
// operands are known. Unknown constants use C base-0 (including octal).
fn linux_digits(raw : String, kind : Kind?) -> (UInt64, Bool)? {
  if kind == Some(Boolean) || kind == Some(Tristate) {
    return match raw {
      "n" => Some((0UL, false))
      "m" => Some((1UL, false))
      "y" => Some((2UL, false))
      _ => None
    }
  }
  if raw.is_empty() {
    return None
  }
  let mut i = 0
  let negative = raw[0] == 45
  if negative || raw[0] == 43 {
    i += 1
  }
  let unsigned = kind == Some(Hex)
  let mut base = if unsigned { 16 } else { 10 }
  if kind == None && i < raw.length() && raw[i] == 48 {
    base = 8
  }
  if i + 1 < raw.length() &&
    raw[i] == 48 &&
    (raw[i + 1] == 120 || raw[i + 1] == 88) &&
    (unsigned || kind == None) {
    base = 16
    i += 2
  }
  if i >= raw.length() {
    return None
  }
  let limit : UInt64 = if unsigned {
    18446744073709551615UL
  } else if negative {
    9223372036854775808UL
  } else {
    9223372036854775807UL
  }
  let mut n = 0UL
  for j in i..<raw.length() {
    let c = raw[j].to_int()
    let digit = if c >= 48 && c <= 57 {
      c - 48
    } else if c >= 65 && c <= 70 {
      c - 55
    } else if c >= 97 && c <= 102 {
      c - 87
    } else {
      return None
    }
    if digit >= base {
      return None
    }
    let d = digit.to_uint64()
    let b = base.to_uint64()
    if n > (limit - d) / b {
      return None
    }
    n = n * b + d
  }
  Some((if negative { 0UL - n } else { n }, unsigned))
}

///|
fn linux_operand(
  expr : Expr,
  values : Map[String, Value],
) -> (String, Kind?, Bool) {
  match expr {
    NumericLiteral(raw, _) => (raw, None, false)
    SymbolRef(name) =>
      match values.get(name) {
        Some(RawNumber(raw, kind)) => (raw, Some(kind), false)
        Some(Text(raw)) => (raw, Some(StringType), false)
        Some(Logic(t)) => (t.text(), Some(Tristate), false)
        Some(v) => (v.text(), Some(Integer), false)
        None => (name, None, false)
      }
    Constant(Text(raw)) => (raw, None, false)
    Constant(Logic(t)) => (t.text(), Some(Tristate), false)
    _ => (expr.evaluate(values, linux612=true).text(), None, false)
  }
}

///|
fn linux_compare(a : Expr, b : Expr, values : Map[String, Value]) -> Int32 {
  let (x, xkind, _) = linux_operand(a, values)
  let (y, ykind, _) = linux_operand(b, values)
  if xkind == Some(StringType) && ykind == Some(StringType) {
    return x.lexical_compare(y)
  }
  match (linux_digits(x, xkind), linux_digits(y, ykind)) {
    (Some((n, u)), Some((m, v))) =>
      if u || v {
        n.compare(m)
      } else {
        n.reinterpret_as_int64().compare(m.reinterpret_as_int64())
      }
    _ => x.lexical_compare(y)
  }
}

///|
fn linux_range_number(raw : String, kind : Kind) -> Int64 {
  // strtoll with an explicit radix accepts a prefix and saturates on overflow.
  let mut i = 0
  while i < raw.length() &&
        (raw[i] == 32 || raw[i] == 9 || raw[i] == 10 || raw[i] == 13) {
    i += 1
  }
  let negative = i < raw.length() && raw[i] == 45
  if i < raw.length() && (raw[i] == 45 || raw[i] == 43) {
    i += 1
  }
  let base = if kind == Hex { 16UL } else { 10UL }
  if kind == Hex &&
    i + 2 < raw.length() &&
    raw[i] == 48 &&
    (raw[i + 1] == 120 || raw[i + 1] == 88) {
    i += 2
  }
  let limit = if negative {
    9223372036854775808UL
  } else {
    9223372036854775807UL
  }
  let mut n = 0UL
  while i < raw.length() {
    let c = raw[i].to_int()
    let digit = if c >= 48 && c <= 57 {
      c - 48
    } else if c >= 65 && c <= 70 {
      c - 55
    } else if c >= 97 && c <= 102 {
      c - 87
    } else {
      break
    }
    let d = digit.to_uint64()
    if d >= base {
      break
    }
    if n > (limit - d) / base {
      return if negative {
        -9223372036854775807L - 1L
      } else {
        9223372036854775807L
      }
    }
    n = n * base + d
    i += 1
  }
  (if negative { 0UL - n } else { n }).reinterpret_as_int64()
}
