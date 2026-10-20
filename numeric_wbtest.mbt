///|
test "hex context uses base sixteen even without a prefix" {
  let s = parse_kconfig(
    "config H\n hex \"H\"\n range 10 ff\n default 20\nconfig T\n string\n default 0x20",
  )
  assert_eq(s.resolve(Fragment::new()).value("H"), Number(32L))
  assert_eq(s.resolve(s.parse_config("CONFIG_H=12")).value("H"), Number(18L))
  assert_eq(s.resolve(Fragment::new()).value("T"), Text("0x20"))
  let failed = try {
    ignore(parse_kconfig("config I\n int \"I\"").parse_config("CONFIG_I=0x10"))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
