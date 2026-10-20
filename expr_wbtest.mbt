///|
test "typed expression evaluation and unique references" {
  let e = Conjunction(SymbolRef("A"), Negation(SymbolRef("B")))
  let v : Map[String, Value] = { "A": Logic(M), "B": Logic(N) }
  assert_eq(e.evaluate(v), Logic(M))
  assert_eq(
    Comparison("<", Constant(Number(2L)), Constant(Number(10L))).evaluate(v),
    Logic(Y),
  )
  assert_eq(e.references(), ["A", "B"])
}

///|
test "signed decimal and hexadecimal boundaries are checked" {
  assert_eq(parse_number("-9223372036854775808"), -9223372036854775807L - 1L)
  assert_eq(parse_number("0x7fffffffffffffff"), 9223372036854775807L)
  for s in ["", "-", "0x", "0xG", "9223372036854775808", "-9223372036854775809"] {
    let failed = try {
      ignore(parse_number(s))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
