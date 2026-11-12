#!/usr/bin/env bash
# The clean-oracle stash (see MANIFEST.md): a REPRODUCER *and* a vendored copy of every
# source that may legally be redistributed.
#
# Every hardware/OS fact in the consuming project cites a clean primary source — AMD ISA,
# Mesa, the Linux kernel AMD headers, FreeBSD, the OpenOrbis SDK, the Vulkan/SPIR-V specs.
# A citation is only worth something if a reader who was not there can check it, which
# needs the source pinned by ref + hash AND still reachable years later. So:
#
#   * what may be redistributed is VENDORED here (committed) — durable, no network needed;
#   * what may NOT (AMD ISA PDFs, the SPIR-V spec HTML) stays fetch-only, pinned by sha256;
#   * `verify --upstream` re-downloads at the pinned refs and diffs against the committed
#     copies, so nobody has to take our word that the vendored bytes are upstream's bytes.
#
# Usage:
#   ./fetch-oracles.sh fetch              # download to pinned refs, refresh the vendored
#                                         # copies, (re)write SHA256SUMS + NOTICE.md
#   ./fetch-oracles.sh verify             # OFFLINE: committed copies vs recorded sha256
#   ./fetch-oracles.sh verify --upstream  # re-download at the pins and DIFF against them
#   ./fetch-oracles.sh notice             # regenerate NOTICE.md from the tables below
#   ./fetch-oracles.sh sums               # rewrite SHA256SUMS from what is on disk
#   ./fetch-oracles.sh quarantine         # re-apply the OpenOrbis provenance quarantine
#
# Exit codes:
#   0 ok · 1 LOCAL DRIFT (a committed copy no longer matches its recorded sha256, or a
#   vendored file is missing, or the provenance quarantine failed) · 2 usage · 3 UPSTREAM
#   MOVED (copies match their sums, but upstream at the pinned ref no longer does) ·
#   4 INCOMPLETE (an upstream was unreachable, so the check could not be finished).
#
# AMD ISA PDFs are © AMD (kept local, cite-only, NOT redistributed). This script fetches
# them from public archives for local reference; they are gitignored and must stay so.
set -euo pipefail
cd "$(dirname "$0")"

# --- pinned refs (change deliberately; then re-run fetch to refresh the vendored copies) ---
KERNEL_REF="v6.12"                                   # torvalds/linux tag
MESA_COMMIT="42f591b906b7e8a966cc339f84d2671f423d48c4"
OPENORBIS_COMMIT="0a1aaf9dd4a92695538bdeb09fb056d06dd11725"
FREEBSD_REF="release/9.0.0"                           # PS4 Orbis OS base
VULKAN_DOCS_REF="v1.4.309"                            # KhronosGroup/Vulkan-Docs tag

# --- x86 section (serves x86jit; MANIFEST.md "x86 ..."). Pinned SEPARATELY from KERNEL_REF
# on purpose: the GPU register headers and the x86 syscall/uapi tables move for unrelated
# reasons, and one consumer's ledger must not be dragged along by the other's pin bump.
KERNEL_X86_REF="v6.12"                                # torvalds/linux tag (x86 uapi)
PSABI_COMMIT="e1ce098331da5dbd66e1ffc74162380bcc213236"  # x86-64 psABI, 2025-03-12
MOO_COMMIT="c438962d2b30856817d8e59bd5f0f4c628596ca8"    # dbalsom/moo, 2025-11-19
SS286_COMMIT="37c73caf53dcd22d3dd369ff09305d13d117a4fe"  # SingleStepTests/80286, 2025-11-02

# Intel SDM: the "latest" endpoint (cdrdv2.intel.com/v1/dl/getContent/671200) MOVES on every
# revision, so it cannot be the pin. The pin is the revision-specific asset it redirects to —
# order number, revision and cdrdv2 content id all recorded, so a reader can tell WHICH
# document a citation meant even after Intel publishes the next one. To move it deliberately:
#   curl -sI https://cdrdv2.intel.com/v1/dl/getContent/671200 | grep -i ^location
# then set SDM_ORDER/SDM_ASSET from the result and re-run `fetch`.
SDM_ORDER="325462-092US"                              # June 2026, 5363 pp
SDM_ASSET="922475/325462-092-sdm-vol-1-2abcd-3abcd-4.pdf"
# AMD64 APM, publication 40332 rev 4.08 (April 2024, 3347 pp). www.amd.com blocks scripted
# fetch from here (http 000), exactly like the GPU ISA PDFs — hence the archive.org snapshot.
APM_PUB="40332"
# Intel 80386 Programmer's Reference Manual, order number 230985-001 (1986). bitsavers.org
# answers scripted fetch without a browser user agent with http 403; its trailing-edge.com
# mirror serves the byte-identical file (same sha256), so the mirror is the pin.
I386PRM_ORDER="230985-001"
I286PRM_ORDER="210498-005"   # 80286 and 80287 Programmer's Reference Manual (1987); same mirror rule
# Intel 8080 manuals for x80; same mirror rule. ORDER is the order number printed on the
# document itself. The mirror files the assembly-language manual as revision "9800301D";
# its title page prints 9800301-04 (May 1981 printing), so that URL cannot reuse ORDER.
I8080UM_ORDER="98-153B"       # 8080 Microcomputer Systems User's Manual (September 1975)
I8080ALPM_ORDER="9800301-04"  # 8080/8085 Assembly Language Programming Manual (May 1981)
# NEC V20/V30 user's manual for x86jit's V20/V30 models and their 8080 emulation mode; same
# mirror rule. STOCK is the stock number printed on the title page; the mirror's file name
# does not carry it.
NECV20UM_STOCK="500350"      # uPD70108 (V20) and uPD70116 (V30) User's Manual (October 1986)

RAW_KERNEL="https://raw.githubusercontent.com/torvalds/linux/${KERNEL_REF}"
RAW_KERNEL_X86="https://raw.githubusercontent.com/torvalds/linux/${KERNEL_X86_REF}"
RAW_PSABI="https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/${PSABI_COMMIT}/x86-64-ABI"
RAW_MOO="https://raw.githubusercontent.com/dbalsom/moo/${MOO_COMMIT}"
RAW_SS286="https://raw.githubusercontent.com/SingleStepTests/80286/${SS286_COMMIT}"
SDM_URL="https://cdrdv2-public.intel.com/${SDM_ASSET}"
APM_URL="https://web.archive.org/web/2id_/https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/${APM_PUB}.pdf"
I386PRM_URL="http://bitsavers.trailing-edge.com/components/intel/80386/${I386PRM_ORDER}_80386_Programmers_Reference_Manual_1986.pdf"
I286PRM_URL="http://bitsavers.trailing-edge.com/components/intel/80286/${I286PRM_ORDER}_80286_and_80287_Programmers_Reference_Manual_1987.pdf"
I8080UM_URL="http://bitsavers.trailing-edge.com/components/intel/MCS80/${I8080UM_ORDER}_Intel_8080_Microcomputer_Systems_Users_Manual_197509.pdf"
I8080ALPM_URL="http://bitsavers.trailing-edge.com/components/intel/MCS80/9800301D_8080_8085_Assembly_Language_Programming_Manual_May81.pdf"
# 8085 sources for x80 (M3); same mirror rule as the 8080 manuals.
I8085UM_ORDER="205775-002"   # MCS-80/85 Family User's Manual (January 1983)
I8085UM_URL="http://bitsavers.trailing-edge.com/components/intel/MCS80/MCS80_85_Users_Manual_Jan83.pdf"
IECH1988_URL="http://bitsavers.trailing-edge.com/components/intel/_dataBooks/1988_Intel_Embedded_Controller_Handbook_Volume_I_8-Bit.pdf"
NECV20UM_URL="http://bitsavers.trailing-edge.com/components/nec/V-Series/V20_V30_Users_Manual_Oct86.pdf"
# 8080 CPU exercisers for x80, from the download area of their 2013 maintainer (Mike Douglas).
CPU8080_TESTS_URL="https://altairclone.com/downloads/cpu_tests"
RAW_FREEBSD="https://raw.githubusercontent.com/freebsd/freebsd-src/${FREEBSD_REF}"
RAW_VULKAN="https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/${VULKAN_DOCS_REF}"
MESA_URL="https://gitlab.freedesktop.org/mesa/mesa.git"
OPENORBIS_URL="https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain.git"
export GIT_TERMINAL_PROMPT=0

# Mesa: the upstream clone is fetch-only scratch (gitignored); the vendored tree is what is
# committed, at the SAME paths the project's citations use (`oracles/mesa/mesa/src/...`).
MESA_CLONE=".upstream/mesa"
MESA_VENDOR="mesa/mesa"
# Cited dirs only — `src/amd` whole is 25 MB / 800 files. `compiler` + `llvm` are here
# because the ledger cites aco_select_nir.cpp, ac_llvm_build.c and ac_nir_to_llvm.c.
MESA_SPARSE=(src/amd/common src/amd/registers src/amd/addrlib src/amd/llvm src/amd/compiler
             src/gallium/drivers/radeonsi)
