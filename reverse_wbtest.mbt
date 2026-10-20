///|
test "select overrides unmet dependencies while imply respects user veto" {
  let s = parse_kconfig(
    "config SOURCE\n bool \"Source\"\n default y\n select STRONG\n imply WEAK\nconfig STRONG\n bool\n depends on n\nconfig WEAK\n bool \"Weak\"\nconfig BLOCKED\n bool\n depends on n\nconfig OTHER\n bool\n default y\n imply BLOCKED",
  )
  let result = s.resolve(s.parse_config("# CONFIG_WEAK is not set"))
  assert_eq(result.value("STRONG"), Logic(Y))
  assert_eq(result.reason("STRONG"), "select")
  assert_eq(result.value("WEAK"), Logic(N))
  assert_eq(result.value("BLOCKED"), Logic(N))
  assert_true(
    result.diagnostics().contains("select bypasses dependencies: STRONG"),
  )
  assert_eq(s.resolve(Fragment::new()).value("WEAK"), Logic(Y))
}

///|
test "conditional reverse dependency strengths follow the tristate lattice" {
  let s = parse_kconfig(
    "config MODULES\n bool\n option modules\n default y\nconfig S\n tristate\n default m\n select T if y\nconfig T\n tristate",
  )
  assert_eq(s.resolve(Fragment::new()).value("T"), Logic(M))
}
