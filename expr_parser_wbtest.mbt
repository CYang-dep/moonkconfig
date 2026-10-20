///|
test "Kconfig expression precedence includes comparison above negation" {
  let values : Map[String, Value] = { "A": Logic(M), "B": Logic(N) }
  assert_eq(parse_expression("A || B && n").evaluate(values), Logic(M))
  assert_eq(parse_expression("!A = m").evaluate(values), Logic(N))
  assert_eq(parse_expression("!(A = y) && (2 < 10)").evaluate(values), Logic(Y))
  let (value, cond) = parse_conditional("y if A && !B")
  assert_eq(value.evaluate(values), Logic(Y))
  assert_eq(cond.evaluate(values), Logic(M))
}

///|
test "expression parser rejects trailing tokens and incomplete operators" {
  for s in ["A B", "A &&", "()", "(A", "A)", "A == y"] {
    let failed = try {
      ignore(parse_expression(s))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
