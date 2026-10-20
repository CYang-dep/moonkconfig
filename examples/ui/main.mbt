///|
fn main {
  try {
    let schema = @config.parse_kconfig(
      "config NETWORK\n bool \"Networking\"\n default y\nconfig TLS\n bool \"TLS\"\n depends on NETWORK\n help\n   Enable encrypted transport.\nchoice STORAGE\n bool \"Storage backend\"\n default FLASH\nconfig RAM\n bool \"RAM\"\nconfig FLASH\n bool \"Flash\"\nendchoice",
    )
    let requests = schema.parse_config("CONFIG_TLS=y\nCONFIG_RAM=y")
    let result = schema.resolve(requests)
    for row in schema.inspect(result) {
      println(
        row.name +
        "=" +
        row.value.text() +
        " visibility=" +
        row.visibility.text() +
        " reason=" +
        row.reason,
      )
    }
    assert_eq(schema.request_options(requests, "TLS"), [
      @config.Logic(@config.N),
      @config.Logic(@config.Y),
    ])
    assert_eq(result.value("FLASH"), @config.Logic(@config.N))
    assert_eq(schema.help("TLS"), "Enable encrypted transport.")
  } catch {
    _ => abort("UI workflow failed")
  }
}
