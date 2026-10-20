///|
fn atom(token : Token) -> Expr raise ConfigError {
  if token.quoted {
    return Constant(Text(token.text))
  }
  match token.text {
    "n" => Constant(Logic(N))
    "m" => Constant(Logic(M))
    "y" => Constant(Logic(Y))
    s => {
      if s.is_empty() {
        raise Invalid("empty atom")
      }
      let c = s[0]
      if (c >= 48 && c <= 57) || c == 45 || c == 43 {
        NumericLiteral(s, parse_number(s))
      } else if identifier(s) {
        SymbolRef(s)
      } else {
        raise Invalid("invalid expression atom " + s)
      }
    }
  }
}

///|
fn precedence(op : String) -> Int32 {
  match op {
    "||" => 1
    "&&" => 2
    "=" | "!=" | "<" | ">" | "<=" | ">=" => 4
    _ => 0
  }
}

///|
fn expression_tokens(
  tokens : Array[Token],
  cursor : Ref[Int32],
  min : Int32,
  depth : Int32,
) -> Expr raise ConfigError {
  if depth > 128 {
    raise Invalid("expression nesting exceeds 128")
  }
  if cursor.val >= tokens.length() {
    raise Invalid("missing expression operand")
  }
  let t = tokens[cursor.val]
  cursor.val += 1
  let mut lhs = if !t.quoted && t.text == "!" {
    Negation(expression_tokens(tokens, cursor, 3, depth + 1))
  } else if !t.quoted && t.text == "(" {
    let inner = expression_tokens(tokens, cursor, 1, depth + 1)
    if cursor.val >= tokens.length() || tokens[cursor.val].text != ")" {
      raise Invalid("unclosed expression parenthesis")
    }
    cursor.val += 1
    inner
  } else {
    atom(t)
  }
  while cursor.val < tokens.length() {
    let op = tokens[cursor.val]
    let p = if op.quoted { 0 } else { precedence(op.text) }
    if p < min || p == 0 {
      break
    }
    cursor.val += 1
    let rhs = expression_tokens(tokens, cursor, p + 1, depth + 1)
    lhs = match op.text {
      "&&" => Conjunction(lhs, rhs)
      "||" => Disjunction(lhs, rhs)
      s => Comparison(s, lhs, rhs)
    }
  }
  lhs
}

///|
pub fn parse_expression(text : String) -> Expr raise ConfigError {
  parse_expression_tokens(tokenize(text))
}

///|
fn parse_expression_tokens(tokens : Array[Token]) -> Expr raise ConfigError {
  if tokens.length() > 256 {
    raise Invalid("expression exceeds 256 tokens")
  }
  let cursor = Ref(0)
  let expr = expression_tokens(tokens, cursor, 1, 0)
  if cursor.val != tokens.length() {
    raise Invalid("unexpected expression token " + tokens[cursor.val].text)
  }
  expr
}

///|
fn truth() -> Expr {
  Constant(Logic(Y))
}

///|
fn conditional(
  tokens : Array[Token],
  start : Int32,
) -> (Array[Token], Expr) raise ConfigError {
  let left : Array[Token] = []
  let right : Array[Token] = []
  let mut found = false
  for i in start..<tokens.length() {
    let t = tokens[i]
    if !t.quoted && t.text == "if" && !found {
      found = true
    } else if found {
      right.push(t)
    } else {
      left.push(t)
    }
  }
  (left, if found { parse_expression_tokens(right) } else { truth() })
}

///|
/// Parse a value/condition pair as used by default and reverse dependencies.
pub fn parse_conditional(text : String) -> (Expr, Expr) raise ConfigError {
  let (value, cond) = conditional(tokenize(text), 0)
  (parse_expression_tokens(value), cond)
}
