///|
test "external consumer can build resolve inspect and export without internals" {
  let schema = @moonkconfig.Schema::new()
  schema.add("FEATURE", @moonkconfig.Boolean, prompt="Feature")
  schema.default_value("FEATURE", @moonkconfig.parse_expression("y"))
  let result = schema.resolve(@moonkconfig.Fragment::new())
  assert_eq(result.value("FEATURE"), @moonkconfig.Logic(@moonkconfig.Y))
  assert_eq(schema.inspect(result)[0].prompt, Some("Feature"))
  assert_true(schema.export_config(result).contains("CONFIG_FEATURE=y"))
}
