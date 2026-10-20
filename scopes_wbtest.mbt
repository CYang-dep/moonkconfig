///|
test "nested inherited dependencies and help are retained" {
  let s = parse_kconfig(
    "menu \"Devices\"\n depends on BUS\n visible if UI\nif ENABLE\nconfig DRIVER\n bool \"Driver\"\n help\n   A driver with # unparsed help.\n   second line\nendif\nendmenu\n",
  )
  assert_eq(s.help("DRIVER"), "A driver with # unparsed help.\nsecond line")
  let values : Map[String, Value] = {
    "BUS": Logic(Y),
    "ENABLE": Logic(N),
    "UI": Logic(Y),
  }
  assert_eq(s.defs[0].depends.evaluate(values), Logic(N))
  assert_eq(s.prompt("DRIVER").1.evaluate(values), Logic(Y))
}

///|
test "scope structural errors are never silently accepted" {
  for
    text in [
      "endif", "menu \"x\"\nendif", "if A\nconfig B\n bool", "help\n text",
    ] {
    let failed = try {
      ignore(parse_kconfig(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
