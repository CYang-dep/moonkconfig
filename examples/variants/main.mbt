///|
fn main {
  try {
    let schema = @config.parse_kconfig(
      "config PRO\n bool \"Pro model\"\nconfig LOGGING\n bool \"Logging\"\n default y if PRO\nconfig BRAND\n string \"Brand\"\n default \"Basic\"",
    )
    let common = schema.parse_config(
      "# CONFIG_PRO is not set\nCONFIG_BRAND=\"Basic\"",
    )
    let premium = schema.parse_config("CONFIG_PRO=y\nCONFIG_BRAND=\"Premium\"")
    let baseline = schema.resolve(common)
    let selected = schema.resolve(@config.merge_fragments([common, premium]))
    assert_eq(@config.overlay_conflicts([common, premium]).length(), 2)
    let changes = schema.changes(baseline, selected)
    assert_eq(changes.length(), 3)
    for change in changes {
      println(
        change.name + ": " + change.before.text() + " -> " + change.after.text(),
      )
    }
    let fragment = schema.minimal_fragment(selected)
    println(schema.export_fragment(fragment))
    assert_eq(
      schema.resolve(fragment).value("LOGGING"),
      @config.Logic(@config.Y),
    )
  } catch {
    _ => abort("variant workflow failed")
  }
}
