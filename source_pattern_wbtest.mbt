///|
test "sources normalize parent components and visit glob matches in order" {
  let sources = Map([
    ("Kconfig", "source \"parts/Kconfig.*\"\n"),
    ("parts/Kconfig.b", "config X\n int\n default 22\n"),
    (
      "parts/Kconfig.a", "rsource \"../shared/Kconfig\"\nconfig X\n int\n default 11\n",
    ),
    ("shared/Kconfig", "config SHARED\n bool\n default y\n"),
  ])
  let schema = parse_sources("Kconfig", sources)
  assert_eq(schema.resolve(Fragment::new()).value("X"), Number(11L))
  assert_eq(schema.source_locations("X"), [
    "parts/Kconfig.a:2", "parts/Kconfig.b:1",
  ])
  assert_true(source_pattern("parts/Kconfig.?", "parts/Kconfig.a"))
  assert_true(!source_pattern("parts/*", "parts/deep/Kconfig"))
  assert_true(!source_pattern("parts/*", "parts/.hidden"))
  let escaped = try {
    ignore(safe_source_path("../outside"))
    false
  } catch {
    _ => true
  }
  assert_true(escaped)
}
