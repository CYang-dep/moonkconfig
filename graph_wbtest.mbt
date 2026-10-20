///|
test "iterative graph ordering respects forward and reverse edges" {
  let s = parse_kconfig(
    "config A\n bool\n default y\n select B\nconfig B\n bool\nconfig C\n bool\n depends on B",
  )
  assert_eq(s.dependency_order(), ["A", "B", "C"])
  assert_eq(s.resolve(Fragment::new()).value("B"), Logic(Y))
}

///|
test "positive and negative dependency cycles report witnesses before resolution" {
  for
    input in [
      "config A\n bool\n depends on B\nconfig B\n bool\n depends on A", "config SELF\n bool\n default !SELF",
      "config A\n bool\n select B\nconfig B\n bool\n select A",
    ] {
    let message = try {
      ignore(parse_kconfig(input).resolve(Fragment::new()))
      ""
    } catch {
      Invalid(msg) => msg
    }
    assert_true(message.has_prefix("dependency cycle:"))
    assert_true(message.contains(" -> "))
  }
}
