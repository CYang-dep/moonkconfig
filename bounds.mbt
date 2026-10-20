///|
fn Expr::validate_bounds(self : Expr) -> Unit raise ConfigError {
  let stack = [(self, 0)]
  let mut count = 0
  while !stack.is_empty() {
    let (expr, depth) = stack.pop().unwrap()
    count += 1
    if depth > 128 || count > 4096 {
      raise Invalid("expression tree exceeds depth/node budget")
    }
    match expr {
      Constant(Text(text)) => ignore(quote_string(text))
      Constant(_) | SymbolRef(_) => ()
      Negation(a) => stack.push((a, depth + 1))
      Conjunction(a, b) | Disjunction(a, b) | Comparison(_, a, b) => {
        stack.push((a, depth + 1))
        stack.push((b, depth + 1))
      }
    }
  }
}
