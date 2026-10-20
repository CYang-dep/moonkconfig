///|
test "defaults follow dependency chains and hidden requests cannot force values" {
  let s = parse_kconfig(
    "config A\n bool \"A\"\n default y\nconfig B\n bool \"B\"\n depends on A\n default y\nconfig SECRET\n bool\n default n\nconfig S\n string \"Text\"\n default \"hello\"\nconfig I\n int\n default 42",
  )
  let requests = s.parse_config("CONFIG_SECRET=y\nCONFIG_S=\"custom\"")
  let result = s.resolve(requests)
  assert_eq(result.value("B"), Logic(Y))
  assert_eq(result.value("SECRET"), Logic(N))
  assert_eq(result.value("S"), Text("custom"))
  assert_eq(result.value("I"), Number(42L))
  assert_eq(result.visibility("SECRET"), N)
  assert_eq(result.reason("B"), "default")
  assert_eq(result.diagnostics(), ["request constrained: SECRET"])
  let disabled = s.resolve(s.parse_config("# CONFIG_A is not set\nCONFIG_B=y"))
  assert_eq(disabled.value("B"), Logic(N))
}

///|
test "first active default wins and snapshots are detached" {
  let s = parse_kconfig(
    "config A\n bool\n default n if n\n default y\n default n",
  )
  let input = Fragment::new()
  let result = s.resolve(input)
  let copy = result.values()
  copy["A"] = Logic(N)
  assert_eq(result.value("A"), Logic(Y))
  s.default_value("A", Constant(Logic(N)))
  assert_eq(result.value("A"), Logic(Y))
}
