///|
test "config export roundtrips and module C headers use standard names" {
  let s = parse_kconfig(
    "config MODULES\n bool\n option modules\n default y\nconfig DRIVER\n tristate \"Driver\"\n default m\nconfig TEXT\n string \"Text\"\n default \"quote \\\" and slash \\\\\"\nconfig HEX\n hex\n default 0x7f\nconfig EMPTY\n int",
  )
  let result = s.resolve(Fragment::new())
  let text = s.export_config(result)
  let again = s.resolve(s.parse_config(text))
  for name in s.names() {
    assert_eq(result.value(name), again.value(name))
  }
  let header = s.export_header(result)
  assert_true(header.contains("#define CONFIG_DRIVER_MODULE 1\n"))
  assert_true(header.contains("#define CONFIG_HEX 0x7f\n"))
  assert_true(!header.contains("CONFIG_EMPTY"))
  assert_eq(s.export_config(result), text)
}

///|
test "snapshot schema mismatch is reported instead of partial output" {
  let a = parse_kconfig("config A\n bool")
  let b = parse_kconfig("config B\n bool")
  let failed = try {
    ignore(b.export_config(a.resolve(Fragment::new())))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(hex_text(9223372036854775807L), "0x7fffffffffffffff")
}