# Licence witnesses shipped alongside the vendored tree (MIT requires the notice to travel
# with the copy). Single files, so they are extracted with `git show` rather than checked out.
MESA_LICENSE_FILES=(docs/license.rst licenses/MIT)

log(){ printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
err(){ printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; }

# ===========================================================================================
# The source tables. ONE table per redistribution class, and they drive BOTH `fetch` and
# `verify --upstream` — a source cannot be fetched from one URL and checked against another.
# Columns: <local path> <upstream URL> <min bytes>.  `#` lines are prose and are stripped.
# ===========================================================================================

# --- VENDORED: committed to this repository (see NOTICE.md for licence + attribution) ---
vendored_files(){ cat <<EOF
# --- Linux kernel radeon/amdgpu register + PM4 headers (canonical AMD MMIO/PM4).
# Individually MIT-licensed (the "Permission is hereby granted, free of charge" header AMD
# put on the radeon/amdgpu sources), NOT GPL-2 like the kernel as a whole — which is why
# they may be vendored here. The per-file headers are preserved verbatim.
# cik.c carries cik_tiling_mode_table_init() — the GB_TILE_MODE / GB_MACROTILE_MODE register
# CONTENTS for each CIK pipe count, which no header and no Mesa file states.
amd/kernel-sid.h        ${RAW_KERNEL}/drivers/gpu/drm/radeon/sid.h          2000
amd/kernel-cikd.h       ${RAW_KERNEL}/drivers/gpu/drm/radeon/cikd.h         2000
amd/kernel-cik.c        ${RAW_KERNEL}/drivers/gpu/drm/radeon/cik.c          2000
amd/kernel-evergreend.h ${RAW_KERNEL}/drivers/gpu/drm/radeon/evergreend.h   2000
amd/kernel-soc15d.h     ${RAW_KERNEL}/drivers/gpu/drm/amd/amdgpu/soc15d.h   2000
amd/kernel-nvd.h        ${RAW_KERNEL}/drivers/gpu/drm/amd/amdgpu/nvd.h      2000

# --- FreeBSD 9.0 (Orbis OS base): syscall table, errno, ELF, mman, fcntl. BSD-2/3-Clause.
# COPYRIGHT is the project's licence text, vendored so the notice travels with the copies.
freebsd9/COPYRIGHT                 ${RAW_FREEBSD}/COPYRIGHT                  500
freebsd9/sys_kern_syscalls.master  ${RAW_FREEBSD}/sys/kern/syscalls.master   500
freebsd9/sys_sys_errno.h           ${RAW_FREEBSD}/sys/sys/errno.h            500
freebsd9/sys_sys_elf_common.h      ${RAW_FREEBSD}/sys/sys/elf_common.h       500
freebsd9/sys_sys_elf64.h           ${RAW_FREEBSD}/sys/sys/elf64.h            500
freebsd9/sys_sys_mman.h            ${RAW_FREEBSD}/sys/sys/mman.h             500
freebsd9/sys_sys_fcntl.h           ${RAW_FREEBSD}/sys/sys/fcntl.h            500
freebsd9/sys_sys_signal.h          ${RAW_FREEBSD}/sys/sys/signal.h           500
freebsd9/sys_sys_unistd.h          ${RAW_FREEBSD}/sys/sys/unistd.h           500
# \`mman.h\` gives the MAP_* flag VALUES but says nothing about what a mapping does when the
# requested range is already mapped. That contract is stated in exactly two places, and
# \`sceKernelBatchMap\`'s direct-memory entries need it (TASK-341/TASK-344):
#   - \`lib/libc/sys/mmap.2\` — normative: "If a MAP_FIXED request is successful, the mapping
#     established by mmap replaces any previous mappings for the process' pages in the range
#     from addr to addr + len", i.e. an overlap is NOT an error. Its ERRORS section reserves
#     ENOMEM for "MAP_FIXED was specified and the addr argument was not available".
#   - \`sys/vm/vm_mmap.c\` — the implementation that backs it: \`sys_mmap()\`'s MAP_FIXED path
#     fails only with EINVAL (misalignment, range outside the user map, wrap), and
#     \`vm_mmap_object()\` routes the fixed case to \`vm_map_fixed()\` (replace) rather than
#     \`vm_map_find()\` (search). \`vm_mmap_to_errno()\` is the whole failure vocabulary.
# 9.0 has no MAP_EXCL, so there is no way to ask this mmap to REFUSE on collision.
freebsd9/lib_libc_sys_mmap.2       ${RAW_FREEBSD}/lib/libc/sys/mmap.2        500
freebsd9/sys_vm_vm_mmap.c          ${RAW_FREEBSD}/sys/vm/vm_mmap.c           500
# First-hand replacement for the EVFILT_* block quarantined out of the OpenOrbis header
# (see \`quarantine_openorbis\`): the BASE kqueue filters, EVFILT_READ..EVFILT_USER (-1..-11)
# with EVFILT_SYSCOUNT 11. Sony's console-specific filters (-12..-22) are NOT here and have
# no clean source — derive those from the dumped guest binary or leave them unmodelled.
freebsd9/sys_sys_event.h           ${RAW_FREEBSD}/sys/sys/event.h            500

# --- Vulkan spec (normative SPIR-V image-operation + host resource semantics). The .adoc
# chapters carry "SPDX-License-Identifier: CC-BY-4.0" in their own headers; vk.xml carries
# "Apache-2.0 OR MIT". LICENSE.adoc is the repository's licence text, vendored with them.
#
# \`chapters/textures.adoc\` is the spec source for section "Texel Gathering"
# ([[textures-gather]]) — the ONLY clean statement of which of the 2x2 texels an
# OpImage*Gather returns in which component. The AMD ISA describes gather4 as
# "gather 4 single component elements (2x2)" and never gives the order, and Mesa
# src/amd passes the hardware order through unpermuted without naming it, so this
# file is what closes the GCN gather lowering (TASK-277).
#
# \`chapters/renderpass.adoc\` carries the framebuffer validity block, including
# VUID-VkFramebufferCreateInfo-flags-04535 (every attachment view's
# \`subresourceRange.layerCount\` >= \`VkFramebufferCreateInfo::layers\`) and
# VUID-VkFramebufferCreateInfo-layers-00890 (\`layers\` <= \`maxFramebufferLayers\`) — the
# normative rule a LAYERED colour target's framebuffer has to satisfy (TASK-279). The same
# file carries the "Render Pass Compatibility" section ([[renderpass-compatibility]]) —
# "Two attachment references are compatible if they have matching format and sample count"
# — the rule that ties the colour format of the pass a draw is recorded into to the format
# of the pass its pipeline was created against (TASK-290).
#
# \`chapters/resources.adoc\` carries the \`VkImageSubresourceRange\` semantics
# ("baseArrayLayer is the first array layer accessible to the view; layerCount is the
# number of array layers starting from baseArrayLayer"), which is what makes an attachment
# view over \`SLICE_START .. SLICE_START+n\` the host expression of a GCN colour target's
# array sub-range (TASK-279).
#
# \`chapters/interfaces.adoc\` carries the built-in variable rules, including the whole
# \`Layer\` block: VUID-Layer-Layer-04272 (which execution models may use it),
# VUID-Layer-Layer-04274 (Output storage class outside a fragment shader),
# VUID-Layer-Layer-04276 (a scalar 32-bit integer), and the out-of-range clause — a
# \`Layer\` value outside the framebuffer's layer count leaves the framebuffer values for
# ALL layers undefined. That last one is why an exported slice index is gated rather than
# trusted (TASK-279).
#
# \`appendices/spirvenv.adoc\` carries the SPIR-V environment rules: a module must not use a
# capability or an \`OpExtension\` whose corresponding Vulkan extension is not enabled on
# the device. That is the normative basis for the guest-side device-capability gate in
# front of the \`ShaderViewportIndexLayerEXT\` module the recompiler emits (TASK-279).
# \`chapters/samplers.adoc\` is the only normative statement of what each \`VkCompareOp\`
# enumerant COMPUTES — "VK_COMPARE_OP_LESS specifies that the comparison evaluates
# reference < test" and so on. \`chapters/textures.adoc\` §"Depth Compare Operation" says
# which value plays which role (the SPIR-V \`Dref\` operand is the reference, the texel
# depth is the test) but never defines the operators themselves, so the shadow-lookup
# oracle needs both files to compute a result at all (TASK-287).
vulkan/LICENSE.adoc        ${RAW_VULKAN}/LICENSE.adoc              500
vulkan/textures.adoc       ${RAW_VULKAN}/chapters/textures.adoc    50000
vulkan/samplers.adoc       ${RAW_VULKAN}/chapters/samplers.adoc    50000
vulkan/renderpass.adoc     ${RAW_VULKAN}/chapters/renderpass.adoc  50000
vulkan/resources.adoc      ${RAW_VULKAN}/chapters/resources.adoc   50000
vulkan/interfaces.adoc     ${RAW_VULKAN}/chapters/interfaces.adoc  50000
vulkan/spirvenv.adoc       ${RAW_VULKAN}/appendices/spirvenv.adoc  50000
# \`chapters/features.adoc\` enumerates which storage-image formats the
# \`StorageImageExtendedFormats\` capability covers — the list a DECLARED \`OpTypeImage\`
# format must stay clear of to need no optional capability (TASK-299 §2c).
# \`chapters/limits.adoc\` carries the "Required Limits" table: the guaranteed floors for
# \`maxPerStageDescriptorStorageImages\`, \`maxComputeSharedMemorySize\` and
# \`maxComputeWorkGroupInvocations\` that bound a dispatch's declared resources.
# \`chapters/shaders.adoc\` defines the Workgroup scope — a local workgroup is the set of
# invocations that "can synchronize and share data with each other using memory in the
# Workgroup storage class", with no promise of lockstep.
# \`appendices/memorymodel.adoc\` gives the synchronizes-with rule a control barrier
# satisfies, which is what makes an inserted \`OpControlBarrier\` order one invocation's
# Workgroup writes before another's reads (TASK-299 §2e).
# \`chapters/devsandqueues.adoc\` states the only guarantee there is about queue-family
# capabilities: "If an implementation exposes any queue family that supports graphics
# operations, at least one queue family of at least one physical device exposed by the
# implementation must support both graphics and compute operations." That is what makes
# asking for GRAPHICS|COMPUTE on ONE family a safe requirement rather than a gamble
# (TASK-299 §3b).
# \`chapters/dispatch.adoc\` is the dispatching-commands chapter — \`vkCmdDispatch\`'s
# groupCount limits, and the statement that a compute pipeline must be bound before any
# dispatching command is recorded.
# \`chapters/synchronization.adoc\` defines the pipeline stages and access flags a
# per-dispatch barrier is written in (\`VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT\`,
# \`VK_ACCESS_SHADER_WRITE_BIT\`/\`_READ_BIT\` naming storage-image access specifically).
# \`chapters/descriptorsets.adoc\` gives the storage-image descriptor's two host rules: its
# subresources "must be in the VK_IMAGE_LAYOUT_GENERAL layout in order to access its data
# in a shader", and a STORE needs the view's format features to contain
# \`VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT\`.
# \`xml/vk.xml\` is the machine-readable spec source; it is where \`vkCmdDispatch\` carries
# \`renderpass="outside"\`, i.e. the property that generates VUID-vkCmdDispatch-renderpass —
# the rule that forces a dispatch to close the render pass (TASK-299 §3b).
vulkan/features.adoc        ${RAW_VULKAN}/chapters/features.adoc         50000
vulkan/limits.adoc          ${RAW_VULKAN}/chapters/limits.adoc           50000
vulkan/shaders.adoc         ${RAW_VULKAN}/chapters/shaders.adoc          50000
vulkan/memorymodel.adoc     ${RAW_VULKAN}/appendices/memorymodel.adoc    20000
vulkan/devsandqueues.adoc   ${RAW_VULKAN}/chapters/devsandqueues.adoc    50000
vulkan/dispatch.adoc        ${RAW_VULKAN}/chapters/dispatch.adoc          5000
vulkan/synchronization.adoc ${RAW_VULKAN}/chapters/synchronization.adoc  50000
vulkan/descriptorsets.adoc  ${RAW_VULKAN}/chapters/descriptorsets.adoc   50000
vulkan/vk.xml               ${RAW_VULKAN}/xml/vk.xml                   1000000
# \`chapters/drawing.adoc\` is the only normative statement of how a TRIANGLE_STRIP is
# ASSEMBLED into primitives — \`p_i = {v_i, v_{i+(1+i%2)}, v_{i+(2-i%2)}}\`, i.e. an odd
# primitive is \`(i, i+2, i+1)\` — stated unconditionally, before any provoking-vertex
# discussion, so it is the order the whole pipeline (a geometry shader's input included)
# receives. Its note says why the reversal exists: "so that the winding order is consistent
# throughout the strip". \`chapters/primsrast.adoc\` carries the barycentric vertex-order
# tables the \`triStripVertexOrderIndependentOfProvokingVertex\` limit refers to, which is
# what bounds the implementation-dependent part to the LAST_VERTEX variant alone.
# Fetched because TASK-362 had concluded from that limit ALONE — without the chapters it
# points at — that the order was not fixed by any readable source, and sent the question to
# the console (TASK-357/362).
vulkan/drawing.adoc         ${RAW_VULKAN}/chapters/drawing.adoc          50000
vulkan/primsrast.adoc       ${RAW_VULKAN}/chapters/primsrast.adoc       100000

# ===== x86 (serves x86jit) ==================================================================

# --- Linux x86 syscall tables + the uapi headers that fix the process/signal layout.
# SPDX on both .tbl files: \`GPL-2.0 WITH Linux-syscall-note\`. THESE ARE THE FIRST GPL-2.0
# SOURCES VENDORED HERE. GPL-2.0 permits verbatim redistribution provided the licence and the
# notices travel with the copy, which is why COPYING and the syscall-note exception text are
# vendored beside them. Nothing else here is affected: every file keeps its own licence and
# this repository relicenses nothing.
# x86jit states 28 \`SYS_*\` constants and a separate i386 \`int 0x80\` table in
# \`x86jit-linux/src/shim.rs\` with no citation at all; these two tables are that citation.
linux-x86/COPYING                  ${RAW_KERNEL_X86}/COPYING                                    200
linux-x86/LICENSES_exceptions_Linux-syscall-note ${RAW_KERNEL_X86}/LICENSES/exceptions/Linux-syscall-note 500
linux-x86/syscall_64.tbl           ${RAW_KERNEL_X86}/arch/x86/entry/syscalls/syscall_64.tbl     5000
linux-x86/syscall_32.tbl           ${RAW_KERNEL_X86}/arch/x86/entry/syscalls/syscall_32.tbl     5000
# \`siginfo.h\` is what fixes si_addr's OFFSET: si_signo/si_errno/si_code, then \`union
# __sifields\` whose \`_sigfault._addr\` is a \`void __user *\`, so natural LP64 alignment puts
# it at 16 — the number \`x86jit-linux/src/sigsegv.rs\` hardcodes. \`sigcontext.h\` gives
# \`struct sigcontext_64\`'s field ORDER, which is the order glibc's \`gregs[]\` (REG_RIP,
# REG_ERR) indexes, and where the page-fault error code sits. What that error code's bit 1
# MEANS is the SDM's job, not this header's.
linux-x86/siginfo.h                ${RAW_KERNEL_X86}/include/uapi/asm-generic/siginfo.h         5000
linux-x86/sigcontext.h             ${RAW_KERNEL_X86}/arch/x86/include/uapi/asm/sigcontext.h     5000

# --- MOO ("Machine Opcode Operation File") — the binary container the SingleStepTests corpora
# are published in. MIT, 435 KB whole, so the cited parts are vendored rather than fetched.
# \`moo_format_v1.md\` is the specification; \`chunks.rs\` and \`registers_16.rs\` are the
# reference implementation and a second witness to the chunk ids and to the REGS presence-
# bitmask ordering that x86jit's hand-written parser (\`x86jit-tests/src/ss286.rs\`) has to
# agree with — a hand parser and a spec disagreeing silently is exactly the failure this
# stash exists to make visible.
moo/LICENSE                        ${RAW_MOO}/LICENSE                                            500
moo/README.md                      ${RAW_MOO}/README.md                                          500
moo/moo_format_v1.md               ${RAW_MOO}/doc/moo_format_v1.md                             10000
moo/chunks.rs                      ${RAW_MOO}/crates/moo/src/types/chunks.rs                    1000
moo/registers_16.rs                ${RAW_MOO}/crates/moo/src/registers/registers_16.rs          5000

# --- SingleStepTests 80286: the DOCUMENTATION is vendored, the 611 MB corpus is NOT.
# Every normative claim a consuming harness rests on is in the README, not in the data —
# \`PUSH SP\` pushes the PRE-push SP; D2/D3 do NOT mask CL (the CPU masks to 5 bits
# internally); \`IN\` returns 0xFF/0xFFFF; an exception record carries \`flag_address\` so the
# undefined FLAGS bits can be masked out of the memory compare; a revoked test is identified
# by its HASH chunk against \`revocation_list.txt\`. All MIT and tiny, so the citations
# survive upstream going away; the data does not need to.
# \`revocation_list.txt\` is vendored for a second reason: x86jit's \`ss286::load_revocations\`
# reads it from the corpus directory, but its \`fetch.sh\` never downloads it — so today the
# revocation list is silently always empty and revoked tests are being trusted.
# The corpus TREE is pinned by ${SS286_COMMIT} in MANIFEST.md and fetched by the consumer,
# not here: 611 MB of test data is not a source anyone cites by section, and mirroring it
# would make this stash a data host rather than a ledger.
ss286/LICENSE                      ${RAW_SS286}/LICENSE                                          500
ss286/README.md                    ${RAW_SS286}/README.md                                      10000
ss286/CHANGELOG.md                 ${RAW_SS286}/CHANGELOG.md                                     200
ss286/revocation_list.txt          ${RAW_SS286}/revocation_list.txt                              100
EOF
}

# --- FETCH-ONLY: pinned by sha256, never committed (no redistribution licence) ---
fetchonly_files(){ cat <<EOF
# AMD ISA manuals — © AMD, no redistribution licence. Cite-only, kept local.
# Sea/Southern Islands = PS4 Liverpool (GCN2/GFX6). RDNA2 = PS5 Oberon (GFX10.3).
# amd.com/docs.amd.com block scripted fetch, hence the archive.org snapshots.
amd/ci-isa.pdf    https://web.archive.org/web/2id_/http://developer.amd.com/wordpress/media/2013/07/AMD_Sea_Islands_Instruction_Set_Architecture.pdf 500000
amd/si-isa.pdf    https://web.archive.org/web/2id_/http://developer.amd.com/wordpress/media/2012/12/AMD_Southern_Islands_Instruction_Set_Architecture.pdf 500000
# RDNA2 ISA ("RDNA 2" Instruction Set Architecture Reference Guide, Nov 2020, 291pp).
# docs.amd.com serves only an HTML viewer + the gpuopen download 404s; the wayback raw
# snapshot of the retired developer.amd.com PDF is the reachable clean copy.
amd/rdna2-isa.pdf https://web.archive.org/web/20230214072857id_/https://developer.amd.com/wp-content/resources/RDNA2_Shader_ISA_November2020.pdf 500000
# SPIR-V core specification. The Vulkan-Docs tree carries only the ENVIRONMENT appendix
# (\`spirvenv.adoc\`) and the memory model; the instruction definitions live in the SPIR-V
# specification, which Khronos publishes as one HTML document with no git ref behind it —
# so it is pinned BY SHA256 like the AMD PDFs. Two facts in the compute lowering come from
# nowhere else (TASK-299): \`OpAtomicIAdd\`'s "The instruction's result is the Original
# Value", which is what makes it the counterpart of GCN's \`DS_ADD_RTN_U32\`; and
# \`OpControlBarrier\`'s "when Execution is Workgroup or larger, behavior is undefined
# unless all invocations within Execution execute the same dynamic instance of this
# instruction", which is the rule the workgroup oracle's barrier scheduler enforces.
# NOT vendored: the Khronos specification licence grants "a conditional copyright license
# to use and reproduce the unmodified Specification", after a sentence that separately
# forbids republishing/distributing without written permission. The grant does not clearly
# reach redistribution, so this stays fetch-only. See NOTICE.md.
vulkan/spirv-core.html https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html 1000000

# ===== x86 (serves x86jit) ==================================================================

# --- x86 CPU manuals — © Intel / © AMD, no redistribution licence. Cite-only, kept local.
# The Intel SDM is the primary authority for the whole lifter: instruction semantics, flag
# effects, the x87 environment/tag-word images, exception behaviour. The pin is the
# REVISION-specific cdrdv2 asset, never Intel's moving "latest" endpoint — see SDM_ORDER /
# SDM_ASSET above for how to move it and why that matters for a citation.
# ${SDM_ORDER}, June 2026, 5363 pp.
intel/sdm.pdf     ${SDM_URL} 20000000
# AMD64 APM volumes 1-5 (publication ${APM_PUB}, rev 4.08, April 2024, 3347 pp) — the SECOND
# WITNESS where the SDM is silent or says "undefined", and the natural authority for the
# Jaguar-class target x86jit's main consumer emulates. This is the CPU manual; the GPU ISA
# manuals in \`amd/\` are a different processor entirely, hence the separate directory.
# www.amd.com blocks scripted fetch from here (http 000), hence the archive.org snapshot.
intel/amd64-apm.pdf ${APM_URL} 10000000
# Intel 80386 Programmer's Reference Manual (${I386PRM_ORDER}, 1986, 523 pp, a scan with an OCR
# text layer) — the SECOND WITNESS for 386-specific behaviour that the current SDM no longer
# describes as a 386 feature set: CR0 and EFLAGS masks, two-level paging permissions and
# reserved bits, reset state. x86jit's decision-18 requires it before any such fact is
# implemented. © Intel, no redistribution licence: cite-only, like the SDM.
intel/i386-prm.pdf ${I386PRM_URL} 20000000
# Intel 80286 and 80287 Programmer's Reference Manual (${I286PRM_ORDER}, 1987, 513 pp, a scan
# with an OCR text layer) — the source for 286-specific behaviour (MSW, LMSW-only protected-
# mode entry, 286 descriptor format) and the 80287 coprocessor that the current SDM does not
# describe. © Intel, no redistribution licence: cite-only, like the SDM.
intel/i286-prm.pdf ${I286PRM_URL} 20000000
# --- 8080 CPU manuals (x80) — © Intel, no redistribution licence. Cite-only, kept local.
# Intel 8080 Microcomputer Systems User's Manual (${I8080UM_ORDER}, September 1975, 262 pp, a
# scan with an OCR text layer) — x80's PRIMARY: the CPU chapter (interrupt, halt and start-up
# sequences, the per-instruction machine-cycle/state table), the instruction set with flag
# effects, and the 8080A data sheet.
intel/i8080-um.pdf ${I8080UM_URL} 20000000
# Intel 8080/8085 Assembly Language Programming Manual (${I8080ALPM_ORDER}, May 1981, 222 pp, a
# scan with an OCR text layer; the mirror files it as revision "9800301D") — x80's SECOND
# WITNESS: per-opcode cycles and states, interrupts, flag notes. 7.15 MB, hence the smaller
# minimum size.
intel/i8080-alpm.pdf ${I8080ALPM_URL} 5000000
# --- 8085 CPU sources (x80, M3) — © Intel, no redistribution licence. Cite-only, kept local.
# MCS-80/85 Family User's Manual (${I8085UM_ORDER}, January 1983, 210 pp, a scan with an OCR
# text layer) — x80's PRIMARY for the 8085A: functional description (interrupts TRAP and
# RST 5.5/6.5/7.5, RIM/SIM, SID/SOD, machine cycles, reset/halt/hold), the instruction set
# with 8085A and 8080A states side by side, and abridged data sheets.
intel/i8085-um.pdf ${I8085UM_URL} 5000000
# 1988 Intel Embedded Controller Handbook, Volume I, 8-bit (1024 pp) — pinned for ONE
# document inside it: the 8085AH/8085AH-2/8085AH-1 data sheet, order number 231718-001
# (September 1987), printed pp. 16-11 to 16-30 (PDF pages 958 to 977). Second source for the
# 8085 (pins, interrupt table, machine-cycle chart, instruction summary; no per-instruction states).
intel/intel-embedded-controller-handbook-1988-v1.pdf ${IECH1988_URL} 30000000
# --- 8080 CPU exercisers (x80 oracles) — GPL-2.0-or-later: Frank D. Cringle's Z80
# instruction exerciser and preliminary test (1994), modified for the 8080 by Ian Bartholomew
# (the exerciser in February 2009); Mike Douglas (May 2013) added to the exerciser the success
# CRCs shown on Bartholomew's website and the PASS display. FETCH-ONLY by the x80 maintainer's
# decision: run locally as falsifying oracles, never committed here. The .MAC files are the
# assembly sources of the .COM programs (CP/M, load address 0100h).
8080-exercisers/8080PRE.COM ${CPU8080_TESTS_URL}/8080PRE.COM 1000
8080-exercisers/8080PRE.MAC ${CPU8080_TESTS_URL}/8080PRE.MAC 4000
8080-exercisers/8080EXM.COM ${CPU8080_TESTS_URL}/8080EXM.COM 4000
8080-exercisers/8080EXM.MAC ${CPU8080_TESTS_URL}/8080EXM.MAC 20000
# The 8085 build of the same exerciser (x80, M3): modified for the 8085 by Ian Bartholomew
# (October 2009), flag mask D5h; success CRCs added in May 2020 per its header. GPL-2.0-or-later.
8080-exercisers/8085EXM.COM ${CPU8080_TESTS_URL}/8085EXM.COM 4000
8080-exercisers/8085EXM.MAC ${CPU8080_TESTS_URL}/8085EXM.MAC 20000
# The exerciser author's results page (a 2019 browser print of the web.archive.org snapshot
# 20151108135453 of his 8080/8085 CPU Exerciser page, 4 pp): the per-chip table of measured
# CRCs from which 8080EXM's expected values come, with contributor notes. No licence: cite-only.
8080-exercisers/8080-8085-cpu-exerciser-results.pdf ${CPU8080_TESTS_URL}/8080_8085%20CPU%20Exerciser.pdf 100000
# --- NEC V20/V30 manual (x86jit) — (c) NEC Electronics, no redistribution licence. Cite-only,
# kept local. uPD70108 (V20) and uPD70116 (V30) User's Manual (stock no. ${NECV20UM_STOCK},
# October 1986, 228 pp, a scan with an OCR text layer) — the PRIMARY source for the V20/V30
# models: the native and 8080 emulation modes (BRKEM, CALLN, RETEM, the MD flag), the
# V-series instruction-set extensions, interrupts and reset. 10.8 MB, hence the smaller
# minimum size.
nec/v20-v30-um.pdf ${NECV20UM_URL} 5000000

# --- System V ABI, AMD64 Architecture Processor Supplement ("the x86-64 psABI"), LaTeX
# sources @ ${PSABI_COMMIT}.
# NOT VENDORED, and the reason is stronger than the SPIR-V one: that repository carries no
# LICENSE and no COPYING file at all. The only licence statement in the whole tree is one
# line in \`abi.tex\`'s revision history scoping CC-BY-4.0 to *Intel's changes*, not to the
# document. For SPIR-V there is at least a document-wide grant that is merely ambiguous about
# redistribution; here there is no document-wide grant to be ambiguous about. Fetch-only.
# Pinned as SOURCE, not as the PDF: the README advertises a \`jobs/artifacts/master/raw\`
# PDF, which is a CI artifact of the latest master build — it moves on every merge and GitLab
# expires artifacts, so it cannot be pinned at all.
# These two files carry every ABI fact x86jit currently states bare: §3.3.1 hardware
# exception types (the exception->signal map), §3.4.1 initial stack and register state,
# §3.4.3 the auxiliary vector (\`x86jit-elf\`'s \`setup_stack\`), §3.2 the calling sequence,
# and A.2.1 the syscall calling convention (RDI/RSI/RDX/R10/R8/R9 — note R10, not RCX).
psabi/low-level-sys-info.tex ${RAW_PSABI}/low-level-sys-info.tex 50000
psabi/kernel.tex             ${RAW_PSABI}/kernel.tex              1000
EOF
}

table_rows(){ grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$'; }

# --- provenance quarantine (MANIFEST.md "Second-hand blocks in a clean source") ---
# One file in the OpenOrbis tree cites a PS4 EMULATOR project as the source of its own
# EVFILT_* block. The provenance rule governs what we CONSULT, not only what we commit, and
# the stash is exactly where an agent goes expecting a clean source — so the block is
# excised at fetch time rather than left to be read in good faith.
OO_KERNEL_H="openorbis/OpenOrbis-PS4-Toolchain/include/orbis/_types/kernel.h"
OO_TAINT_MARKER="red-prig/fpPS4"
QUARANTINE_MARK="unemups4-quarantine"

fetch_file(){ # url dest [min_bytes] — writes to a temp, keeps existing file on failure
  local url="$1" dest="$2" min="${3:-500}" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"
  local code; code=$(curl -sL -o "$tmp" -w '%{http_code}' --max-time 90 "$url" 2>/dev/null || echo 000)
  local sz; sz=$(stat -c%s "$tmp" 2>/dev/null || echo 0)
  if [ "$code" != "200" ] || [ "${sz:-0}" -lt "$min" ]; then
    rm -f "$tmp"
    warn "FAILED $dest (http=$code size=$sz) <- $url ${dest:+(kept existing if any)}"
    return 1
  fi
  mv "$tmp" "$dest"
  printf '   %-40s http=%s size=%s\n' "$dest" "$code" "$sz"
}

# A fetch-only source is pinned by sha256, so its bytes have to be REPRODUCIBLE. One is not:
# registry.khronos.org sits behind a CDN that injects a per-request challenge script
# (`window.__CF$cv$params`, a fresh request id + timestamp) into the SPIR-V spec HTML, so two
# downloads a second apart differ and the "pin" was uncheckable by anyone including us. The
# pin is therefore taken over the document with that injected line removed — nothing else is
# touched, and the removed line is CDN plumbing, not specification text.
#   $1 = logical path (selects the canonicalisation), $2 = file to hash (default $1)
pin_hash(){
  local logical="$1" f="${2:-$1}"
  case "$logical" in
    vulkan/spirv-core.html) grep -av '__CF\$cv\$params' "$f" | sha256sum | cut -d' ' -f1 ;;
    *)                      sha256sum "$f" | cut -d' ' -f1 ;;
  esac
}

