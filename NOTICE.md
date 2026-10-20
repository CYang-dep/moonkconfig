# Provenance and references

MoonKconfig is an original MoonBit implementation, not a source-code port.

- Linux Kconfig language documentation: `torvalds/linux`, commit `f47d223627f80cb7a1eb14c585fe6cb35de5e984`, `Documentation/kbuild/kconfig-language.rst`. Studied as language behavior documentation; no Linux implementation or fixtures copied.
- Kconfiglib: https://github.com/ulfalizer/Kconfiglib , upstream inspected commit `061e71f7d78cb057762d88de088055361863deff`; development differential oracle is the separately installed PyPI release `kconfiglib==14.1.0`, ISC license. Not vendored, not linked at runtime. All differential fixtures in `tools/cases.py` are original synthetic inputs.
- Runtime: official MoonBit core. Local baseline `moon 0.1.20261012`, `moonc v0.10.15+943464bfa`.
- GitHub Actions uses the official stable installer and logs its actual version; C backend runs on Ubuntu.
- Source, tests and documentation were developed with AI assistance. Human-facing authorship is the account-bound project identity, not a claim of manual-only implementation.

The Apache-2.0 license applies to this repository's original code and documents. Merely referring to Linux documentation does not relicense Linux source or claim its code was ported. External tools retain their respective licenses.
