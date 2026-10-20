///|
test "parse typed options defaults ranges and reverse dependencies" {
  let s = parse_kconfig(
    "config NET\n bool \"Network\"\n default y\nconfig RATE\n int \"Rate\"\n default 10 if NET\n range 1 100\nconfig DRIVER\n tristate\n depends on NET\n select NET\n",
  )
  assert_eq(s.names(), ["NET", "RATE", "DRIVER"])
  assert_eq(s.kind("RATE"), Integer)
  assert_eq(s.source_location("RATE"), "Kconfig:4")
  assert_eq(s.prompt("NET").0, Some("Network"))
}

///|
test "reject missing types duplicate symbols and unsupported grammar" {
  for
    text in [
      "config A\n", "config A\n bool\nconfig A\n bool", "config A\n bool\n option env=BAD",
      "config A\n string\n select B",
    ] {
    let failed = try {
      ignore(parse_kconfig(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
