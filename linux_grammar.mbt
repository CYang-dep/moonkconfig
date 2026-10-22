///|
// Comparisons in parser.y have symbol operands, never parenthesized or chained
// expressions. Checking tokens retains distinctions erased by the public AST.
fn validate_linux_tokens(ts : Array[Token]) -> Unit raise ConfigError {
  for i, token in ts {
    if token.quoted || !["=", "!=", "<", ">", "<=", ">="].contains(token.text) {
      continue
    }
    if i == 0 || i + 1 >= ts.length() {
      raise Invalid("comparison needs two symbols")
    }
    for operand in [ts[i - 1], ts[i + 1]] {
      if !operand.quoted &&
        ["(", ")", "!", "&&", "||", "=", "!=", "<", ">", "<=", ">="].contains(
          operand.text,
        ) {
        raise Invalid("comparison operand must be a symbol")
      }
    }
    if i >= 2 &&
      !ts[i - 2].quoted &&
      ["=", "!=", "<", ">", "<=", ">="].contains(ts[i - 2].text) {
      raise Invalid("chained comparison")
    }
  }
}
