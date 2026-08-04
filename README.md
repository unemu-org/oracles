# oracles — a reproducible clean-source stash for clean-room reverse engineering

Projects that reimplement undocumented hardware live or die on where their facts come from. A
mechanism derived from a vendor ISA manual, a driver's own source, or a capture from the real
device is defensible; one copied out of somebody else's reimplementation is not — legally, and
also practically, because a copied mistake is invisible until it costs you a week.

So the rule these projects work under is: **every hardware fact must be derived from, and cite,
a clean primary source** — and the citation has to be checkable by someone who was not there.
That is all this repository is.

## The two halves of a checkable citation

A citation is only worth something if the source is **still there** and is **provably the same
source**. A pin alone rots: refs get deleted, projects move hosts, Khronos reorganises. A
vendored copy alone is *our* copy, and you would have to take our word that it matches
upstream. So this repository does both:

| | |
|---|---|
| `fetch-oracles.sh` | Downloads every source to a **pinned** ref, refreshes the vendored copies, writes `SHA256SUMS` |
| **vendored sources** | Everything that may legally be redistributed is **committed here** — durable, offline, no fetch needed |
| `MANIFEST.md` | Per source: version/commit, sha256, licence, and **which fact it witnesses** |
| `NOTICE.md` | Per vendored source: licence, upstream URL, pinned ref (generated — `verify` fails if stale) |

```sh
./fetch-oracles.sh fetch              # download to the pinned refs; refresh the vendored copies
./fetch-oracles.sh verify             # OFFLINE: committed copies vs recorded sha256 — the gate
./fetch-oracles.sh verify --upstream  # re-download at the pins and DIFF against the copies
```

`verify` needs **no network at all** and is what CI and anyone else runs. `verify --upstream`
is the part that means nobody has to take our word, and it names its two failure modes
separately, because they mean opposite things:

* **LOCAL DRIFT** (exit 1) — a committed copy no longer matches its recorded sha256. *This
  repository* changed: an edit, a bad merge, tampering. Fix it here.
* **UPSTREAM MOVED** (exit 3) — the copies match their sums, but upstream at the pinned ref no
  longer does. *The source* changed under a pin that was supposed to be immutable. That is
  itself a finding — a source that no longer says what a citation claims is exactly what a
  provenance ledger exists to detect. Re-read the citations resting on it before moving a pin.

(Exit 2 is usage; exit 4 means an upstream was unreachable, so the check is incomplete.)

## What is vendored and what is not

Vendored: the Vulkan specification chapters and `vk.xml` (CC-BY-4.0 / Apache-2.0 OR MIT), Mesa
`src/amd` + `radeonsi` (MIT), the AMD `radeon`/`amdgpu` kernel headers (MIT), FreeBSD 9.0
sources (BSD). Unmodified, with their licence texts and copyright headers.

**Not** vendored, and fetched to a gitignored working copy instead: the **AMD ISA PDFs**
(© AMD, no redistribution licence — these must never be committed), the **SPIR-V core
specification** (the Khronos grant covers use and reproduction, not clearly redistribution),
and the **OpenOrbis toolchain** (GPL-3, so it legally could be — but it is 169 MB for a handful
of headers, and the provenance quarantine below rewrites one of its files, which would make a
vendored copy a *modified* redistribution). Their hashes/commits are committed, so those
citations stay checkable too: fetch the source yourself and compare.

`NOTICE.md` carries the full table with licence, URL and pinned ref for every entry.

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
cd oracles && ./fetch-oracles.sh verify   # the vendored sources are already there
cd oracles && ./fetch-oracles.sh fetch    # adds the fetch-only ones (AMD PDFs, SPIR-V, OpenOrbis)
```

Cite by **file and section**, not by "the stash" — `oracles/vulkan/drawing.adoc`, *Triangle
Strips* is a citation; "Vulkan says so" is not.

## Licence

The files written for this repository — `fetch-oracles.sh`, `MANIFEST.md`, `README.md`,
`NOTICE.md`, `.gitignore` — are **MIT**, © 2026 Mikołaj Mikołajczyk (`LICENSE`).

**That licence does not extend to the vendored sources.** Each one keeps its own licence, with
its headers intact; `NOTICE.md` records which is which. Take a file out of here and you comply
with *its* licence, not with `LICENSE`.