quarantine_openorbis(){ # excise the emulator-sourced block; idempotent
  if [ ! -f "$OO_KERNEL_H" ]; then
    warn "quarantine: $OO_KERNEL_H absent (OpenOrbis clone not fetched?)"
    return 0
  fi
  if grep -q "$QUARANTINE_MARK" "$OO_KERNEL_H"; then
    printf '   %-40s already quarantined\n' "$OO_KERNEL_H"
    return 0
  fi
  if ! grep -q "$OO_TAINT_MARKER" "$OO_KERNEL_H"; then
    warn "quarantine: '$OO_TAINT_MARKER' NOT found in $OO_KERNEL_H — upstream moved or dropped"
    warn "  the block. Re-locate it before trusting this file; do not assume it is clean."
    return 1
  fi
  awk -v mark="$QUARANTINE_MARK" '
    $0 ~ /red-prig\/fpPS4/ {
      skip = 1
      print "// [" mark "] An EVFILT_* block stood here that cited a PS4 EMULATOR project as"
      print "// its own source. unemups4 is clean-room and its provenance rule governs what we"
      print "// CONSULT, so fetch-oracles.sh removes it — nothing here was ever derived from it."
      print "// Base kqueue filters (-1..-11) have a first-hand source: freebsd9/sys_sys_event.h."
      print "// The console-specific filters (-12..-22) have NO clean source; derive them from"
      print "// the dumped guest binary instead. Reasoning: oracles/MANIFEST.md."
      next
    }
    skip && /EVFILT_SYSCOUNT/ { skip = 0; next }
    !skip { print }
  ' "$OO_KERNEL_H" > "$OO_KERNEL_H.tmp"
  mv "$OO_KERNEL_H.tmp" "$OO_KERNEL_H"
  printf '   %-40s emulator-sourced EVFILT_* block excised\n' "$OO_KERNEL_H"
}

