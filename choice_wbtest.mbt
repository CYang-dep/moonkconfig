///|
test "boolean choices enforce exclusivity and ordered default selection" {
  let s = parse_kconfig(
    "choice BACKEND\n bool \"Backend\"\n default B\nconfig A\n bool \"A\"\nconfig B\n bool \"B\"\nendchoice",
  )
  let defaults = s.resolve(Fragment::new())
  assert_eq(defaults.value("A"), Logic(N))
  assert_eq(defaults.value("B"), Logic(Y))
  let requested = s.resolve(s.parse_config("CONFIG_B=y\nCONFIG_A=y"))
  assert_eq(requested.value("A"), Logic(Y))
  assert_eq(requested.value("B"), Logic(N))
  assert_eq(s.choice_members("BACKEND"), ["A", "B"])
}

///|
test "optional choice stays disabled until a visible member is requested" {
  let s = parse_kconfig(
    "choice\n bool \"Optional\"\n optional\nconfig A\n bool \"A\"\nconfig B\n bool \"B\"\n depends on n\nendchoice",
  )
  assert_eq(s.resolve(Fragment::new()).value("A"), Logic(N))
  assert_eq(s.resolve(s.parse_config("CONFIG_A=y")).value("A"), Logic(Y))
  assert_eq(s.resolve(s.parse_config("CONFIG_B=y")).value("B"), Logic(N))
  let failed = try {
    ignore(parse_kconfig("choice\n tristate \"Unsupported\"\nendchoice"))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
