///|
pub(all) enum Expr {
  Constant(Value)
  NumericLiteral(String, Int64)
  SymbolRef(String)
  Negation(Expr)
  Conjunction(Expr, Expr)
  Disjunction(Expr, Expr)
  Comparison(String, Expr, Expr)
} derive(Eq, Debug)

///|
/// Checked signed decimal/hex input without host-dependent conversions.
pub fn parse_number(text : String) -> Int64 raise ConfigError {
  if text.is_empty() {
    raise Invalid("empty number")
  }
  let mut i = 0
  let negative = text[0] == 45
  if negative || text[0] == 43 {
    i += 1
  }
  let mut base = 10L
  if i + 1 < text.length() &&
    text[i] == 48 &&
    (text[i + 1] == 120 || text[i + 1] == 88) {
    base = 16L
    i += 2
  }
  if i == text.length() {
    raise Invalid("number has no digits")
  }
  let limit = if negative {
    -9223372036854775807L - 1L
  } else {
    -9223372036854775807L
  }
  let mut acc = 0L
  while i < text.length() {
    let c = text[i].to_int()
    let d = if c >= 48 && c <= 57 {
      c - 48
    } else if c >= 65 && c <= 70 {
      c - 55
    } else if c >= 97 && c <= 102 {
      c - 87
    } else {
      raise Invalid("invalid number: " + text)
    }
    let digit = d.to_int64()
    if digit >= base || acc < limit / base {
      raise Invalid("numeric overflow or digit")
    }
    acc *= base
    if acc < limit + digit {
      raise Invalid("numeric overflow")
    }
    acc -= digit
    i += 1
  }
  if negative {
    acc
  } else {
    -acc
  }
}

///|
pub fn Expr::evaluate(
  self : Expr,
  values : Map[String, Value],
  linux612~ : Bool = false,
) -> Value {
  match self {
    Constant(v) => v
    NumericLiteral(_, n) => Number(n)
    SymbolRef(name) => values.get(name).unwrap_or(Text(name))
    Negation(a) => Logic(a.evaluate(values, linux612~).logic().negate())
    Conjunction(a, b) =>
      Logic(
        a
        .evaluate(values, linux612~)
        .logic()
        .meet(b.evaluate(values, linux612~).logic()),
      )
    Disjunction(a, b) =>
      Logic(
        a
        .evaluate(values, linux612~)
        .logic()
        .join(b.evaluate(values, linux612~).logic()),
      )
    Comparison(op, a, b) => {
      let x = a.evaluate(values, linux612~)
      let y = b.evaluate(values, linux612~)
      let order = if linux612 {
        linux_compare(a, b, values)
      } else {
        match (x, y) {
          (Number(n), Number(m)) => n.compare(m)
          _ => x.text().compare(y.text())
        }
      }
      let yes = match op {
        "=" => order == 0
        "!=" => order != 0
        "<" => order < 0
        ">" => order > 0
        "<=" => order <= 0
        ">=" => order >= 0
        _ => false
      }
      Logic(if yes { Y } else { N })
    }
  }
}

///|
pub fn Expr::references(self : Expr) -> Array[String] {
  let out : Array[String] = []
  fn visit(expr : Expr) -> Unit {
    match expr {
      SymbolRef(s) => if !out.contains(s) { out.push(s) }
      Negation(a) => visit(a)
      Conjunction(a, b) | Disjunction(a, b) | Comparison(_, a, b) => {
        visit(a)
        visit(b)
      }
      Constant(_) | NumericLiteral(_, _) => ()
    }
  }
  visit(self)
  out
}

///|
#deprecated
pub extend Expr with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Expr with Eq::{equal, not_equal}
