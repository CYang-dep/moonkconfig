///|
test "lexer quotes comments operators and UTF16 offsets" {
  let ts = tokenize("A && (B != \"姹夊瓧\\\"\") # ignored")
  assert_eq(ts.length(), 7)
  assert_eq(ts[5].text, "姹夊瓧\"")
  assert_eq(ts[5].quoted, true)
  assert_eq(quote_string("a\\b\""), "\"a\\\\b\\\"\"")
  assert_true(identifier("SPI_2"))
  assert_eq(identifier("a-b"), true)
}

///|
test "lexer rejects incomplete strings macros and single operators" {
  for s in ["\"oops", "A & B", "A | B", "$(shell bad)"] {
    let failed = try {
      ignore(tokenize(s))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
