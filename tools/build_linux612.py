"""Build the pinned external Linux v6.12 conf oracle. GPL sources stay external."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess
HERE = pathlib.Path(__file__).resolve().parent

def verify(source):
    pins = json.loads((HERE / "linux612-pins.json").read_text(encoding="utf-8"))
    for name, expected in pins["files"].items():
        data = (source / name).read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if actual != expected:
            raise RuntimeError("Pinned Linux v6.12 source mismatch: " + name)
    return pins["commit"]

def build(source, output):
    verify(source)
    output.mkdir(parents=True, exist_ok=True)
    src = source / "scripts/kconfig"
    for p in src.iterdir():
        if p.suffix in (".c", ".h", ".l", ".y") and p.name not in ("parser.tab.c", "parser.tab.h", "lexer.lex.c"):
            shutil.copyfile(str(p), str(output / p.name))
    commands = [
        ["bison", "-d", "-o", "parser.tab.c", "parser.y"],
        ["flex", "-o", "lexer.lex.c", "lexer.l"],
        [os.environ.get("CC", "cc"), "-O2", "-DYYDEBUG=1", "-I" + str(source / "scripts/include"), "-I.", "-o", "conf",
         "conf.c", "confdata.c", "expr.c", "lexer.lex.c", "menu.c", "parser.tab.c", "preprocess.c", "symbol.c", "util.c"],
    ]
    for command in commands:
        subprocess.run(command, cwd=str(output), check=True)
    return output / "conf"

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", type=pathlib.Path, required=True)
    p.add_argument("--output", type=pathlib.Path, required=True)
    a = p.parse_args()
    print(build(a.source.resolve(), a.output.resolve()))
