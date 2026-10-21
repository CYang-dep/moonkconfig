///|
fn main raise {
  let files = Map([
    (
      "Kconfig", "FIRST = 11\nSECOND := 22\nconfig LEFT\n bool \"Left\"\nconfig RIGHT\n bool \"Right\"\nsource \"a/Kconfig\"\nsource \"b/Kconfig\"\n",
    ),
    (
      "a/Kconfig", "if LEFT\nconfig SHARED\n int \"First declaration\"\n default $(FIRST)\nendif\n",
    ),
    (
      "b/Kconfig", "if RIGHT\nconfig SHARED\n int \"Second declaration\"\n default $(SECOND)\nendif\n",
    ),
  ])
  let schema = @config.parse_sources("Kconfig", files)
  let right = schema.resolve(schema.parse_config("CONFIG_RIGHT=y\n"))
  assert_eq(right.value("SHARED"), @config.Number(22L))
  let both = schema.resolve(
    schema.parse_config("CONFIG_LEFT=y\nCONFIG_RIGHT=y\n"),
  )
  assert_eq(both.value("SHARED"), @config.Number(11L))
  let requested = schema.resolve(
    schema.parse_config("CONFIG_RIGHT=y\nCONFIG_SHARED=37\n"),
  )
  assert_eq(requested.value("SHARED"), @config.Number(37L))
  assert_eq(schema.source_locations("SHARED"), ["a/Kconfig:2", "b/Kconfig:2"])
  println(schema.export_config(right))
}
