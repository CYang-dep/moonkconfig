///|
fn main {
  try {
    let files = {
      "Kconfig": "config MODULES\n bool\n option modules\n default y\nsource \"drivers/Kconfig\"\nconfig QUEUE\n int \"Queue depth\"\n range 1 64\n default 8",
      "drivers/Kconfig": "config UART\n tristate \"UART driver\"\n default m\n select SERIAL\nconfig SERIAL\n tristate",
    }
    let schema = @config.parse_sources("Kconfig", files)
    let board = schema.parse_config("CONFIG_UART=y\nCONFIG_QUEUE=16")
    let result = schema.resolve(board)
    assert_eq(result.value("SERIAL"), @config.Logic(@config.Y))
    assert_eq(result.value("QUEUE"), @config.Number(16L))
    println(schema.export_header(result))
  } catch {
    _ => abort("firmware workflow failed")
  }
}
