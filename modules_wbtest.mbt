///|
test "module switch changes tristate effective type and bare m conditions" {
  let s = parse_kconfig(
    "config MODS\n bool \"Modules\"\n option modules\n default y\nconfig DRIVER\n tristate \"Driver\"\n default m\nconfig ONLY_MODULE\n bool\n depends on m\n default y",
  )
  let enabled = s.resolve(Fragment::new())
  assert_eq(enabled.value("DRIVER"), Logic(M))
  assert_eq(enabled.value("ONLY_MODULE"), Logic(Y))
  let disabled = s.resolve(s.parse_config("# CONFIG_MODS is not set"))
  assert_eq(disabled.value("DRIVER"), Logic(Y))
  assert_eq(disabled.value("ONLY_MODULE"), Logic(N))
  assert_eq(parse_expression("m = m").condition(Map([]), false), Y)
}

///|
test "no module switch means boolean effective tristates" {
  let s = parse_kconfig("config D\n tristate \"D\"\n default m")
  assert_eq(s.resolve(Fragment::new()).value("D"), Logic(Y))
}
