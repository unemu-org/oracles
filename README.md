# oracles — a reproducible clean-source stash for clean-room reverse engineering

A **reproducer**, not an archive. This repository holds two files that matter:

| File | What it is |
|---|---|
| `fetch-oracles.sh` | Downloads every source to a **pinned** ref, writes `SHA256SUMS`, and re-verifies |
| `MANIFEST.md` | For each source: name, version/commit, sha256, licence, and **which fact it witnesses** |

**No fetched content is ever committed here.** The AMD ISA PDFs are copyright AMD and are kept
local only; the Mesa and OpenOrbis trees are clones pinned by commit; the kernel and FreeBSD
headers are pinned by sha256. `.gitignore` tracks exactly three files and excludes everything
else, so cloning this repository downloads a few tens of kilobytes and cloning *the sources* is
something you do yourself, deliberately, from their own upstreams.

```sh
./fetch-oracles.sh fetch     # download everything to its pinned ref, write SHA256SUMS
./fetch-oracles.sh verify    # sha256 of fixed files + git HEADs vs pinned commits
```

## Why it exists

Projects that reimplement undocumented hardware live or die on where their facts come from. A
mechanism derived from a vendor ISA manual, a driver's own source, or a capture from the real
device is defensible; one copied out of somebody else's reimplementation is not — legally, and
also practically, because a copied mistake is invisible until it costs you a week.

So the rule these projects work under is: **every hardware fact must be derived from, and cite,
a clean primary source** — and the citation has to be checkable by someone who was not there.
That needs the source pinned by version and hash, and it needs the pin to be *reproducible on a
fresh machine*. That is all this repository is.

## What it does not promise

**"It came from the stash" is not by itself proof that a fact is first-hand.** A clean source can
carry a second-hand block: one file in the OpenOrbis tree cited another project as the origin of
its own constants. The reproducer excises that block on every fetch and `verify` re-checks it —
but the general lesson stands, and `MANIFEST.md` documents it under *Second-hand blocks in a
clean source*. Read that section before leaning on a citation.

## Using it from a project

Add it as a submodule so the paths your code and tests cite stay stable and the version is
pinned by commit:

```sh
git submodule add https://github.com/unemu-org/oracles.git oracles
git submodule update --init
cd oracles && ./fetch-oracles.sh fetch
```

Cite by **file and section**, not by "the stash" — `oracles/vulkan/drawing.adoc`, *Triangle
Strips* is a citation; "Vulkan says so" is not.

## Licence

GPL-3.0, inherited from the project this was extracted from (see `COPYING`). That covers the
reproducer and the manifest — the sources it fetches carry their own licences, which
`MANIFEST.md` records per entry.
