///|
test "macros share state across sources with deferred and immediate flavor" {
  let files = Map([
    (
      "Kconfig", "BASE = old\nDEFER = $(BASE)\nNOW := $(BASE)\nF = $(1)-$(2)\nsource \"sub/Kconfig\"\nconfig RESULT\n string\n default \"$(DEFER):$(NOW):$(F,x,y)\"\n",
    ),
    ("sub/Kconfig", "BASE = new\nBASE += tail\nNOW += $(BASE)\n"),
  ])
  let schema = parse_sources("Kconfig", files)
  assert_eq(
    schema.resolve(Fragment::new()).value("RESULT"),
    Text("new tail:old new tail:x-y"),
  )
}

///|
test "macro host environment shell and diagnostics are explicit" {
  let messages = []
  let calls = []
  let env = Map([("ARCH", "arm")])
  let pp = Preprocessor::new(
    environment=env,
    shell=fn(command) {
      calls.push(command)
      "y\n\n"
    },
    message=fn(level, text) { messages.push(level + ":" + text) },
  )
  env["ARCH"] = "changed"
  let s = parse_kconfig(
    "$(info,building $(ARCH))\n$(warning-if,y,check)\nconfig HAS\n def_bool $(shell,probe $(ARCH))\nconfig WHERE\n string\n default \"$(filename):$(lineno)\"\n",
    preprocessor=pp,
  )
  let result = s.resolve(Fragment::new())
  assert_eq(result.value("HAS"), Logic(Y))
  assert_eq(result.value("WHERE"), Text("Kconfig:7"))
  assert_eq(calls, ["probe arm"])
  assert_eq(messages, ["info:building arm", "warning:Kconfig:2: check"])
}

///|
test "macro boundaries arity recursion and help" {
  for
    text in [
      "A = $(B)\nB = $(A)\nconfig X\n string\n default \"$(A)\"", "$(error-if,y,stop)",
      "$(shell,a,b)", "$(filename,argument)", "A := $(missing\n",
    ] {
    let rejected = try {
      ignore(parse_kconfig(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let s = parse_kconfig(
    "comma := ,\nconfig X\n string\n default \"$(MISSING)$(comma)\"\n help\n   literal $(error-if,y,do not execute)\n",
  )
  assert_eq(s.resolve(Fragment::new()).value("X"), Text(","))
  assert_eq(s.help("X"), "literal $(error-if,y,do not execute)")
}
