///|
fn main {
  try {
    let files = Map([
      (
        "Kconfig", "config LEFT\n bool \"Left\"\nconfig RIGHT\n bool \"Right\"\nsource \"left/Kconfig\"\nsource \"right/Kconfig\"\n",
      ),
      (
        "left/Kconfig", "if LEFT\nconfig SHARED\n int \"Shared left\"\n default 11\nendif\n",
      ),
      (
        "right/Kconfig", "if RIGHT\nconfig SHARED\n int \"Shared right\"\n default 22\nendif\n",
      ),
    ])
    let schema = @config.parse_linux612("Kconfig", files)
    for
      (request, expected) in [
        ("CONFIG_LEFT=n\nCONFIG_RIGHT=n\n", "0"),
        ("CONFIG_LEFT=y\nCONFIG_RIGHT=n\n", "11"),
        ("CONFIG_LEFT=n\nCONFIG_RIGHT=y\n", "22"),
        ("CONFIG_LEFT=y\nCONFIG_RIGHT=y\n", "11"),
        ("CONFIG_LEFT=n\nCONFIG_RIGHT=y\nCONFIG_SHARED=37\n", "37"),
      ] {
      let (fragment, diagnostics) = schema.read_linux_config(request)
      assert_eq(diagnostics.length(), 0)
      let result = schema.resolve(fragment)
      assert_eq(result.value("SHARED").text(), expected)
      println("SHARED=" + expected)
      println(schema.export_linux_config(result))
    }
    assert_eq(schema.source_locations("SHARED"), [
      "left/Kconfig:2", "right/Kconfig:2",
    ])
  } catch {
    _ => abort("Linux v6.12 configuration failed")
  }
}
