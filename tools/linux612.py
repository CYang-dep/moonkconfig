"""Compare MoonKconfig with the pinned native Linux v6.12 conf; never skips failures.

Linux: --source /path/to/linux-v6.12 --conf /path/to/conf --target js
Windows: add --wsl Ubuntu; source/conf must be visible to that WSL distribution.
Only original fixtures and the upstream test inputs are read. No oracle package
is linked into the MoonBit library. Temporary test files are always removed.
"""
import argparse, hashlib, json, os, pathlib, re, subprocess, sys, tempfile, uuid
from build_linux612 import verify
from cases import cases as portable_cases
from linux612_cases import cases as profile_cases
ROOT = pathlib.Path(__file__).resolve().parents[1]

def quote(s):
    if len(s) > 2000:
        return "(" + " +\n".join(json.dumps(s[i:i+2000], ensure_ascii=False) for i in range(0, len(s), 2000)) + ")"
    return json.dumps(s, ensure_ascii=False)

def wsl_path(path):
    text = str(path.resolve()).replace("\\", "/")
    if len(text) > 2 and text[1] == ":":
        return "/mnt/" + text[0].lower() + text[2:]
    return text

def collect(source):
    result = []
    for label, text, fragment in portable_cases():
        files = text if isinstance(text, dict) else {"Kconfig": text}
        result.append({"label": "original " + label, "files": {n: t.replace("option modules", "modules") for n, t in files.items()}, "fragment": fragment})
    result.extend(profile_cases())
    tests = source / "scripts/kconfig/tests"
    for entry in sorted(tests.rglob("Kconfig")):
        folder = entry.parent
        files = {p.relative_to(folder).as_posix(): p.read_text(encoding="utf-8") for p in folder.rglob("*")
                 if p.is_file() and not p.name.startswith(("expected", "__", "oldask", "all")) and p.suffix not in (".py", ".pyc")}
        fragments = [""] + [p.read_text(encoding="utf-8") for p in sorted(folder.iterdir()) if p.name in ("config", "base_config")]
        for n, fragment in enumerate(fragments):
            result.append({"label": "upstream " + folder.relative_to(tests).as_posix() + "/" + str(n), "files": files, "fragment": fragment})
    pins = json.loads((ROOT / "tools/linux612-pins.json").read_text(encoding="utf-8"))
    for name in pins["integration"]:
        text = (source / name).read_text(encoding="utf-8")
        declared = set(re.findall(r"^\s*(?:config|menuconfig)\s+([A-Za-z0-9_]+)", text, re.M))
        references = set()
        for line in text.splitlines():
            if re.match(r"\s*(depends|select|imply|if|default|def_bool|def_tristate)\b", line):
                unquoted = re.sub(r'"(?:[^"\\]|\\.)*"', "", line)
                references.update(re.findall(r"\b[A-Z][A-Z0-9_]*\b", unquoted))
        for external in ("n", "y"):
            host = 'config MODULES\n bool\n modules\n default y\n'
            for symbol in sorted(references - declared - {"MODULES"}):
                host += 'config ' + symbol + '\n bool\n default ' + external + '\n'
            for requests in ("", "y"):
                fragment = "" if not requests else "".join("CONFIG_" + n + "=y\n" for n in sorted(declared))
                result.append({"label": "Linux component " + name + " external=" + external + " requests=" + (requests or "defaults"),
                               "files": {"Kconfig": host + 'source "component"\n', "component": text}, "fragment": fragment})
    return result

