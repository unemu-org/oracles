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

RAW_KERNEL="https://raw.githubusercontent.com/torvalds/linux/${KERNEL_REF}"
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
  printf '| Mesa — `src/amd` (common, registers, addrlib, llvm, compiler) and `src/gallium/drivers/radeonsi` (`mesa/mesa/`) | %s | `%s` | **MIT**, © Advanced Micro Devices, Inc., Red Hat, VMware, Valve and other Mesa contributors (SPDX header in each file). Licence text vendored as `mesa/mesa/licenses/MIT` and `mesa/mesa/docs/license.rst`. |\n\n' "$MESA_URL" "$MESA_COMMIT"

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
