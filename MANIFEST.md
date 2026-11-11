# clean-oracle stash — MANIFEST

Pinned, checksummed clean sources for the provenance-derivation ledgers that cite them.
A ledger cites entries here by **name + version/commit + sha256 + section**.

Two projects draw on this stash, and their sources are grouped separately:

- **unemups4** (PS4 emulation) — the AMD GPU ISA manuals, the kernel `radeon`/`amdgpu`
  register headers, Mesa, Vulkan, SPIR-V, OpenOrbis, FreeBSD 9.0. The original consumer; its
  sections below are unchanged and the doc-9 ledger references still resolve.
- **x86jit** (x86-64 → host recompiler) — the Intel SDM and AMD64 APM, the x86-64 psABI, the
  Linux x86 syscall tables and process/signal uapi, and the SingleStepTests 80286 corpus with
  its MOO container format. See **x86 sources** below.

The pins are deliberately independent: `KERNEL_REF` (GPU headers) and `KERNEL_X86_REF`
(syscall tables) are separate variables even while they hold the same tag, so bumping one
consumer's ledger never silently moves the other's citations.

Every source here is in one of exactly two states, and each entry below says which:

- **VENDORED** — committed to this repository, unmodified, at the path the citations use.
  Durable: no fetch, no network, no live upstream needed to read what a citation points at.
  Licences and attribution: `NOTICE.md` (generated; `verify` fails if it goes stale).
- **FETCH-ONLY** — may not be redistributed from here (AMD PDFs are © AMD; the Khronos
  SPIR-V spec grants no clear redistribution right) or is impractical to commit (the 169 MB
  OpenOrbis clone, one of whose files the quarantine below rewrites). Pinned by sha256 or
  commit, gitignored, downloaded by `fetch`. The pin is what keeps it checkable.

**Reproduce / check this stash:**

- `./fetch-oracles.sh fetch` — download everything at the pinned refs, refresh the vendored
  copies, rewrite `SHA256SUMS` (vendored) and `SHA256SUMS.fetched` (pins for the rest).
- `./fetch-oracles.sh verify` — **offline**: vendored copies vs recorded sha256, the fetch-only
  pins for whatever is present locally, and the provenance quarantine. Exit 1 = **LOCAL DRIFT**.
- `./fetch-oracles.sh verify --upstream` — re-download at the pinned refs and diff against the
  committed copies. Exit 3 = **UPSTREAM MOVED**: the copies still match their sums, so this
  repository did not drift — the *source* no longer says what it said at the pin. Treat that as
  a finding and re-read the citations that rest on it before moving the pin.

Obtained: 2026-07-23; vendored 2026-08-04. Host: this machine, `oracles/`.

Guard: **only** these sources may back a mechanism in the ledger. Another PS4 emulator's
code, headers, wiki, design docs or URLs are FORBIDDEN as source.

