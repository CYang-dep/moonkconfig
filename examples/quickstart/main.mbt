///|
fn main {
  try {
    let schema = @config.parse_kconfig(
      "config ENABLE\n bool \"Enable\"\n default y\nconfig DEPTH\n int \"Depth\"\n range 1 32\n default 8",
    )
    let requests = schema.parse_config("CONFIG_DEPTH=16")
    let result = schema.resolve(requests)
    assert_eq(result.value("ENABLE"), @config.Logic(@config.Y))
    assert_eq(result.value("DEPTH"), @config.Number(16L))
    println(schema.export_config(result))
    println(schema.export_header(result))
  } catch {
    _ => abort("configuration failed")
  }
}