def native(data, conf, directory):
    answers = []
    for index, case in enumerate(data):
        folder = directory / str(index)
        folder.mkdir(parents=True, exist_ok=True)
        for name, text in case["files"].items():
            path = (folder / name).resolve()
            if folder.resolve() not in path.parents:
                raise RuntimeError("Fixture path escapes its isolated directory")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode("utf-8"))
        (folder / ".config").write_bytes(case["fragment"].encode("utf-8"))
        env = {k: v for k, v in os.environ.items() if not k.startswith("KCONFIG_")}
        env.update(srctree=str(folder), KCONFIG_CONFIG=".config", KCONFIG_DEFCONFIG_LIST="", LC_ALL="C")
        p = subprocess.run([str(conf), "--olddefconfig", "Kconfig"], cwd=str(folder), env=env, input=b"", stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        config = (folder / ".config").read_text(encoding="utf-8") if p.returncode == 0 else ""
        values = {}
        for line in config.splitlines():
            if line.startswith("CONFIG_"):
                key, value = line[7:].split("=", 1)
                if value.startswith('"'):
                    value = value[1:-1].replace('\\"', '"').replace("\\\\", "\\")
                values[key] = value
            elif line.startswith("# CONFIG_") and line.endswith(" is not set"):
                values[line[9:-11]] = "n"
        answers.append({"returncode": p.returncode, "stdout": p.stdout.decode("utf-8"), "stderr": p.stderr.decode("utf-8"), "values": values, "config": config})
    return answers

def generated_test(index, case, answer):
    lines = ["///|", "test " + quote("Linux v6.12 " + str(index) + " " + case["label"]) + " {",
             "let files = Map([" + ",".join("(" + quote(n) + "," + quote(t) + ")" for n, t in case["files"].items()) + "])"]
    commands = {"echo hello world 3": "hello world 3\n", "printf 'hello\\nworld\\n\\n4\\n\\n\\n'": "hello\nworld\n\n4\n\n\n"}
    arms = ";".join(quote(k) + " => " + quote(v) for k, v in commands.items())
    lines.append("let preprocessor = Preprocessor::new(shell=fn(command) raise ConfigError { match command { " + arms + '; _ => raise Invalid("unmapped test command " + command) } })')
    if answer["returncode"]:
        lines.append('assert_true(try { ignore(parse_linux612("Kconfig", files, preprocessor=preprocessor).resolve(Fragment::new())); false } catch { _ => true })')
    else:
        lines.extend(['let schema = parse_linux612("Kconfig", files, preprocessor=preprocessor)',
                      'let (fragment, _) = schema.read_linux_config(' + quote(case["fragment"]) + ')', 'let result = schema.resolve(fragment)', 'ignore(result)'])
        for name, value in answer["values"].items():
            lines.append("assert_eq(result.value(" + quote(name) + ").text(), " + quote(value) + ")")
        expected = sorted(l for l in answer["config"].splitlines() if l.startswith("CONFIG_") or (l.startswith("# CONFIG_") and l.endswith(" is not set")))
        lines.extend(['let emitted = schema.export_linux_config(result).split("\\n").filter(fn(line) { !line.is_empty() }).map(fn(line) { line.to_owned() }).to_array()',
                      'emitted.sort_by(fn(a,b) { a.lexical_compare(b) })', 'assert_eq(emitted, [' + ','.join(quote(l) for l in expected) + '])'])
    if not answer["returncode"]:
        lines.insert(4, "try {")
        lines.append("} catch { Invalid(msg) => fail(msg); other => raise other }")
    lines.append("}")
    return "\n".join(lines)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=pathlib.Path)
    p.add_argument("--conf", type=pathlib.Path, required=True)
    p.add_argument("--target", choices=("wasm-gc", "wasm", "js", "native"), default="js")
    p.add_argument("--moon", default="moon")
    p.add_argument("--report", type=pathlib.Path)
    p.add_argument("--wsl")
    p.add_argument("--oracle-cache", type=pathlib.Path, help="Optional native answers cache keyed by all fixture bytes and oracle binary bytes")
    p.add_argument("--native-worker", type=pathlib.Path, help=argparse.SUPPRESS)
    a = p.parse_args()
    if a.native_worker:
        data = json.loads(a.native_worker.read_text(encoding="utf-8"))
        answers = native(data, a.conf.resolve(), a.native_worker.parent / "native")
        a.native_worker.with_suffix(".answers.json").write_text(json.dumps(answers), encoding="utf-8")
        return 0
    if not a.source:
        p.error("--source is required")
    source = a.source.resolve()
    commit = verify(source)
    data = collect(source)
    fixture_hash = hashlib.sha256(json.dumps(data, sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()
    with tempfile.TemporaryDirectory(prefix="moonkconfig-v612-") as temporary:
        directory = pathlib.Path(temporary)
        cache = None
        if a.oracle_cache:
            a.oracle_cache.mkdir(parents=True, exist_ok=True)
            key = hashlib.sha256((fixture_hash + hashlib.sha256(a.conf.read_bytes()).hexdigest()).encode()).hexdigest()
            cache = a.oracle_cache / (key + ".json")
        if cache and cache.exists():
            answers = json.loads(cache.read_text(encoding="utf-8"))
        elif a.wsl:
            manifest = directory / "inputs.json"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            subprocess.run(["wsl", "-d", a.wsl, "--", "python3", wsl_path(pathlib.Path(__file__)), "--conf", wsl_path(a.conf), "--native-worker", wsl_path(manifest)], check=True)
            answers = json.loads(manifest.with_suffix(".answers.json").read_text(encoding="utf-8"))
        else:
            answers = native(data, a.conf.resolve(), directory)
        if cache and not cache.exists():
            cache.write_text(json.dumps(answers), encoding="utf-8")
        if len(answers) != len(data) or any(r["returncode"] not in (0, 1) for r in answers):
            raise RuntimeError("Native oracle failed to classify inputs normally")
        body = "\n".join(generated_test(i, c, r) for i, (c, r) in enumerate(zip(data, answers)))
        generated = ROOT / ("linux612_" + uuid.uuid4().hex + "_wbtest.mbt")
        try:
            generated.write_bytes((body + "\n").encode("utf-8"))
            command = [a.moon, "test", str(generated), "--deny-warn", "--target", a.target]
            completed = subprocess.run(command, cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log = completed.stdout.decode("utf-8", errors="replace")
            print(log)
        finally:
            generated.unlink()
    report = {"linux_commit": commit, "target": a.target, "fixture_sha256": fixture_hash, "cases": len(data),
              "accepted": sum(r["returncode"] == 0 for r in answers), "rejected": sum(r["returncode"] != 0 for r in answers),
              "moon_returncode": completed.returncode, "passed": completed.returncode == 0,
              "mapping": [{"index": i, "label": c["label"], "native_returncode": r["returncode"], "stderr": r["stderr"]} for i, (c, r) in enumerate(zip(data, answers))]}
    if a.report:
        a.report.parent.mkdir(parents=True, exist_ok=True)
        a.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Linux v6.12 native cases:", len(data), "accepted:", report["accepted"], "rejected:", report["rejected"], "target:", a.target)
    return completed.returncode

if __name__ == "__main__":
    sys.exit(main())
