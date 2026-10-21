///|
test "macro output is literal data inside a quoted token" {
  let s = parse_kconfig("V = a\"b\nconfig X\n string\n default \"$(V)\"\n")
  assert_eq(s.resolve(Fragment::new()).value("X"), Text("a\"b"))
}

///|
test "macros cannot synthesize directives or spread over tokens" {
  for
    source in [
      "TYPE = bool\nconfig X\n $(TYPE) \"X\"\n", "BOUNDS = 1 3\nconfig X\n int\n range $(BOUNDS)\n",
    ] {
    let rejected = try {
      ignore(parse_kconfig(source))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