# ===========================================================================================
# Mesa: clone into gitignored scratch, then refresh the VENDORED tree from it.
# ===========================================================================================

mesa_clone_meta(){ # commit + trees only (blobless, no checkout) — enough for ls-tree
  if [ ! -d "$MESA_CLONE/.git" ]; then
    mkdir -p "$MESA_CLONE"
    git -C "$MESA_CLONE" init -q
    git -C "$MESA_CLONE" remote add origin "$MESA_URL"
  fi
  git -C "$MESA_CLONE" rev-parse -q --verify "${MESA_COMMIT}^{commit}" >/dev/null 2>&1 && return 0
  git -C "$MESA_CLONE" fetch -q --depth 1 --filter=blob:none origin "$MESA_COMMIT"
}

mesa_checkout(){ # materialise the sparse paths at the pinned commit
  mesa_clone_meta
  git -C "$MESA_CLONE" sparse-checkout set "${MESA_SPARSE[@]}"
  git -C "$MESA_CLONE" checkout -qf "$MESA_COMMIT"
}

vendor_mesa(){
  # A pre-vendoring stash had the clone AT mesa/mesa — a nested .git there would make git
  # treat the whole vendored tree as a gitlink. Migrate it out of the way.
  if [ -e "$MESA_VENDOR/.git" ]; then
    warn "legacy in-place clone at $MESA_VENDOR — removing it; the vendored tree is committed now"
    rm -rf "$MESA_VENDOR"
  fi
  # The sparse checkout is only a way to pull the blobs down in one round trip; the vendored
  # copies are written from the OBJECTS, not from the working tree. Mesa's .gitattributes
  # says `*.csv eol=crlf`, so a working-tree copy of those files is NOT what upstream stores
  # — and a vendored copy that differs from the blob is a modified redistribution that
  # `verify --upstream` would (correctly) flag forever. `git cat-file` bypasses all filters.
  mesa_checkout
  local p
  for p in "${MESA_SPARSE[@]}"; do rm -rf "${MESA_VENDOR:?}/$p"; done
  local oid path n=0
  while read -r _ _ oid path; do
    mkdir -p "$MESA_VENDOR/$(dirname "$path")"
    git -C "$MESA_CLONE" cat-file blob "$oid" > "$MESA_VENDOR/$path"
    n=$((n+1))
  done < <(git -C "$MESA_CLONE" ls-tree -r "$MESA_COMMIT" -- "${MESA_SPARSE[@]}" "${MESA_LICENSE_FILES[@]}")
  printf '   %-52s %s files (raw blobs, no filters)\n' "$MESA_VENDOR" "$n"
}

