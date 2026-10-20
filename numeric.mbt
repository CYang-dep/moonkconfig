///|
fn parse_hex(text : String) -> Int64 raise ConfigError {
  if text.is_empty() || text.has_prefix("-") || text.has_prefix("+") {
    raise Invalid("hex requires unsigned digits")
  }
  parse_number(
    if text.has_prefix("0x") || text.has_prefix("0X") {
      text
    } else {
      "0x" + text
    },
  )
}

///|
fn Expr::typed_value(
  self : Expr,
  kind : Kind,
  values : Map[String, Value],
) -> Value raise ConfigError {
  match self {
    NumericLiteral(raw, n) =>
      match kind {
        Hex => Number(parse_hex(raw))
        StringType => Text(raw)
        Integer => {
          if raw.contains("x") || raw.contains("X") {
            raise Invalid("integer defaults require decimal literals")
          }
          Number(n)
        }
        _ => Logic(N)
      }
    // Unquoted A-F-only hex literals are lexically indistinguishable from
    // undefined references. Defined symbols always take precedence.
    SymbolRef(raw) =>
      if kind == Hex && !values.contains(raw) {
        Number(parse_hex(raw))
      } else {
        typed_default(self.evaluate(values), kind)
      }
    _ => typed_default(self.evaluate(values), kind)
  }
}