> **A clean source can still contain a second-hand block.** One file in the OpenOrbis tree
> cited an emulator project as the source of its own constants; the reproducer now excises
> it on every fetch and `verify` re-checks it. Read
> [Second-hand blocks in a clean source](#second-hand-blocks-in-a-clean-source-provenance-quarantine)
> before treating "it came from the stash" as proof that a fact is first-hand.

---

## AMD ISA manuals (shader-ISA semantics + T#/V# descriptor layouts) — **FETCH-ONLY**

| File | Title | Pages | sha256 | License | Covers |
|---|---|---|---|---|---|
| `amd/ci-isa.pdf` | AMD Sea Islands Series Instruction Set Architecture (R1100_ISA.book) | 316 | `a62ed1c0c1fb3f3215ed6cf45218c70d4caf059398906f645d6a366a70abde98` | © AMD (cite-only) | **PS4 Liverpool ≈ GCN2/Sea Islands** — shader opcode semantics (#6), image descriptor T# (#5), buffer descriptor V# (#11) |
| `amd/si-isa.pdf` | AMD Southern Islands Series Instruction Set Architecture | — | `f09c4c5327f1e845cc79197f4bfc45fe49fe94709895fe0abd2624055eafc99f` | © AMD (cite-only) | GFX6 baseline — cross-check opcode/descriptor when CI diverges |
| `amd/rdna2-isa.pdf` | "RDNA 2" Instruction Set Architecture: Reference Guide (Nov 2020) | 291 | `22aec03f2706dba2e148ffde1f3a25d5cdd42c71a96f95240aeb48d995d44795` | © AMD (cite-only) | **PS5 Oberon ≈ RDNA2/GFX10.3** — wave32 shader opcode semantics, VOP/SOP/SMEM/VMEM encodings, RDNA image T#/sampler S#/buffer V# descriptor layouts (differ from GCN) |

- Source (GCN): archive.org snapshot of `developer.amd.com/wordpress/media/.../AMD_{Sea,Southern}_Islands_Instruction_Set_Architecture*.pdf` (amd.com direct + docs.amd.com were blocked, http 000/301).
- Source (RDNA2): wayback raw snapshot (`20230214072857id_`) of the retired `developer.amd.com/wp-content/resources/RDNA2_Shader_ISA_November2020.pdf` — `docs.amd.com` serves only an HTML viewer (2.5 KB), the `gpuopen.com` download 404s.
- **CI is the primary** oracle for PS4 (Liverpool); cite SI only when it disambiguates a GFX6-level fact. **RDNA2 is the primary** oracle for PS5 (Oberon) — GCN facts do NOT carry over: wavefront width (64→32/64), VOP3/DPP/SDWA encodings, and the descriptor word layouts all changed. Never derive a PS5 shader fact from the CI/SI PDF.

## AMD register + PM4 headers (Linux kernel — canonical MMIO reg offsets + PM4 PKT3 opcodes) — **VENDORED**

Kernel `drivers/gpu/drm/{radeon,amd/amdgpu}/*.{h,c}` from `torvalds/linux` @ tag **`v6.12`**
(`radeon/cik.c` added 2026-07-28). License: **MIT** — the kernel as a whole is GPL-2.0, but
these particular files carry AMD's own "Permission is hereby granted, free of charge" notice,
which is what allows them to be vendored; the per-file headers are preserved verbatim.

| File | Origin | sha256 | Covers |
|---|---|---|---|
| `amd/kernel-sid.h` | radeon/sid.h (Southern Islands) | `fa2749d08d2028fdb2ff1fa434c167b79e4a0d91cdf0ef7c6d15c6e4d9f18c56` | GFX6 regs + PM4 PACKET3; tiling mode regs (#7) |
| `amd/kernel-cikd.h` | radeon/cikd.h (Sea Islands/CIK) | `e0332925036d1f60e323364842661edee97f5f5c684a6f16d3966c776505b8d2` | **GFX7/Liverpool regs + PM4** — reg banks, PKT3 opcodes (#8, #9) |
| `amd/kernel-cik.c` | radeon/cik.c (Sea Islands/CIK) | `dc36ae5c44ba51fb762ebb1734046665ec3bd763c39ad195f5d2e9afa52da8b4` | **`cik_tiling_mode_table_init()`** — the GB_TILE_MODE / GB_MACROTILE_MODE register CONTENTS per pipe count. The only clean statement of the CIK tile tables anywhere (Mesa reads them from the kernel at runtime, and the guest never programs them) — TASK-250 |
| `amd/kernel-evergreend.h` | radeon/evergreend.h | `a03a2858f249b0415ef804e4e81064e395b7315ecb885fd9683fe5b01214d7c2` | older PM4 PACKET3 cross-ref |
| `amd/kernel-soc15d.h` | amd/amdgpu/soc15d.h | `45426641c204f06f54951174ac02a58c9bd49f7b0a7c822eaf984668ba3b8457` | PKT3/IT_* opcode list (stable across gens) |
| `amd/kernel-nvd.h` | amd/amdgpu/nvd.h | `f65a105dfceff3bc03b3e02ac52ed18586586a5866135170a3239ec77fbe29c8` | newer PKT3/IT_* cross-ref |

Note: kernel radeon headers + Mesa (below) are independent witnesses for the same
upstream AMD facts (PM4/registers). Cross-agreement between them and the CI-ISA PDF is
the proof for #8/#9.

## Mesa `src/amd` + `radeonsi` (second witness: PM4, registers, tiling, descriptors) — **VENDORED**

`src/amd/{common,registers,addrlib,llvm,compiler}` and `src/gallium/drivers/radeonsi` from
`https://gitlab.freedesktop.org/mesa/mesa.git` (git clone works — Anubis blocks the
browser, not the git protocol) @ commit `42f591b906b7e8a966cc339f84d2671f423d48c4`,
2026-07-23. License: **MIT** (SPDX header in each file; the licence text travels with the
copy as `mesa/mesa/licenses/MIT` and `mesa/mesa/docs/license.rst`).

Committed at `mesa/mesa/…`, the same paths the ledger already cites. The upstream clone lives
in gitignored scratch (`.upstream/mesa`) and exists only so `fetch` and `verify --upstream`
have something to diff against. The vendored files are written from the **git objects**, not
from a working tree: Mesa's `.gitattributes` says `*.csv eol=crlf`, so a working-tree copy of
`radeonsi/ci/*.csv` is *not* what upstream stores — and a vendored copy that differs from the
blob would be a modified redistribution. `verify --upstream` compares git blob ids, so this is
checked on every run.

**Which directories are vendored is decided by what the ledger cites.** All of `src/amd` is
25 MB / 800 files; the five subdirectories above are 17 MB / 418 files and cover every Mesa
file cited by unemups4 (`src/amd/llvm` and `src/amd/compiler` are here because the ledger
cites `ac_llvm_build.c`, `ac_nir_to_llvm.c` and `aco_select_nir.cpp` — they were *outside*
the pre-vendoring sparse set, so those three citations pointed at files the stash never had).
If a new citation names a Mesa file outside these paths, add its directory to `MESA_SPARSE` in
`fetch-oracles.sh` and re-run `fetch`.

| File | sha256 | Covers |
|---|---|---|
| `mesa/mesa/src/amd/common/sid.h` | `ab9a023178aa4ee5944e20cc5720fe82a5b4b07b026a89488f38eb713e011968` | PM4 PKT3 + IT_* (106 defs), SI regs (#8, #9) |
| `mesa/mesa/src/amd/common/ac_surface.c` | `062351d2d2e5c6c2251e308be0fd952f94ed2ac9d0847f8ac345034a58bfa3d3` | **tiling / surface math (#7)** — GFX6 through GFX12, incl. **GFX10.3 (RDNA2) tiling + DCC** |
| `mesa/mesa/src/amd/registers/gfx6.json` | `38b492cf4211615934372777c55381ba21e448d3f199ddf1394def62446ce1a1` | machine-readable GFX6 register layouts (#5, #9, #11) |
| `mesa/mesa/src/amd/registers/gfx7.json` | (in tree) | GFX7/Liverpool register layouts |

**The driver that programs those registers** — the register files say what a field IS; radeonsi
says which value means what and *when the hardware consults the field at all*. Same pinned clone:

| File | sha256 | Covers |
|---|---|---|
| `mesa/mesa/src/gallium/drivers/radeonsi/gfx/si_shader.c` | (in tree, git-pinned) | how a VS→PS varying becomes `SPI_PS_INPUT_CNTL`: "OFFSET=0x20 means that DEFAULT_VAL is used" — the ONE condition under which the SPI substitutes a constant (TASK-306) |
| `mesa/mesa/src/gallium/drivers/radeonsi/gfx/si_state_shaders.cpp` | (in tree, git-pinned) | `si_emit_spi_map()` — reads the same escape back (`G_028644_OFFSET(...) != 0x20`) to gate `FLAT_SHADE`/FP16 fields |

**PS5 / RDNA2 (GFX10.3) register + descriptor witnesses** — same pinned Mesa clone (`MESA_COMMIT`), just not previously listed:

| File | sha256 | Covers |
|---|---|---|
| `mesa/mesa/src/amd/registers/gfx103.json` | (in tree, git-pinned) | **machine-readable RDNA2 (GFX10.3 = PS5 Oberon) register layouts** — CB/DB/SPI/PA/VGT/GE banks |
| `mesa/mesa/src/amd/registers/gfx10.json` | (in tree, git-pinned) | GFX10 (RDNA1) register layouts — cross-witness where 10.3 inherits from 10 |
| `mesa/mesa/src/amd/registers/gfx10-rsrc.json` | (in tree, git-pinned) | **RDNA image/buffer/sampler resource (T#/V#/S#) descriptor bit layouts** — machine-readable second witness to the RDNA2-ISA PDF |
| `mesa/mesa/src/amd/registers/gfx11-rsrc.json` | (in tree, git-pinned) | RDNA3 descriptor layouts — forward cross-check only (PS5 is RDNA2) |
| `mesa/mesa/src/amd/registers/pkt3.json` | (in tree, git-pinned) | PM4 PKT3 / IT_* opcode table (gen-stable; RDNA2 command stream) |
| `mesa/mesa/src/amd/common/ac_shadowed_regs.c` | (in tree, git-pinned) | GFX10.3 register shadow list — enumerates the regs the RDNA2 GPU state-shadows |

T#/V#/S# descriptor *bit layouts*: PS4 authoritative source is the **CI-ISA PDF** §Image/Buffer
Resource (Mesa gfx6/7.json + `ac_*` are the second witness). PS5 authoritative source is the
**RDNA2-ISA PDF** §resource descriptors (Mesa `gfx10-rsrc.json` is the machine-readable second
witness). The two generations' layouts differ — do not cross-apply.

## Vulkan spec (normative SPIR-V image-operation + host resource semantics) — **VENDORED**

`chapters/*.adoc`, `appendices/*.adoc` and `xml/vk.xml` from
`https://github.com/KhronosGroup/Vulkan-Docs` @ tag `v1.4.309`. License: **CC-BY-4.0** for the
`.adoc` files (SPDX header in each), **Apache-2.0 OR MIT** for `vk.xml`, © 2015-2025 The
Khronos Group Inc. Reproduced unmodified; `vulkan/LICENSE.adoc` is the repository's own licence
file, vendored with them. Attribution: `NOTICE.md`.

| File | sha256 | Covers |
|---|---|---|
| `vulkan/textures.adoc` | `d6469337f42c5faf4debcb3fa10b4da37ccdf281bb83d41688881c036dff6778` | **Texel Gathering (`[[textures-gather]]`)** — which of the 2x2 texels an `OpImage*Gather` returns in which component (`tau[R]=tau_i0j1`, `[G]=tau_i1j1`, `[B]=tau_i1j0`, `[A]=tau_i0j0`), plus the `i0/i1/j0/j1` linear-filter footprint they index. The **only** clean statement of the gather return order: the CI-ISA describes every gather4 opcode as "gather 4 single component elements (2x2)" and never orders them, and Mesa `src/amd` passes the hardware order through unpermuted without naming it. Witnesses TASK-277's `IMAGE_GATHER4_LZ_O` lowering. |
| `vulkan/samplers.adoc` | `ca9e1186daf185d881d55137866aa3665198b4c34c0eba27049a00de816a4ed8` | **`VkCompareOp`** — the only normative statement of what each enumerant COMPUTES: "Comparison operators compare a _reference_ and a _test_ value", `VK_COMPARE_OP_LESS` "specifies that the comparison evaluates _reference_ < _test_", and so on through `ALWAYS`. `textures.adoc` §"Depth Compare Operation" assigns the ROLES (the SPIR-V `Dref` operand is the reference, the texel depth value is the test) and defines the result as 1.0/0.0, but never defines the operators, so a shadow-lookup oracle cannot compute a result from `textures.adoc` alone. Witnesses TASK-287's `IMAGE_SAMPLE_C_LZ` compare arm; the S# field that SELECTS the enumerant is pinned separately against Mesa's `SQ_TEX_DEPTH_COMPARE`. |
| `vulkan/renderpass.adoc` | `fc42ab2d443f6345dde25d232eb4cc261e9f4b4426dcecb754355bf393b52f8b` | **`VkFramebufferCreateInfo` validity** — `VUID-VkFramebufferCreateInfo-flags-04535` (each attachment view's `subresourceRange.layerCount` must be `>=` the framebuffer's `layers`) and `VUID-VkFramebufferCreateInfo-layers-00890` (`layers <= maxFramebufferLayers`). The normative rule a LAYERED colour target's framebuffer has to satisfy; nothing in the AMD ISA or Mesa states the host-side constraint. Witnesses TASK-279's layered render targets. Also **Render Pass Compatibility** (`[[renderpass-compatibility]]`) — "Two attachment references are compatible if they have matching format and sample count", and "Framebuffers and graphics pipelines are created based on a specific render pass object. They must only be used with that render pass object, or one compatible with it". This is what makes the colour FORMAT of the pass a draw is recorded into, and of the pass its pipeline was built against, the same value — witnesses TASK-290. The same section's DEPTH/STENCIL clause — "Two render passes are compatible if their corresponding color, input, resolve, and depth/stencil attachment references are compatible", with a reference being compatible with `VK_ATTACHMENT_UNUSED` only when it too is unused — is what makes the PRESENCE of a depth attachment part of compatibility: witnesses TASK-294. |
| `vulkan/resources.adoc` | `57f852f7268d40a2890cc7fe6cd955a098132c8e49e965b1c9572d8165446051` | **`VkImageSubresourceRange` semantics** — "`baseArrayLayer` is the first array layer accessible to the view; `layerCount` is the number of array layers (starting from `baseArrayLayer`) accessible to the view", plus `VK_REMAINING_ARRAY_LAYERS`. This is what makes an attachment view over `SLICE_START .. SLICE_START+n` the host expression of a GCN colour target's array sub-range (TASK-279); Mesa `ac_descriptors.c` gives the guest side (`SLICE_START = first_layer`), this gives the host side. |
| `vulkan/interfaces.adoc` | `33b4d0a456fd9c8cab9d1f6a2ebdeed4bc3972c7ae6e50f208f5beae2f7e9a88` | **Built-In Variables, the `Layer` block** — `VUID-Layer-Layer-04272` (usable from the `Vertex` execution model), `-04274` (declared in the `Output` storage class), `-04276` (a **scalar 32-bit integer**, signedness unconstrained — which is why the raw exported bits are stored with no conversion), and the out-of-range clause: a `Layer` outside the framebuffer's layer count leaves the framebuffer values for **all** layers undefined. Witnesses TASK-279's `exp pos1` → `BuiltIn Layer` lowering and the gates in front of it. |
| `vulkan/spirvenv.adoc` | `815e50e95762dc0ef8c733ea5db41c2f642f61e568a53ae4d55a3e6bb7c055a5` | **Vulkan Environment for SPIR-V** — a module passed to `vkCreateShaderModule` must not contain "a capability which corresponds to a Vulkan feature or extension which has not been enabled", and must not use a SPIR-V `OpExtension` unless the corresponding Vulkan extension is enabled. The normative basis for gating a `ShaderViewportIndexLayerEXT` module on what device creation actually took (TASK-279). Also `VUID-…-OpTypeImage-06269` / `-07954` / `-07956`: without the `shaderStorageImageWriteWithoutFormat` feature, an `OpTypeImage` with `Sampled = 2` and an `Image Format` of `Unknown` must be decorated `NonWritable` — i.e. a written storage image must DECLARE its format. Witnesses TASK-299's `image_store` → `OpImageWrite` lowering. |
| `vulkan/features.adoc` | `05690653cbabcc51cbd1b1533d6497f08595499ba819eee5503437198f4978a4` | **`shaderStorageImageExtendedFormats`** — the closed list of "storage image extended formats" (`R16G16_SFLOAT`, `B10G11R11_UFLOAT_PACK32`, `R16_SFLOAT`, `R16G16B16A16_UNORM`, … `R8_UINT`). `VK_FORMAT_R32G32B32A32_SFLOAT` — SPIR-V `Rgba32f`, the format every store T# in LN's CS corpus carries — is NOT on it, which is what makes the declared format on the `OpTypeImage` need no optional capability. Also `shaderStorageImageWriteWithoutFormat`, the feature the declared format avoids depending on (TASK-299 §2c). |
| `vulkan/limits.adoc` | `f56e92630164b9b2e9ee489eb1c18fc85dee0edd25c0d167c9a64f8309b8df01` | **Required Limits** — the guaranteed floors a dispatch's declared resources must fit: `maxPerStageDescriptorStorageImages` **4** (LN's clear kernel stores to exactly four images), `maxComputeSharedMemorySize` **16384** (LN's histogram kernel declares exactly 16 KiB of LDS), `maxComputeWorkGroupInvocations` **128**. Witnesses the `MAX_STORAGE_IMAGES` and LDS-size bounds in TASK-299 §2c/§2e. |
| `vulkan/shaders.adoc` | `0de2fca0ba6ee86366c1e8260f6e8b65a6eb738855a219db5f75d6d3c4eca031` | **Scope → Workgroup** — "A local workgroup is a set of invocations that can synchronize and share data with each other using memory in the `Workgroup` storage class", and "for shaders that have defined workgroups, this set of invocations forms an _invocation group_". It grants sharing and says nothing about lockstep: the normative reason a 64-invocation workgroup gets no free ordering just because GCN would have run it as one wavefront (TASK-299 §2e). |
| `vulkan/devsandqueues.adoc` | `9baca303aa9cc2e638dcba7a3d5328663526510d963d7c5ffa615ce5a8b35382` | **Queue-family capability guarantee** — "If an implementation exposes any queue family that supports graphics operations, at least one queue family of at least one physical device exposed by the implementation must: support both graphics and compute operations." The whole basis for selecting ONE queue family on `GRAPHICS \| COMPUTE` and recording draws and dispatches into one command buffer on it. Note what it does NOT promise: the guarantee is per-implementation, not per-physical-device, so the selection must be free to walk every device (TASK-299 §3b). |
| `vulkan/dispatch.adoc` | `61ab029360dd9622417ebbc26b1ce3cef6b306845e55debde180adf68e7b418b` | **Dispatching Commands** — "A compute pipeline must: be bound to a command buffer before any dispatching commands are recorded in that command buffer", and `VUID-vkCmdDispatch-groupCountX/Y/Z-00386/7/8` (each group count `<= maxComputeWorkGroupCount[i]`). The chapter body only; the render-pass property that generates `VUID-vkCmdDispatch-renderpass` lives in `vk.xml` below (TASK-299 §3b). |
| `vulkan/synchronization.adoc` | `d111c7fbc7277ec396399c632898f06a8f3a2961ab66f84ef6b17532468ec950` | **Pipeline stages + access flags** — `VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT` "specifies the execution of a compute shader"; `VK_ACCESS_SHADER_WRITE_BIT` / `_READ_BIT` "specifies write/read access to a storage buffer, … or **storage image** in any shader pipeline stage". The per-dispatch barrier's `srcStage`/`dstStage` and `srcAccess`/`dstAccess` are written directly from these definitions (TASK-299 §3b). |
| `vulkan/descriptorsets.adoc` | `1d5e6c2b5ca933bbc8ba17fcaa378a1c0752ec0657238175ebf00ce385c4c25f` | **Storage Image descriptor** (`[[descriptorsets-storageimage]]`) — "The image subresources for a storage image must: be in the `VK_IMAGE_LAYOUT_GENERAL` layout in order to access its data in a shader" (and `VUID-VkWriteDescriptorSet-descriptorType-04152` binds the descriptor write to that same list); "Stores to storage images are supported in compute shaders for image views whose format features contain `VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT`" — the queried capability the compute harness skips on rather than assumes. Also the Sampled Image / Combined Image Sampler layout lists, which is why a compute dispatch's READ bindings stay `SHADER_READ_ONLY_OPTIMAL` while its WRITE bindings go to `GENERAL` (TASK-299 §3b). |
| `vulkan/vk.xml` | `1adbeb17c00be04771aac41bbb33850ff83c3503b42dcb2a25a96b4fd79c7e07` | **The registry** — the machine-readable spec source the `.adoc` validity blocks are generated from. Cited for exactly one fact: `<command queues="compute" renderpass="outside" cmdbufferlevel="primary,secondary" tasks="action">` on `vkCmdDispatch`, i.e. the property that generates `VUID-vkCmdDispatch-renderpass` ("must only be called outside of a render pass instance"). That VUID appears in no `.adoc` chapter — it is emitted by the generator from this attribute — so the registry is where it can be read (TASK-299 §3b). |
| `vulkan/memorymodel.adoc` | `523021383bd0e9faca2d4bdd7c747b5e5fdcf14bd4a443d299e0cd3bc1d607ef` | **Memory Model** — `OpControlBarrier` is a *memory barrier* instruction, and: "If A is a release barrier, B is an acquire barrier, and C is a control barrier (where A can equal C, and B can equal C), then A synchronizes-with B if … A is program-ordered before (or equals) C; C is program-ordered before (or equals) B; A and B are in the instance of each other's memory scopes; A and B are in the instance of C's execution scope." One `OpControlBarrier(Workgroup, Workgroup, AcquireRelease \| WorkgroupMemory)` is simultaneously A, B and C, which is exactly what orders one invocation's LDS writes before another's LDS reads. Witnesses TASK-299 §2e's inserted barriers. |
| `vulkan/drawing.adoc` | `3ab5849ed630f301715e8cf8b5e73dfdb99a33577591d67d5210e16b7f8b6f68` | **Triangle Strips (`[[drawing-triangle-strips]]`)** — the only normative statement of how a strip is ASSEMBLED into primitives: `p_i = {v_i, v_{i+(1+i%2)}, v_{i+(2-i%2)}}`, so an ODD primitive is `(i, i+2, i+1)`. Stated unconditionally, ahead of any provoking-vertex discussion, so it is the order the whole pipeline receives — a geometry shader's input included. Its note gives the reason: "The ordering of the vertices in each successive triangle is reversed, so that the winding order is consistent throughout the strip." Pairs with Mesa `si_state_draw.cpp` (`[MESA_PRIM_TRIANGLE_STRIP] = V_008958_DI_PT_TRISTRIP`, no software decomposition — the VGT does it), which is what carries the rule from the API onto this hardware (TASK-362) |
| `vulkan/primsrast.adoc` | `6e967448e6d5becc6a54e9c1fc4473364ad617bcdc7dc4ec855a27c748c58a2e` | **Barycentric vertex-order tables** (`[[primsrast-barycentric-order-table]]` and its last-vertex twin) — the tables the `triStripVertexOrderIndependentOfProvokingVertex` limit points at. They are what bounds the implementation-dependent part to the `VK_PROVOKING_VERTEX_MODE_LAST_VERTEX_EXT` variant ALONE; the first-vertex ordering is fixed. Fetched because TASK-362 had read that limit WITHOUT the chapters it references and concluded no readable source fixes the order (TASK-362) |

Pairing note: this file gives the *component ordering*; Mesa `src/amd` (below) gives the
*GCN-VGPR-to-shader-component* mapping as the identity. Neither alone is enough — the two
together are what pin a GCN gather to `OpImageGather`.

## SPIR-V specification (Khronos registry) — **FETCH-ONLY**

The Vulkan-Docs tree carries the SPIR-V *environment* appendix and the memory model but not
the instruction definitions. Khronos publishes those as one HTML document with no git ref
behind it, so it is pinned by sha256 like the AMD PDFs. Fetched 2026-07-31 from
`https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html`. License: Khronos
specification copyright — it grants "a conditional copyright license to **use and reproduce**
the unmodified Specification", directly after a sentence that separately forbids the document
being "reproduced, republished, distributed, transmitted, displayed, broadcast or otherwise
exploited" without written permission. The grant does not clearly reach redistribution, so
this stays fetch-only and gitignored like the PDFs.

> **The pin is taken over a canonicalised document, and it has to be.** `registry.khronos.org`
> sits behind a CDN that injects a per-request challenge script (`window.__CF$cv$params`, a
> fresh request id + timestamp) into the HTML: two downloads seconds apart differ, so the raw
> sha256 recorded before 2026-08-04 could never have been reproduced by anyone, including us.
> `pin_hash()` in `fetch-oracles.sh` therefore hashes the document with that one injected line
> removed — nothing else is touched, and the line is CDN plumbing, not specification text. The
> hash below is that canonical one; `verify --upstream` now round-trips it cleanly.

| File | sha256 | Covers |
|---|---|---|
| `vulkan/spirv-core.html` | `f3eb5d5191b6b55bd9ccf591d992166842fee1e7952e56f35378e04d3c5125c5` | **`OpAtomicIAdd`** — "Perform the following steps atomically with respect to any other atomic accesses within Memory to the same location: 1) load through Pointer to get an Original Value, 2) get a New Value by integer addition of Original Value and Value, and 3) store the New Value back through Pointer. The instruction's result is the Original Value." That last sentence is what makes it the counterpart of GCN's `DS_ADD_RTN_U32`, whose `_RTN_` form returns the pre-op value; nothing in Vulkan-Docs states it. **`OpControlBarrier`** — "Wait for all invocations in the scope restricted tangle to reach the current point of execution before executing further instructions", and the clause the workgroup oracle is built around: "When Execution is `Workgroup` or larger, behavior is undefined unless all invocations within Execution execute the same dynamic instance of this instruction." Witnesses TASK-299's multi-wave barrier scheduler and its LDS atomic. |

## OpenOrbis SDK (Sony-facing formats) — **FETCH-ONLY**

GPL-3.0, so redistributing it would be *legal*; it is fetch-only for two other reasons. The
clone is ~169 MB for a handful of headers plus the OELF/SELF spec, and the provenance
quarantine below **rewrites** one of its headers — a vendored copy would be a *modified*
redistribution, which is the one thing this stash exists not to do. Pinned by commit instead.
(A ~1 MB subset — `include/orbis/` plus `docs/MD/OELF Specification/` — would be vendorable
under GPL-3 if the durability of those two citations is ever judged to be worth it; the
quarantined header would have to be vendored in its *upstream* form, with the quarantine still
applied at fetch time to the working copy.)

| Path | Commit | License | Covers |
|---|---|---|---|
| `openorbis/OpenOrbis-PS4-Toolchain` | `0a1aaf9dd4a92695538bdeb09fb056d06dd11725` | permissive (per repo) | NID salt (#1), SELF/dynamic tags (#2, #3), .sb / GnmDriver types (#10). Headers under `include/orbis/`, `include/orbis/_types/gnm.h`. Blobless depth-1 clone. **One block is quarantined** — see [Second-hand blocks](#second-hand-blocks-in-a-clean-source-provenance-quarantine). |

## FreeBSD 9.0 (Orbis OS base — syscall/kernel-HLE oracle) — **VENDORED**

The PS4 OS ("Orbis OS") is a fork of **FreeBSD 9.0**. Syscall numbers, errno values,
mmap/fcntl flags, and base ELF/dynamic tags trace to it. Fetched raw from
`freebsd/freebsd-src` @ tag `release/9.0.0`, 2026-07-23. License: **BSD-2-Clause /
BSD-3-Clause** (© The Regents of the University of California and others); per-file notices
preserved, and the project licence text is vendored alongside them as `freebsd9/COPYRIGHT`.

| File | Origin | sha256 | Covers |
|---|---|---|---|
| `freebsd9/sys_kern_syscalls.master` | sys/kern/syscalls.master | `37432dded0a21ec91b0b33f5551cae1eeb4d072098903b5e4637b047d8f88556` | syscall number table (BSD base of sceKernel* syscalls) |
| `freebsd9/sys_sys_errno.h` | sys/sys/errno.h | `c3c1266e5651be85387522621557e455db3015f77073f9fdbb4d9ac650c414bd` | errno values (SCE_KERNEL_ERROR_* base) |
| `freebsd9/sys_sys_elf_common.h` | sys/sys/elf_common.h | `62a00357b288bf2da532b74bb2b9ba73dd39ae6bbcac4442c97f0e5252469499` | ELF/dynamic base tags (DT_*, PT_*, ET_*) |
| `freebsd9/sys_sys_elf64.h` | sys/sys/elf64.h | `bcf3d1904281bc0d88622458795b23b58dfcf69c5d0310aacd0c616c0af99378` | Elf64 header/phdr/dyn structs |
| `freebsd9/sys_sys_mman.h` | sys/sys/mman.h | `5618c19f54fbd9db389ee820b026ab7b30e8002aa1377c7df6ca287cf7c4960a` | mmap PROT_*/MAP_* flags |
| `freebsd9/sys_sys_fcntl.h` | sys/sys/fcntl.h | `eaf84ec2d2ee516e40c423bde93bd1eab06c919801773631e9ce222c75f726ac` | open/fcntl O_* flags |
| `freebsd9/lib_libc_sys_mmap.2` | lib/libc/sys/mmap.2 | `596ca65ba6cdde1d804d5f3c8ce63fcecd8025e92409ffa46a4391cb91bf0a23` | **what a mapping does when the range is already mapped** — the MAP_FIXED replace contract + the ERRORS vocabulary (TASK-344) |
| `freebsd9/sys_vm_vm_mmap.c` | sys/vm/vm_mmap.c | `907159d56b13decd80465139c7ea4660d6d8564d6a9027ad85a309d270b19a07` | the implementation behind that contract — `sys_mmap()` MAP_FIXED validation, `vm_mmap_object()` fixed-vs-search dispatch, `vm_mmap_to_errno()` (TASK-344) |
| `freebsd9/sys_sys_event.h` | sys/sys/event.h | `252da293ad3345c283ed96fc354730fb9577dcaa3c549450e71805d615c5b504` | base kqueue `EVFILT_*` (-1..-11), `EVFILT_SYSCOUNT` 11 — the first-hand replacement for the quarantined block below (TASK-344) |

### What `mman.h` does NOT say, and where it is said

`sys/sys/mman.h` gives the `MAP_*` flag **values** and nothing about behaviour, so a
collision — a `MAP_FIXED` request over a range that is already mapped — is not answerable
from it. TASK-341 hit exactly this on `sceKernelBatchMap` and correctly recorded its
collision handling as a *modelling choice* rather than a derived fact. The two files added
in TASK-344 close it:

- **`lib/libc/sys/mmap.2`** is normative and direct: *"If a `MAP_FIXED` request is
  successful, the mapping established by `mmap` **replaces any previous mappings** for the
  process' pages in the range from `addr` to `addr` + `len`."* An overlap is therefore **not
  an error**. The ERRORS section reserves `ENOMEM` for *"`MAP_FIXED` was specified and the
  `addr` argument was not available"*, and `EINVAL` for a non-page-aligned `addr` or a range
  outside the process' valid address space.
- **`sys/vm/vm_mmap.c`** corroborates in the implementation: `sys_mmap()`'s `MAP_FIXED` arm
  fails only with `EINVAL` (misalignment, range outside `vm_map_min`..`vm_map_max`, wrap);
  `vm_mmap_object()` then routes the fixed case to `vm_map_fixed()` — the *replace*
  primitive — rather than `vm_map_find()` with a search policy; and `vm_mmap_to_errno()` is
  the whole failure vocabulary (`KERN_INVALID_ADDRESS`/`KERN_NO_SPACE` → `ENOMEM`,
  `KERN_PROTECTION_FAILURE` → `EACCES`, else `EINVAL`).

FreeBSD 9.0 has **no `MAP_EXCL`** (verified: absent from the pinned `sys_sys_mman.h`), so
there is no way to ask this `mmap` to *refuse* on collision. Consequence for the emulator:
**succeeding on a collision is derived, not invented**; declining to re-map — which
preserves the bytes already committed there — is a *named divergence*, because FreeBSD would
replace the mapping and an anonymous replacement yields zero-filled pages. See
`crates/kernel/src/process.rs::map_direct_memory_at`.

---

# x86 sources (serve x86jit)

x86jit is an x86-64 → host recompiler. Unlike the PS4 GPU, x86-64 is a *documented*
architecture, so the provenance problem has a different shape: the primary source exists and
is authoritative, and the failure mode is not "nobody wrote it down" but **citing it too
vaguely to check**. Before this section the engine carried 562 internal `§spec` references
against ~55 mentions of "the SDM", only five of which named a volume and a section, and three
URLs in the entire source tree. These entries are what a precise citation points at.

The other half is the differential oracle. x86jit compares against Unicorn (QEMU) and against
the host CPU, and the tree already records ~20 places where **QEMU is wrong and hardware
agrees with the engine** — so an oracle here is a *comparand, not an authority*, and the
manuals below are what settles the disagreement.

## x86 CPU manuals (instruction semantics, flags, exception behaviour) — **FETCH-ONLY**

| File | Title | Pages | sha256 | License | Covers |
|---|---|---|---|---|---|
| `intel/sdm.pdf` | Intel® 64 and IA-32 Architectures Software Developer's Manual, Combined Volumes 1, 2A-2D, 3A-3D, 4 (Order Number 325462-092US, June 2026) | 5363 | `16a9336104750613ae2f2bab6eb7a1b21a7e1ef60ced35e9ab2e0d8c7efcec68` | © Intel (cite-only) | **The primary authority for the whole lifter.** Vol 1 §4.8.4 rounding control; Vol 1 §8.1.7 the x87 tag word; Vol 1 Figure 8-9 the 28-byte `FNSTENV` environment image; Vol 2 the per-instruction pages (`FISUB`/`FIDIV` operand order, `SHUFPS` lane selection, `VEXTRACTF128`); Vol 3 the page-fault error code |
| `intel/amd64-apm.pdf` | AMD64 Architecture Programmer's Manual, Volumes 1-5 (Publication 40332, Revision 4.08, April 2024) | 3347 | `6f044603aded1010e981c04ce5ec9e558719d7072e336a80651c49f8904e4cb7` | © AMD (cite-only) | **Second witness** where the SDM is silent or says "undefined" — and the natural authority for the Jaguar-class (x86-64-v2) target x86jit's main consumer emulates. This is the CPU manual; the GPU ISA manuals in `amd/` are a different processor |
| `intel/i286-prm.pdf` | Intel 80286 and 80287 Programmer's Reference Manual (Order Number 210498-005, 1987) | 513 | `ad487ba99b48cd9f61b14c0fe912a04c7cdb4c7c14a18419aa9faf62d8962460` | © Intel (cite-only) | **Source for 286- and 287-specific behaviour** the current SDM does not describe: MSW and LMSW-only protected-mode entry, the 286 descriptor format and 24-bit bases, 286 exception conditions, and the 80287 coprocessor (projective infinity, FSETPM, error signalling). A 1987 scan with an OCR text layer: check a cited value against the page image. |
| `intel/i386-prm.pdf` | Intel 80386 Programmer's Reference Manual (Order Number 230985-001, 1986) | 523 | `e97605911bc589e5d33ffbc7b7e742dd6ab0dda69e12ad972cdc8d32a1cdc775` | © Intel (cite-only) | **Second witness for 386-specific behaviour** the current SDM no longer describes as a 386 feature set: CR0 and EFLAGS masks, two-level paging permissions and reserved bits, reset state. A 1986 scan with an OCR text layer: check a cited value against the page image, not only the extracted text. |

- Source (SDM): `https://cdrdv2-public.intel.com/922475/325462-092-sdm-vol-1-2abcd-3abcd-4.pdf`.
- Source (80286/80287 PRM): `http://bitsavers.trailing-edge.com/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf`, byte-identical to the bitsavers.org copy.
- Source (80386 PRM): `http://bitsavers.trailing-edge.com/components/intel/80386/230985-001_80386_Programmers_Reference_Manual_1986.pdf`, a mirror of bitsavers.org serving the byte-identical file; bitsavers.org itself refuses scripted fetch without a browser user agent (http 403).
  Intel's advertised endpoint `cdrdv2.intel.com/v1/dl/getContent/671200` **301s to whatever
  the newest revision is**, so it is not a pin. The pin is the revision-specific asset above,
  recorded together with the order number so a reader can tell *which* document a citation
  meant after Intel publishes 093. To move it deliberately:
  `curl -sI https://cdrdv2.intel.com/v1/dl/getContent/671200 | grep -i ^location`, then set
  `SDM_ORDER`/`SDM_ASSET` in `fetch-oracles.sh` and re-run `fetch`.
- Source (APM): archive.org snapshot of
  `www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/40332.pdf`
  — `www.amd.com` blocks scripted fetch from here (http 000), the same obstacle the GCN ISA
  PDFs hit.
- **The SDM is the primary** oracle. Cite the APM when it disambiguates something the SDM
  leaves undefined, or when a Jaguar-specific behaviour is at issue — and say which manual
  you are citing, because "undefined" in one is not "undefined" in the other.

## x86-64 psABI (process initialisation, syscall ABI, exception→signal map) — **FETCH-ONLY**

System V ABI, AMD64 Architecture Processor Supplement, LaTeX sources from
`gitlab.com/x86-psABIs/x86-64-ABI` @ commit
**`e1ce098331da5dbd66e1ffc74162380bcc213236`** (2025-03-12).

| File | sha256 | Covers |
|---|---|---|
| `psabi/low-level-sys-info.tex` | `2d42f2ab76b99a3b8456e6bc07e18314e85991119f72db90ca1175328e27b705` | §3.2 function calling sequence (register roles, stack frame, red zone); §3.3.1 hardware exception types — the exception→signal map `x86jit-linux/src/sigsegv.rs` implements; §3.4.1 initial stack and register state; §3.4.3 the auxiliary vector — both built by `x86jit-elf`'s `setup_stack` |
| `psabi/kernel.tex` | `f4756c5f1103de96e0f91fc663d7f089b06789d9a8d796ec0b3e5097f368f1c7` | A.2.1 the syscall calling convention: arguments in RDI, RSI, RDX, **R10**, R8, R9 — *not* RCX, which the `syscall` instruction clobbers. The one fact most likely to be mis-stated from memory |

**Not vendored, and the reason is stronger than the SPIR-V one.** That repository carries no
`LICENSE` and no `COPYING` file at all. The only licence statement in its entire tree is one
line in `abi.tex`'s revision history, scoping CC-BY-4.0 to *Intel's changes* — not to the
document. For SPIR-V a document-wide grant exists and is merely ambiguous about
redistribution; here there is no document-wide grant to be ambiguous about.

**Pinned as source, not as the PDF.** The upstream README advertises
`.../jobs/artifacts/master/raw/x86-64-ABI/abi.pdf?job=build`, which is a CI artifact of the
latest master build: it moves on every merge and GitLab expires artifacts. It cannot be
pinned at all. The `.tex` at a commit is immutable, greppable and diffable.

## Linux x86 syscall tables + process/signal uapi (x86jit's OS surface) — **VENDORED**

From `torvalds/linux` @ tag **`v6.12`**. License: **GPL-2.0 WITH Linux-syscall-note** (SPDX
header in each file). These are the **first copyleft sources vendored in this stash** — GPL-2.0
§1 permits verbatim redistribution provided the notices travel with the copy, so both licence
texts are vendored alongside. See `NOTICE.md` for the full reasoning.

| File | Origin | sha256 | Covers |
|---|---|---|---|
| `linux-x86/syscall_64.tbl` | `arch/x86/entry/syscalls/syscall_64.tbl` | `980ce3115028c71c5618e7864d262017bde8103bcfe7b413147a14fd312c92ac` | The x86-64 syscall numbers. `x86jit-linux/src/shim.rs` states 28 `SYS_*` constants with no citation at all; this is that citation |
| `linux-x86/syscall_32.tbl` | `arch/x86/entry/syscalls/syscall_32.tbl` | `48deaff56363a5889acd966b5a9df8cf084e8951c45fddd7a2f33f3b8bc4d81d` | The i386 `int 0x80` numbers — a *different* table, which is exactly why the shim keeps a separate one for its Compat32 mode |
| `linux-x86/siginfo.h` | `include/uapi/asm-generic/siginfo.h` | `18625c075e9ee00c53f0389f50bfca3b85da648bb994383acfc106c5dde5dce0` | Fixes `si_addr`'s **offset**: `si_signo`/`si_errno`/`si_code`, then `union __sifields` whose `_sigfault._addr` is a `void __user *` — natural LP64 alignment puts it at 16, the number `sigsegv.rs` hardcodes |
| `linux-x86/sigcontext.h` | `arch/x86/include/uapi/asm/sigcontext.h` | `84e2cf444ec6a539a4bc0b46717775cb1fd1f591301b7469ba143e56f43afc0c` | `struct sigcontext_64`'s field **order** — the order glibc's `gregs[]` (`REG_RIP`, `REG_ERR`) indexes, and where the page-fault error code sits. What bit 1 of that code *means* is the SDM's job, not this header's |
| `linux-x86/COPYING` | `COPYING` | `fb5a425bd3b3cd6071a3a9aff9909a859e7c1158d54d32e07658398cd67eb6a0` | Licence text (travels with the copies) |
| `linux-x86/LICENSES_exceptions_Linux-syscall-note` | `LICENSES/exceptions/Linux-syscall-note` | `8e378ab93586eb55135d3bc119cce787f7324f48394777d00c34fa3d0be3303f` | The exception that makes user-space use of the syscall interface not a derived work |

## SingleStepTests 80286 (hardware-captured differential oracle) — **VENDORED docs / FETCH-ONLY corpus**

A per-instruction test corpus for the Intel 80286, by **Daniel Balsom**, captured from a real
**Harris N80C286-12** through the ArduinoX86 CPU-to-Arduino interface — i.e. ground truth from
silicon, not from another emulator. `SingleStepTests/80286` @ commit
**`37c73caf53dcd22d3dd369ff09305d13d117a4fe`** (2025-11-02). MIT.

The **documentation is vendored; the 611 MB corpus is not.** Every normative claim a consuming
harness rests on lives in the README, not in the data — and 611 MB of test vectors is not a
source anyone cites by section. Mirroring it would make this stash a data host rather than a
ledger. The consumer (`x86jit-tests/vendor/80286/fetch.sh`) fetches the corpus itself at this
same pin.

| File | Origin | sha256 | Covers |
|---|---|---|---|
| `ss286/README.md` | `README.md` | `0381eb13604e5b2cea6f3ede348146d28d129b8f5f6d4af3668cc54be83bf025` | The normative claims: `PUSH SP` pushes the **pre-push** SP; `D2`/`D3` do **not** mask CL (the CPU masks to 5 bits internally); `IN` returns `0xFF`/`0xFFFF`; an exception record carries `flag_address` so undefined FLAGS bits can be masked out of the memory compare; a revoked test is identified by its `HASH` chunk |
| `ss286/revocation_list.txt` | `revocation_list.txt` | `219381caae2bd5f86d616fd9ee7309193c1dc254589ef032c0059dd42db3716f` | The revoked-test hashes. **Vendored for a second reason:** x86jit's `ss286::load_revocations` reads this from the corpus directory, but its `fetch.sh` never downloads it — so today the revocation list is silently always empty and revoked tests are being trusted |
| `ss286/CHANGELOG.md` | `CHANGELOG.md` | `5efd9f33316ea637f551a2662257cac0d5939ffc242bfa6252d0f5debe42cfc2` | Which corpus revision changed what — needed to tell a real regression from a corpus correction |
| `ss286/LICENSE` | `LICENSE` | `17169beea9b37538e699029d724687acf89182988b78f5ddce0f65a01db14653` | MIT text (travels with the copies) |

## MOO — the corpus's binary container (`dbalsom/moo`) — **VENDORED**

`dbalsom/moo` @ commit **`c438962d2b30856817d8e59bd5f0f4c628596ca8`** (2025-11-19). MIT,
435 KB whole, so the cited parts are vendored rather than fetched.

| File | Origin | sha256 | Covers |
|---|---|---|---|
| `moo/moo_format_v1.md` | `doc/moo_format_v1.md` | `72187464b34c255e413b24a127adcce2fb87996e86d2f33999e5b7047f5b636f` | The format specification — chunk framing and ids |
| `moo/chunks.rs` | `crates/moo/src/types/chunks.rs` | `05a1760cbd1cfb904d481bb6e41ca86fc85c4817c6c351fbb9f308739a2b6b0b` | Reference implementation of the chunk ids — a **second witness** to the spec |
| `moo/registers_16.rs` | `crates/moo/src/registers/registers_16.rs` | `a3a22d25bbc93d6041463dba7cec01ca2f51ff9d8e8f7f34cb4d8a04f1468a33` | The `REGS` presence-bitmask **ordering**, which x86jit's hand-written parser (`x86jit-tests/src/ss286.rs`) must agree with. A hand parser and a spec disagreeing silently is precisely the failure this stash exists to make visible |
| `moo/README.md` | `README.md` | `8fe54f83e1780149f727a9f64810ee773a6bfa2d18f63b7175c5f57f5dbb3883` | Format overview |
| `moo/LICENSE` | `LICENSE` | `17169beea9b37538e699029d724687acf89182988b78f5ddce0f65a01db14653` | MIT text |

---

## Second-hand blocks in a clean source (provenance quarantine)

The AGENTS.md provenance Hard rule governs what we **consult**, not only what we commit.
The tainted file is in a fetch-only source, so it is not committed anywhere — but the stash
is precisely where an agent goes *expecting a clean source*, which makes a second-hand block
inside one more dangerous here than it would be anywhere else. (This is also the reason the
OpenOrbis tree stays fetch-only now that other sources are vendored: the quarantine modifies
that header, and a modified copy is not something to redistribute.)

**Finding (TASK-344).** `openorbis/OpenOrbis-PS4-Toolchain/include/orbis/_types/kernel.h`
carried, at its head, an upstream inline comment naming a **PS4 emulator project** as the
source of its own `EVFILT_*` block (the filter numbers `-1..-22` and `EVFILT_SYSCOUNT`).
Nothing in unemups4 was ever derived from it — the emulator encodes no kqueue filter number
anywhere (`crates/libs/src/libkernel/equeue.rs` tracks GNM completion events by handle and
never reads a filter value), and TASK-341's mapping contract came from the OpenOrbis
function *declarations* plus FreeBSD's `mman.h`.

**Decision: quarantine, in the reproducer.** `fetch-oracles.sh` excises the block on every
fetch (`quarantine_openorbis`, also runnable as `./fetch-oracles.sh quarantine`) and leaves
a marker comment in its place naming what was removed, why, and where the clean source is.
`./fetch-oracles.sh verify` re-checks it and fails loudly if the block is back.

Annotation alone was rejected: it protects only the reader who happens to open MANIFEST.md
first, and the failure mode here is an agent that opens the header directly and believes it
is on a clean source. Removing the bytes protects that reader too. The quarantine is in the
*reproducer* rather than done by hand so it survives a fresh fetch on any machine — the
checkout is `-qf` so a re-pin discards the modified file and the quarantine re-applies.

What is deliberately **kept**: the `ORBIS_KERNEL_EVFILT_* → EVFILT_*` alias lines further
down the file. The second-hand part was the numeric *values*; the alias mapping (e.g.
`ORBIS_KERNEL_EVFILT_GNM` is the graphics-core filter) is OpenOrbis's own first-hand SDK
surface. Those aliases now reference undefined macros, which matters not at all: this stash
is **cite-only and never compiled**.

**Replacement source.** `freebsd9/sys_sys_event.h` (added by the same task) is the
first-hand oracle for the base kqueue filters `EVFILT_READ`..`EVFILT_USER` (-1..-11),
`EVFILT_SYSCOUNT` 11. Sony's console-specific filters (-12..-22: polling, display,
graphics-core, hrtimer, UVD/VCE/SDMA traps, GPU exceptions) are **not** in FreeBSD and have
**no clean source in this stash** — derive them from the dumped guest binary or leave them
unmodelled. Do not reintroduce them from a second-hand list.

**Sweep (TASK-344) — one found by accident is not evidence there is only one.** Method:
across the whole fetched stash, (a) a case-insensitive name grep for known PS4-emulator
projects and RE wikis, and (b) for the OpenOrbis tree specifically, a census of *every*
external URL plus a grep for non-URL attributions (`credit`, `thanks`, `taken from`,
`based on`, `reversed by`). Results:

- `amd/`, `freebsd9/`, `vulkan/`, `mesa/` — **no hits**. Clean.
- OpenOrbis tree — **exactly one** emulator citation, the one above. The PS4-specific
  headers (`include/orbis/`) carry only four external URLs in total: the quarantined one,
  `freebsd/freebsd-src` (clean, `sys/vm/vm.h` for `vm_prot_t`), a scene stub-lib generator
  (`flatz/ps4_stub_lib_maker_v2`, `_types/bgft.h`), and `psdevwiki` (`_types/sysmodule.h`,
  the sysmodule id list). Everything else resolves to bundled third-party libraries (stb,
  freetype, glm, GL/EGL headers) and is irrelevant to PS4 facts.
- **Not quarantined, but flagged:** the `psdevwiki` citations (`_types/sysmodule.h:5` and
  `docs/MD/PS4 Libraries/Sysmodule.md:2`) and the individual scene-RE credits (`reversed by
  flatz`, `Struct Credits - psxdev`, `Credit: LightningMods`, `Enum Credits - OSM-Made` in
  this same `kernel.h`). These are second-hand relative to the allowed-source list, but they
  are **not** emulator projects, so the Hard rule's specific prohibition does not reach
  them. Treat any fact resting on one of them as unpinned: corroborate against the dumped
  guest binary before relying on it, and say so at the use site.

## OpenOrbis — SELF/OELF layout spec (loader oracle, in the pinned clone)

Beyond headers, the OpenOrbis clone carries an authoritative **SELF/OELF format spec**:
- `openorbis/OpenOrbis-PS4-Toolchain/docs/MD/OELF Specification/PS4 ELF Specification.md`
- `.../PS4 ELF Specification - Dynlib Data.md`
- `.../extra/OpenOrbis PS4 SELF Project.zip` (make-fself source — constructs the format)
These are THE clean oracle for "how a SELF is laid out" (loader mechanisms #2 SELF, #3
dynamic/DT_SCE). Corroborate against DUMP (real `eboot.bin` at /home/mikolaj/PS4/CUSA*/).

## Ground truth (DUMP) — not in this stash, referenced by location

Real dumped guest binaries live with the game assets (gitignored):
`/home/mikolaj/PS4/{CUSA11302 Celeste, CUSA05952 Little Nightmares, CUSA03173, ...}/eboot.bin`.
Loader/.sb/fetch mechanisms validate against these. Cite by title+path in the ledger.

## llvm-mc (independent GCN witness)

- Version: **LLVM 22.1.8**, `/usr/bin/llvm-mc`. Target `amdgcn` registered.
- **Disassembly NOT supported** for gfx600/gfx700 subtargets in this build
  (`LLVM ERROR: disassembly not yet supported for subtarget`).
- **Use the ASSEMBLE direction**: `llvm-mc --assemble --arch=amdgcn --mcpu=gfx700 --show-encoding`
  emits the encoding bytes for a mnemonic (verified: `s_mov_b32 s0,s1 → [0x01,0x03,0x80,0xbe]`).
  Witness for #6/#9: assemble known mnemonics, compare encoding bytes to our decoder's
  expected. llvm-mc never saw shadPS4 → agreement proves we both track the hardware.
- mcpu for Liverpool (PS4): **gfx700** (Sea Islands / CIK). gfx600 = Southern Islands cross-check.
- mcpu for Oberon (PS5): **gfx1030** (RDNA2 / Navi 2x). Unlike gfx600/gfx700, this build
  supports **both directions** for RDNA2 — verified:
  `v_add_f32 v0,v1,v2 --assemble → [0x01,0x05,0x00,0x06]` and the reverse `--disassemble`
  round-trips. So RDNA2 has a full bidirectional encoding witness (stronger than the
  assemble-only PS4 path); `gfx1010` = RDNA1 cross-check.

---

## TODO / gaps

- [x] ~~Mesa `src/amd`~~ — DONE via `gitlab.freedesktop.org/mesa/mesa.git` (git clone works).
- [x] ~~**PS5 / RDNA2 shader ISA**~~ — DONE: `amd/rdna2-isa.pdf` (291pp, © AMD cite-only) +
      Mesa `gfx103.json` / `gfx10-rsrc.json` (RDNA2 regs + T#/V#/S#) + llvm-mc `gfx1030`
      (bidirectional encoding witness). Covers PS5 Oberon GPU-ISA facts end to end.
- [ ] **PS5 Sony-facing GPU API (AGC)** — the PS5 replaces GNM with **AGC**; there is **no**
      clean public oracle equivalent to the OpenOrbis GnmDriver headers. This is the real
      remaining PS5 gap. Until a clean source exists, AGC-level facts must come from the
      **dumped PS5 guest binary** (RE the command-stream the title emits) cross-checked against
      the RDNA2-ISA PDF + Mesa `pkt3.json` for the underlying PM4 — never from another emulator.
- [x] ~~**PS5 SELF/PRX loader**~~ — DONE: the PS5 container/dynamic layout was RE'd from the
      **retail PS5 dump** (ground-truth oracle), corroborated by the OpenOrbis OELF spec where
      it carries over from PS4; the PS5 `ps5_names.txt` NID corpus feeds import resolution. The
      dumped binary is the clean primary source — cite it by title+path in the ledger. No
      external spec needed.
- [x] ~~**Vulkan spec**~~ — DONE (TASK-277, widened TASK-279): `vulkan/textures.adoc` @
      `v1.4.309` pins the `OpImage*Gather` return order, which nothing in the AMD ISA or Mesa
      `src/amd` states; `renderpass.adoc` + `resources.adoc` pin the framebuffer-layers VUIDs
      and the image-view array-sub-range semantics the layered-render-target path relies on;
      `interfaces.adoc` + `spirvenv.adoc` pin the `Layer` built-in's rules (execution model,
      storage class, scalar 32-bit integer, out-of-range undefined) and the
      capability/extension enablement rule the device gate implements.
      Only the chapters the GPU path cites are vendored; add a row to `vendored_files()` in
      `fetch-oracles.sh` and re-run `fetch` if a further chapter is ever needed.
- [ ] **Durability of the fetch-only sources** — the vendored half of the stash survives any
      upstream disappearing; the fetch-only half does not. Three live risks: the AMD ISA PDFs
      exist for us only as archive.org snapshots of a retired `developer.amd.com`; the SPIR-V
      spec HTML is a rolling artifact behind a CDN with no ref at all; the OpenOrbis clone is
      one GitHub repository. None may (or may practically) be vendored here — so if one of
      them goes, the citations resting on it are pinned by a hash whose source is gone. Keep
      a private copy off this repository, and prefer a vendored witness where one exists
      (Mesa `gfx6/7.json` + the kernel headers cover much of what the PDFs witness).
- [ ] **CLRXdisasm** — not installed; would be a second GCN disasm witness. Optional (llvm-mc
      assemble covers #6). Install `CLRadeonExtender` if a disasm-direction witness is wanted.
- [ ] Ground-truth captures (real Celeste DCB/CCB) + dumped .sb/fetch-shaders are the Sony-GT
      oracle for #4/#8/#10 — they live with the game assets / scrape tooling, not in this stash.
      Reference their location in the ledger when used.

## Access notes (for re-fetch)

- amd.com / docs.amd.com: blocked from this host (http 000/301) → use archive.org `…/2id_/…`.
- github.com raw + clone: works (OpenOrbis cloned, kernel raw fetched).
- Mesa: GitHub `Mesa3D/mesa` 404s; **`gitlab.freedesktop.org/mesa/mesa.git` git clone WORKS**
  (Anubis blocks the browser, not the git protocol) — use it for Mesa.
- Mesa `.gitattributes` sets `*.csv eol=crlf`: a working-tree copy of `radeonsi/ci/*.csv` is
  NOT the stored blob. Vendor from `git cat-file`, never from the checkout.
- `registry.khronos.org` is behind a CDN that injects a per-request challenge script into the
  SPIR-V HTML — a raw sha256 of that download is never reproducible. See `pin_hash()`.
- Bash tool here executes under **fish** for some invocations — wrap bash-only syntax
  (`declare -A`, `${!arr[@]}`) in `bash -c` or a `.sh` run with `bash`.