mesa_vendored_paths(){ find "$MESA_VENDOR" -type f 2>/dev/null | LC_ALL=C sort; }

# ===========================================================================================
# fetch
# ===========================================================================================

fetch_all(){
  local old_sums; old_sums="$(mktemp)"
  [ -f SHA256SUMS ] && cp SHA256SUMS "$old_sums" || true

  log "fetch-only sources (NOT redistributable — pinned by sha256, gitignored)"
  local dest url min
  while read -r dest url min; do
    fetch_file "$url" "$dest" "$min" || warn "grab $dest manually if the archive is down"
  done < <(fetchonly_files | table_rows)

  log "vendored sources — refreshing the committed copies from upstream"
  while read -r dest url min; do
    fetch_file "$url" "$dest" "$min" || true
  done < <(vendored_files | table_rows)

  log "Mesa src/amd + radeonsi @ ${MESA_COMMIT:0:10} (vendored into $MESA_VENDOR)"
  vendor_mesa

  # --- OpenOrbis SDK (headers + OELF/SELF spec + make-fself) — FETCH-ONLY.
  # 169 MB for a handful of headers, and the quarantine below rewrites one of its files;
  # a vendored copy would be a modified redistribution. Pinned by commit instead.
  log "OpenOrbis toolchain @ ${OPENORBIS_COMMIT:0:10} (fetch-only)"
  if [ ! -d openorbis/OpenOrbis-PS4-Toolchain/.git ]; then
    git clone --filter=blob:none "$OPENORBIS_URL" openorbis/OpenOrbis-PS4-Toolchain
  fi
  git -C openorbis/OpenOrbis-PS4-Toolchain fetch --depth 1 origin "$OPENORBIS_COMMIT" 2>/dev/null \
    || git -C openorbis/OpenOrbis-PS4-Toolchain fetch origin
  # -f: the quarantine below leaves one file modified, so a plain checkout would refuse to
  # move the pin. Discard it and re-apply — the quarantine is the reproducible step.
  git -C openorbis/OpenOrbis-PS4-Toolchain checkout -qf "$OPENORBIS_COMMIT"
  quarantine_openorbis || warn "OpenOrbis quarantine did not apply — see MANIFEST.md"

  # --- llvm-mc (witness tool; record version) ---
  log "llvm-mc witness"
  if command -v llvm-mc >/dev/null; then
    llvm-mc --version | sed -n 's/.*LLVM version \(.*\)/llvm-mc \1/p' > llvm-mc.version
    printf '   llvm-mc: %s\n' "$(cat llvm-mc.version)"
  else
    warn "llvm-mc not installed — needed as GCN encoding witness (#6). Install LLVM."
  fi

  report_vendor_changes "$old_sums"
  rm -f "$old_sums"
  write_sums
  gen_notice > NOTICE.md
  log "NOTICE.md regenerated"
  log "Done. Stash rebuilt; SHA256SUMS + NOTICE.md refreshed."
  log "A vendored copy that changed shows up in 'git diff' — review it before committing."
}

