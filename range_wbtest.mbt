///|
test "numeric range rejects user outliers and clamps defaults not user values" {
  let s = parse_kconfig(
    "config LOW\n int\n default 5\nconfig COUNT\n int \"Count\"\n range LOW 10\n default 20\nconfig HEX\n hex \"Hex\"\n range 0x10 0xff\n default 0\nconfig EMPTY\n int",
  )
  let out = s.resolve(s.parse_config("CONFIG_COUNT=2\nCONFIG_HEX=0x80"))
  assert_eq(out.value("COUNT"), Number(10L))
  assert_eq(out.value("HEX"), Number(128L))
  assert_eq(out.value("EMPTY"), Unset)
  assert_eq(s.resolve(Fragment::new()).value("HEX"), Number(16L))
  assert_eq(
    s.resolve(s.parse_config("CONFIG_COUNT=7")).value("COUNT"),
    Number(7L),
  )
}

///|
test "conditional first range and inverted bounds are explicit" {
  let s = parse_kconfig(
    "config X\n int\n range 1 4 if n\n range 10 20\n default 0",
  )
  assert_eq(s.resolve(Fragment::new()).value("X"), Number(10L))
  let failed = try {
    ignore(parse_kconfig("config X\n int\n range 9 1").resolve(Fragment::new()))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
