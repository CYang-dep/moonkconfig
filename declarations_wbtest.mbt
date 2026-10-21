///|
test "cross-file declarations merge local dependencies and ordered defaults" {
  let sources = Map([
    (
      "Kconfig", "config LEFT\n bool \"Left\"\nconfig RIGHT\n bool \"Right\"\nsource \"a/Kconfig\"\nsource \"b/Kconfig\"\n",
    ),
    (
      "a/Kconfig", "if LEFT\nconfig SHARED\n int \"First\"\n default 11\nendif\n",
    ),
    (
      "b/Kconfig", "if RIGHT\nconfig SHARED\n int \"Second\"\n default 22\nendif\n",
    ),
  ])
  let schema = parse_sources("Kconfig", sources)
  assert_eq(schema.names(), ["LEFT", "RIGHT", "SHARED"])
  let right = schema.resolve(schema.parse_config("CONFIG_RIGHT=y\n"))
  assert_eq(right.value("SHARED"), Number(22L))
  assert_eq(right.visibility("SHARED"), Y)
  let both = schema.resolve(
    schema.parse_config("CONFIG_LEFT=y\nCONFIG_RIGHT=y\n"),
  )
  assert_eq(both.value("SHARED"), Number(11L))
  let requested = schema.resolve(
    schema.parse_config("CONFIG_RIGHT=y\nCONFIG_SHARED=37\n"),
  )
  assert_eq(requested.value("SHARED"), Number(37L))
}