report_vendor_changes(){ # $1 = pre-fetch SHA256SUMS copy
  local old="$1" n=0 line h p cur
  [ -s "$old" ] || return 0
  while read -r h p; do
    [ -f "$p" ] || continue
    cur=$(sha256sum "$p" | cut -d' ' -f1)
    if [ "$cur" != "$h" ]; then
      printf '   \033[1;33mCHANGED\033[0m %s\n' "$p"
      n=$((n+1))
    fi
  done < <(grep -v '^#' "$old")
  if [ "$n" -gt 0 ]; then
    warn "$n vendored file(s) changed against the previously recorded sums — UPSTREAM MOVED"
    warn "  or the pin was moved deliberately. 'git diff' is the record; review before commit."
  fi
}

# ===========================================================================================
# sums
# ===========================================================================================

vendored_paths(){ { vendored_files | table_rows | awk '{print $1}'; mesa_vendored_paths; } | LC_ALL=C sort -u; }

write_sums(){
  log "Writing SHA256SUMS (vendored, committed copies) + SHA256SUMS.fetched (pins only)"
  local p missing=0 paths
  paths="$(vendored_paths)"
  while read -r p; do
    [ -f "$p" ] || { warn "vendored file MISSING, not recorded: $p"; missing=1; }
  done <<< "$paths"
  # shellcheck disable=SC2046
  ( while read -r p; do [ -f "$p" ] && sha256sum "$p"; done <<< "$paths" ) > SHA256SUMS
  {
    echo "# pinned refs (the trees these copies were taken from):"
    echo "#   mesa            $MESA_COMMIT"
    echo "#   kernel          $KERNEL_REF"
    echo "#   freebsd         $FREEBSD_REF"
    echo "#   vulkan-docs     $VULKAN_DOCS_REF"
    echo "# fetch-only, pinned by sha256 in SHA256SUMS.fetched:"
    echo "#   openorbis       $OPENORBIS_COMMIT"
  } >> SHA256SUMS
  printf '   %-24s %s entries\n' SHA256SUMS "$(grep -vc '^#' SHA256SUMS)"

  # Fetch-only pins: MERGE, never drop. A PDF that was not fetched on this machine must not
  # silently lose its recorded hash — the pin is the only thing a reader can check it against.
  declare -A PIN=()
  if [ -f SHA256SUMS.fetched ]; then
    while read -r h p; do [ -n "${p:-}" ] && PIN["$p"]="$h"; done < <(grep -v '^#' SHA256SUMS.fetched || true)
  fi
  while read -r p _ _; do
    [ -f "$p" ] && PIN["$p"]="$(pin_hash "$p")"
  done < <(fetchonly_files | table_rows)
  {
    echo "# Sources that may NOT be redistributed (© AMD ISA PDFs; the Khronos SPIR-V spec)."
    echo "# They are gitignored — these hashes ARE the pin: fetch them and check yourself."
    echo "# vulkan/spirv-core.html is hashed with the CDN-injected challenge script line"
    echo "# ('__CF\$cv\$params') removed: registry.khronos.org rewrites it on every request,"
    echo "# so the raw bytes are not reproducible. See pin_hash() in fetch-oracles.sh."
    for p in $(printf '%s\n' "${!PIN[@]}" | LC_ALL=C sort); do
      printf '%s  %s\n' "${PIN[$p]}" "$p"
    done
  } > SHA256SUMS.fetched
  printf '   %-24s %s entries\n' SHA256SUMS.fetched "$(grep -vc '^#' SHA256SUMS.fetched || true)"
  [ "$missing" -eq 0 ] || warn "some vendored files were missing — run 'fetch' before committing sums"
}

# ===========================================================================================
# verify — offline by default; --upstream re-downloads and diffs
# ===========================================================================================

verify_quarantine(){ # non-fatal when the stash is absent; LOUD when the taint is present
  if [ ! -f "$OO_KERNEL_H" ]; then
    printf '   %-40s absent (fetch-only source not fetched)\n' "$OO_KERNEL_H"
    return 0
  fi
  if grep -q "$OO_TAINT_MARKER" "$OO_KERNEL_H"; then
    err "PROVENANCE: emulator-sourced block is PRESENT in $OO_KERNEL_H"
    warn "  run './fetch-oracles.sh quarantine' before consulting the OpenOrbis tree"
    return 1
  fi
  if grep -q "$QUARANTINE_MARK" "$OO_KERNEL_H"; then
    printf '   %-40s quarantine in place\n' "$OO_KERNEL_H"
  else
    warn "quarantine marker missing in $OO_KERNEL_H (upstream changed?) — re-check by hand"
    return 1
  fi
}

