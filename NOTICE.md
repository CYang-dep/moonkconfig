# Provenance and references

MoonKconfig is an original MoonBit implementation under Apache-2.0, developed with AI assistance. It is not a source-code translation of Linux or Kconfiglib.

- Fixed language endpoint: Linux v6.12, commit `adc218676eef25575469234709c2d87185ca223a`, including the language and macro documentation and the native `scripts/kconfig/conf` behavior.
- `tools/linux612-pins.json` records Git blob hashes for external development-oracle sources and input fixtures. Tools retrieve/verify and compile these in an external checkout. Linux C implementation and upstream fixtures retain GPL-2.0 and their original notices; they are not vendored into the repository or MoonCakes package, linked into the library, or relicensed by this project. Derived test reports identify their external inputs. Original synthetic vectors in this repository remain project code.
- Earlier documentation study: `torvalds/linux` commit `f47d223627f80cb7a1eb14c585fe6cb35de5e984`.
- Kconfiglib: https://github.com/ulfalizer/Kconfiglib , inspected commit `061e71f7d78cb057762d88de088055361863deff`. Separately installed PyPI `kconfiglib==14.1.0` (ISC) is a development-only oracle, not vendored or linked at runtime. `tools/cases.py` contains original synthetic inputs.
- Runtime dependency: official MoonBit core. Local baseline `moon 0.1.20261016`, `moonc v0.10.16+b1a0e846e`; CI installs official stable and records its actual version.

Tests and reports establish their measured scope. They do not certify every possible language input or claim organizer acceptance. See docs/conformance.md for the fixed target, host responsibilities and reproducible evidence.