verify_offline(){ # -> 0 ok, 1 local drift.  NO NETWORK.
  local rc=0
  [ -f SHA256SUMS ] || { err "no SHA256SUMS — run 'fetch' first"; return 1; }
  log "vendored copies vs recorded sha256 (offline)"
  local n; n=$(grep -vc '^#' SHA256SUMS || true)
  if grep -v '^#' SHA256SUMS | sha256sum -c --quiet -; then
    printf '   %s vendored files OK\n' "$n"
  else
    err "LOCAL DRIFT: a committed copy does not match its recorded sha256 (see above)"
    rc=1
  fi
  # An UNRECORDED file inside a vendored tree is drift too — that is what the allow-list
  # in .gitignore plus this check are for: nothing arrives in the stash unaccounted for.
  local extra
  extra=$(comm -23 <(mesa_vendored_paths) <(grep -v '^#' SHA256SUMS | awk '{print $2}' | grep "^$MESA_VENDOR/" | LC_ALL=C sort) || true)
  if [ -n "$extra" ]; then
    err "LOCAL DRIFT: file(s) present under $MESA_VENDOR but not recorded in SHA256SUMS:"
    printf '     %s\n' $extra
    rc=1
  fi
  log "NOTICE.md is generated — checking it is current"
  if [ -f NOTICE.md ] && diff -q <(gen_notice) NOTICE.md >/dev/null; then
    printf '   NOTICE.md up to date\n'
  else
    err "NOTICE.md is stale or missing — run './fetch-oracles.sh notice'"
    rc=1
  fi
  log "fetch-only sources (not committed; checked only if present locally)"
  local h p cur
  while read -r h p; do
    if [ ! -f "$p" ]; then
      printf '   %-24s not fetched (pin: %s…)\n' "$p" "${h:0:12}"
      continue
    fi
    cur=$(pin_hash "$p")
    if [ "$cur" = "$h" ]; then printf '   %-24s matches its pin\n' "$p"
    else err "LOCAL DRIFT: $p does not match its recorded pin"; rc=1; fi
  done < <(grep -v '^#' SHA256SUMS.fetched 2>/dev/null || true)
  log "git-pinned tree (fetch-only): openorbis"
  printf '   openorbis %s (want %s)\n' \
    "$(git -C openorbis/OpenOrbis-PS4-Toolchain rev-parse HEAD 2>/dev/null || echo NOT-FETCHED)" "$OPENORBIS_COMMIT"
  log "provenance quarantine:"
  verify_quarantine || rc=1
  return $rc
}

verify_upstream(){ # -> 0 ok, 3 upstream moved, 4 unreachable.  Assumes offline pass ran.
  local moved=0 unreachable=0 tmpd
  tmpd="$(mktemp -d)"
  declare -A REC=()
  while read -r h p; do REC["$p"]="$h"; done < <(grep -v '^#' SHA256SUMS)

  log "re-downloading the curl-pinned sources at their pinned refs and diffing"
  local dest url min up loc n_ok=0
  while read -r dest url min; do
    loc="${REC[$dest]:-}"
    if [ -z "$loc" ]; then err "not recorded in SHA256SUMS: $dest"; continue; fi
    if ! curl -sfL -o "$tmpd/blob" --max-time 90 "$url" 2>/dev/null; then
      warn "UNREACHABLE $dest <- $url"; unreachable=$((unreachable+1)); continue
    fi
    up=$(sha256sum "$tmpd/blob" | cut -d' ' -f1)
    if [ "$up" = "$loc" ]; then n_ok=$((n_ok+1))
    else
      err "UPSTREAM MOVED  $dest"
      printf '     recorded/committed %s\n     upstream today    %s\n     %s\n' "$loc" "$up" "$url"
      moved=$((moved+1))
    fi
  done < <(vendored_files | table_rows)
  printf '   %s curl-pinned files identical to upstream\n' "$n_ok"

  log "diffing the vendored Mesa tree against $MESA_URL @ ${MESA_COMMIT:0:10}"
  if ! mesa_clone_meta 2>/dev/null; then
    warn "UNREACHABLE mesa ($MESA_URL) — vendored tree not checked against upstream"
    unreachable=$((unreachable+1))
  else
    # git object ids, not sha256: the pinned tree already names every blob, so this needs
    # the TREES only (blobless clone) — no blob download, and it detects missing/extra files.
    declare -A UPOID=()
    local mode type oid path rel
    while read -r mode type oid path; do UPOID["$path"]="$oid"; done < <(
      git -C "$MESA_CLONE" ls-tree -r "$MESA_COMMIT" -- "${MESA_SPARSE[@]}" "${MESA_LICENSE_FILES[@]}")
    local files; files="$(mesa_vendored_paths)"
    if [ -z "$files" ]; then
      err "no vendored Mesa tree at $MESA_VENDOR — run 'fetch'"
      moved=$((moved+1)); files=""
    fi
    local locoids; locoids="$(git hash-object --no-filters --stdin-paths <<< "$files")"
    local i=0 mismatched=0 nmesa=0
    local -a farr loarr
    mapfile -t farr <<< "$files"
    mapfile -t loarr <<< "$locoids"
    for i in "${!farr[@]}"; do
      rel="${farr[$i]#"$MESA_VENDOR"/}"
      nmesa=$((nmesa+1))
      if [ -z "${UPOID[$rel]:-}" ]; then
        err "UPSTREAM MOVED  $MESA_VENDOR/$rel — no such path at the pinned commit"
        mismatched=$((mismatched+1)); continue
      fi
      if [ "${UPOID[$rel]}" != "${loarr[$i]}" ]; then
        err "UPSTREAM MOVED  $MESA_VENDOR/$rel (blob ${loarr[$i]:0:12} vs upstream ${UPOID[$rel]:0:12})"
        mismatched=$((mismatched+1))
      fi
      unset "UPOID[$rel]"
    done
    if [ "${#UPOID[@]}" -gt 0 ]; then
      err "INCOMPLETE VENDOR: ${#UPOID[@]} file(s) exist upstream under the vendored paths but"
      err "  are not committed here — run 'fetch' (they will be added):"
      printf '     %s\n' $(printf '%s\n' "${!UPOID[@]}" | LC_ALL=C sort | head -20)
      mismatched=$((mismatched+1))
    fi
    if [ "$mismatched" -eq 0 ]; then printf '   %s vendored Mesa files identical to upstream\n' "$nmesa"
    else moved=$((moved+mismatched)); fi
  fi

  log "fetch-only pins vs upstream (only what is present locally)"
  while read -r dest url min; do
    [ -f "$dest" ] || { printf '   %-24s not fetched — pin unchecked\n' "$dest"; continue; }
    if ! curl -sfL -o "$tmpd/blob" --max-time 300 "$url" 2>/dev/null; then
      warn "UNREACHABLE $dest <- $url"; unreachable=$((unreachable+1)); continue
    fi
    up=$(pin_hash "$dest" "$tmpd/blob")
    loc=$(pin_hash "$dest")
    if [ "$up" = "$loc" ]; then printf '   %-24s identical to upstream\n' "$dest"
    else
      err "UPSTREAM MOVED  $dest"
      printf '     local %s\n     upstream %s\n' "$loc" "$up"
      moved=$((moved+1))
    fi
  done < <(fetchonly_files | table_rows)

  rm -rf "$tmpd"
  if [ "$moved" -gt 0 ]; then
    err "$moved source(s) MOVED upstream. The committed copies still match their recorded"
    err "  sums — this repo did not drift; the SOURCE no longer says what it said. That is a"
    err "  finding: re-read the citations that rest on it before moving the pin."
    return 3
  fi
  [ "$unreachable" -gt 0 ] && { warn "$unreachable source(s) unreachable — check INCOMPLETE"; return 4; }
  return 0
}

verify(){
  local upstream=0
  case "${1:-}" in
    --upstream) upstream=1 ;;
    "") ;;
    *) echo "usage: $0 verify [--upstream]"; exit 2 ;;
  esac
  local rc=0
  verify_offline || rc=1
  if [ "$upstream" -eq 1 ]; then
    if [ "$rc" -ne 0 ]; then
      err "LOCAL DRIFT found — fix that first; an upstream diff on drifted copies means nothing"
      return 1
    fi
    verify_upstream || return $?
  fi
  [ "$rc" -eq 0 ] && log "OK"
  return $rc
}

# ===========================================================================================
# NOTICE.md — GENERATED from the tables above so it cannot drift from what is vendored.
# ===========================================================================================

gen_notice(){
  cat <<'HEAD'
# NOTICE — third-party sources vendored in this repository

**Generated by `./fetch-oracles.sh notice` — do not edit by hand.** `./fetch-oracles.sh
verify` fails if this file is stale, so it cannot drift from what is actually committed.

This repository vendors (commits) copies of third-party sources so that a citation stays
checkable when an upstream ref is deleted, a project moves, or a URL rots. Every vendored
file is unmodified and is listed below with its licence, its upstream URL and the ref it was
taken at.

**Two licences are in play, and they do not overlap.** The files written *for* this
repository — `fetch-oracles.sh`, `MANIFEST.md`, `README.md`, this file and `.gitignore` — are
MIT, © 2026 Mikołaj Mikołajczyk (`LICENSE`). **That licence does not extend to any vendored
source.** Every third-party file keeps the licence it arrived under, listed below; its
copyright headers are preserved verbatim and must stay that way. Copying a vendored file out
of this repository means complying with *its* licence, not with `LICENSE`.

**No modifications.** The vendored copies are byte-identical to upstream at the pinned ref;
`./fetch-oracles.sh verify --upstream` re-downloads and proves it. (The one place this stash
*does* modify a source — the OpenOrbis provenance quarantine — applies to a **fetch-only**
source that is never redistributed from here. See `MANIFEST.md`.)

**When a pin moves:** edit the ref at the top of `fetch-oracles.sh`, run
`./fetch-oracles.sh fetch`, and commit the refreshed copies together with the regenerated
`SHA256SUMS` and this file. The refs quoted below come from the same variables the fetcher
uses, so this file follows the pin automatically.

HEAD

  printf '## Vendored sources\n\n'
  printf '| Source | Upstream | Pinned ref | Licence |\n|---|---|---|---|\n'
  printf '| Linux kernel — AMD `radeon`/`amdgpu` register + PM4 headers (`amd/kernel-*`) | https://github.com/torvalds/linux | `%s` | MIT (per-file: "Permission is hereby granted, free of charge…", © Advanced Micro Devices, Inc. 2010–2019). The kernel as a whole is GPL-2.0; these particular files carry AMD'"'"'s MIT notice, which is preserved verbatim in each copy. |\n' "$KERNEL_REF"
  printf '| FreeBSD 9.0 — syscall/errno/ELF/mman/kqueue sources (`freebsd9/`) | https://github.com/freebsd/freebsd-src | `%s` | BSD-2-Clause / BSD-3-Clause, © The Regents of the University of California and others; licence text vendored as `freebsd9/COPYRIGHT`, per-file notices preserved. |\n' "$FREEBSD_REF"
  printf '| Vulkan specification — chapters, appendices and the registry (`vulkan/*.adoc`, `vulkan/vk.xml`) | https://github.com/KhronosGroup/Vulkan-Docs | `%s` | The `.adoc` files: **CC-BY-4.0**, © 2015-2025 The Khronos Group Inc. (SPDX header in each file). `vk.xml`: **Apache-2.0 OR MIT**, same copyright. Licence text vendored as `vulkan/LICENSE.adoc`; full CC-BY-4.0 at https://creativecommons.org/licenses/by/4.0/. Unmodified. |\n' "$VULKAN_DOCS_REF"
  printf '| Mesa — `src/amd` (common, registers, addrlib, llvm, compiler) and `src/gallium/drivers/radeonsi` (`mesa/mesa/`) | %s | `%s` | **MIT**, © Advanced Micro Devices, Inc., Red Hat, VMware, Valve and other Mesa contributors (SPDX header in each file). Licence text vendored as `mesa/mesa/licenses/MIT` and `mesa/mesa/docs/license.rst`. |\n' "$MESA_URL" "$MESA_COMMIT"
  printf '| Linux kernel — x86 syscall tables and process/signal uapi headers (`linux-x86/`) | https://github.com/torvalds/linux | `%s` | **GPL-2.0 WITH Linux-syscall-note** (SPDX header in each file). Licence text vendored as `linux-x86/COPYING` and `linux-x86/LICENSES_exceptions_Linux-syscall-note`. See the GPL-2.0 note below. |\n' "$KERNEL_X86_REF"
  printf '| MOO — the SingleStepTests container format: spec + reference parser (`moo/`) | https://github.com/dbalsom/moo | `%s` | **MIT**, © Daniel Balsom. Licence text vendored as `moo/LICENSE`. |\n' "$MOO_COMMIT"
  printf '| SingleStepTests 80286 — documentation and revocation list only, **not** the corpus (`ss286/`) | https://github.com/SingleStepTests/80286 | `%s` | **MIT**, © Daniel Balsom. Licence text vendored as `ss286/LICENSE`. The 611 MB corpus itself is fetched by the consumer at this same pin, not mirrored here. |\n\n' "$SS286_COMMIT"

  cat <<'MIT'
### MIT licence text (Mesa, and the AMD kernel headers)

> Permission is hereby granted, free of charge, to any person obtaining a copy of this
> software and associated documentation files (the "Software"), to deal in the Software
> without restriction, including without limitation the rights to use, copy, modify, merge,
> publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
> to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or
> substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
> INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
> PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
> FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
> OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
> DEALINGS IN THE SOFTWARE.

The per-file copyright notices in the vendored files are the authoritative ones; the text
above is reproduced so the notice travels with this repository even for the data files
(`src/amd/registers/*.json`) that carry no header of their own.

### Attribution (CC-BY-4.0, Vulkan specification)

The Vulkan specification chapters and appendices in `vulkan/` are © 2015-2025 The Khronos
Group Inc., licensed CC-BY-4.0, obtained from the Vulkan-Docs repository at the tag recorded
above, and are reproduced here **unmodified**. This repository is not endorsed by, and its
contents are not approved or reviewed by, The Khronos Group.

MIT

  cat <<'GPL2'

### GPL-2.0 WITH Linux-syscall-note (the `linux-x86/` tables and uapi headers)

These are the first copyleft-licensed sources vendored here, so the reasoning is worth
stating rather than assuming. GPL-2.0 **permits verbatim redistribution** — §1, "You may
copy and distribute verbatim copies of the Program's source code as you receive it" —
provided the copyright notice and the licence travel with the copy. They do: each file keeps
its `SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note` header, and both licence texts
are vendored beside them as `linux-x86/COPYING` and
`linux-x86/LICENSES_exceptions_Linux-syscall-note`.

The syscall-note exception is what makes these safe to *consult* from a permissively-licensed
project at all. In the kernel's own words: "this exception does not invalidate any other
reasons why the code file might be covered by the GNU General Public License", but user-space
code that merely uses the kernel's syscall interface is "not considered a derived work" of
the kernel.

**Nothing else in this repository is affected.** Every vendored file keeps the licence it
arrived under; there is no combined work here, only a stash of separately-licensed documents
sitting in adjacent directories. Copying a file out means complying with *that file's*
licence.
GPL2

  printf '## NOT vendored — fetch-only, pinned by sha256 in `SHA256SUMS.fetched`\n\n'
  cat <<'FETCHONLY'
These are downloaded by `./fetch-oracles.sh fetch` into a gitignored working copy. Their
hashes are committed, so a citation is still checkable — you fetch the source yourself and
compare. They are not redistributed from here:

| Source | Why not vendored |
|---|---|
| AMD ISA manuals — `amd/ci-isa.pdf` (Sea Islands), `amd/si-isa.pdf` (Southern Islands), `amd/rdna2-isa.pdf` (RDNA 2) | © AMD, published with **no redistribution licence**. Cite-only. Non-negotiable: these must never be committed. |
| SPIR-V core specification — `vulkan/spirv-core.html` | Khronos specification copyright. It grants "a conditional copyright license to use and reproduce the unmodified Specification", immediately after a sentence that separately forbids the copy being "reproduced, republished, distributed, transmitted, displayed, broadcast or otherwise exploited" without written permission. The grant does not clearly extend to redistribution, so the safe reading is fetch-only. (Its pin is taken over the document with the CDN-injected challenge-script line removed — `registry.khronos.org` rewrites that line on every request, so the raw bytes are not reproducible and a raw sha256 pin could never be checked.) |
| OpenOrbis PS4 Toolchain — `openorbis/` | GPL-3.0, so redistribution would be *legal*. It is fetch-only for two other reasons: the clone is ~169 MB for a handful of headers plus the OELF/SELF spec, and the provenance quarantine (`MANIFEST.md`) **rewrites** one of its headers — a vendored copy would be a modified redistribution, which is exactly the thing this stash exists to avoid. Pinned by commit. |
| Intel SDM — `intel/sdm.pdf` (combined volumes 1, 2A-D, 3A-D, 4) | © Intel Corporation, published with **no redistribution licence**. Cite-only, same class as the AMD ISA manuals. Pinned by order number *and* sha256, because Intel's download endpoint always serves the newest revision. |
| AMD64 APM — `intel/amd64-apm.pdf` (volumes 1-5) | © Advanced Micro Devices, Inc., **no redistribution licence**. Cite-only. This is the x86-64 CPU manual, distinct from the GPU ISA manuals in `amd/`. |
| x86-64 psABI — `psabi/*.tex` | The upstream repository (gitlab.com/x86-psABIs/x86-64-ABI) carries **no `LICENSE` and no `COPYING` file at all**. The only licence statement in its tree is one line in `abi.tex`'s revision history scoping CC-BY-4.0 to *Intel's changes*, not to the document. That is weaker than the SPIR-V case above: there, a document-wide grant exists and is merely ambiguous about redistribution; here there is no document-wide grant to be ambiguous about. Fetch-only, pinned by commit, taken as LaTeX source — the PDF upstream advertises is a CI artifact of the latest master build and expires, so it cannot be pinned. |
FETCHONLY
}

# ===========================================================================================

case "${1:-fetch}" in
  fetch)      fetch_all ;;
  verify)     shift; verify "${1:-}" ;;
  sums)       write_sums ;;
  notice)     gen_notice > NOTICE.md; log "NOTICE.md regenerated" ;;
  quarantine) quarantine_openorbis ;;
  *) echo "usage: $0 [fetch|verify [--upstream]|sums|notice|quarantine]"; exit 2 ;;
esac
