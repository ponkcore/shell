# Storage: used vs available, and the ext4 root reserve

**Status: fixed in `8e2b9e1d`.** This document is the analysis behind the fix;
it is kept because the trap is easy to walk back into.

The shipped fix stores `availBytes` alongside `usedBytes` in `DiskInfo`,
computes `used = bytesTotal() - bytesFree()`, reports `free()` as the stored
available value rather than deriving it, and uses df's `used / (used + avail)`
ratio for both `DiskInfo::perc()` and `Storage::percentage()`. Note that `perc()`
returns the raw ratio while `df` ceils its integer, so the shell can read one
point below `df` (20% vs 21% here) — a rounding convention difference, not a
disagreement about the underlying bytes. Both are documented in the source.

One claim below was wrong and is corrected here: it warns that fixing `used`
regresses `free`, because `free` was "the one correct value in the chain".
`DiskInfo::free` had **no consumers at all** — no QML or C++ read it, and no
low-disk threshold exists in the tree. Nothing could regress. The separate
`availBytes` field is still the right shape (it makes `free` mean something and
stops the identity from being derived), but the urgency in "Knock-on effects"
does not apply.

---

## Original analysis

- **Repo:** `ponkcore/shell` (branch `main` @ `0e1ce334`)
- **Files:** `plugin/src/Caelestia/Services/storage.cpp` (primary),
  `plugin/src/Caelestia/Services/diskinfo.cpp` (derived values)
- **Severity:** cosmetic, but user-facing and always wrong on ext4 root
- **Verified on:** NixOS 26.05, ext4 root, Qt 6.11.1, Caelestia shell
  running as `caelestia.service`
- **No upstream behaviour depends on this** — it is a pure display bug

## Symptom

The shell's storage popout reports ~225 GiB used on a disk where
`df` reports 177 GiB and `du -shx /*` sums to ~177.6 GiB. The over-report
is a **constant 47.7 GiB**, which is exactly this filesystem's ext4
root reserve. It is not a stale reading and does not shrink with GC —
the offset is structural.

Observed during a real disk cleanup, where the discrepancy made it look
like a 50 GiB garbage collection had not applied:

```
$ df -BG /
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  937G  178G  713G  20% /

$ python3 -c 'import os; s=os.statvfs("/")'   # values below
bytesTotal     (f_blocks*bs) = 936.8 GiB
bytesFree      (f_bfree *bs) = 759.7 GiB
bytesAvailable (f_bavail*bs) = 712.0 GiB

used via bytesFree      = 177.1 GiB   <- matches df and du
used via bytesAvailable = 224.8 GiB   <- what the shell shows
difference              =  47.7 GiB   <- ext4 reserved for root (5%)
```

Reserve confirmed from the superblock:

```
$ sudo tune2fs -l /dev/nvme0n1p2 | grep -iE "^Reserved block count|^Block count"
Block count:              249788493
Reserved block count:     12489424
12489424 * 4096 = 47.64 GiB = 5.0% of 952.9 GiB, Reserved blocks uid: 0
```

## Root cause

`plugin/src/Caelestia/Services/storage.cpp:233-235`:

```cpp
const auto totalBytes = static_cast<quint64>(v.bytesTotal());
const auto availBytes = static_cast<quint64>(v.bytesAvailable());
const quint64 usedBytes = totalBytes > availBytes ? totalBytes - availBytes : 0;
```

`QStorageInfo::bytesAvailable()` maps to `statvfs.f_bavail`, which is the
space available to an **unprivileged** user and therefore *excludes* the
ext4 root reserve. Subtracting it from the total does not yield "bytes
occupied by files" — it yields "everything that is not usable by a normal
user", which silently folds in the reserve.

The correct source is `QStorageInfo::bytesFree()`, which maps to
`statvfs.f_bfree` and *includes* the reserve. This is precisely what
`df`'s "Used" column uses (`f_blocks - f_bfree`), which is why `df` and
the shell disagree.

Both methods are public in Qt 6.11.1
(`qtbase/include/QtCore/qstorageinfo.h:47-49`):

```cpp
qint64 bytesTotal() const;      // f_blocks * f_frsize
qint64 bytesFree() const;       // f_bfree  * f_frsize   <- use this for used
qint64 bytesAvailable() const;  // f_bavail * f_frsize   <- usable by non-root
```

## Fix

In `storage.cpp`, compute `usedBytes` from `bytesFree()`:

```cpp
const auto totalBytes = static_cast<quint64>(v.bytesTotal());
const auto freeBytes  = static_cast<quint64>(v.bytesFree());
const quint64 usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0;
```

`bytesFree()` is available on every `QStorageInfo` backend that provides
`bytesAvailable()` (both derive from the same `statvfs` call), so this is
safe for the ZFS and bind-mount paths already handled below in the same
function. Filesystems without a reserve (btrfs, tmpfs, vfat) return
`bytesFree() == bytesAvailable()`, so nothing changes there.

**This one line is necessary but not sufficient** — it fixes `used` and
silently breaks `free`, which is currently the one correct value in the
chain. Read "Knock-on effects" below before implementing.

## Knock-on effects — the one-line fix is NOT sufficient

`DiskInfo` stores only `m_usedBytes` and `m_totalBytes`, and derives both
`free` and `perc` from them (`diskinfo.cpp:22-37`):

```cpp
qreal DiskInfo::free() const {
    const quint64 freeBytes = m_totalBytes > m_usedBytes ? m_totalBytes - m_usedBytes : 0;
    return static_cast<qreal>(freeBytes) / kKib;
}

qreal DiskInfo::perc() const {
    return m_totalBytes > 0 ? static_cast<qreal>(m_usedBytes) / static_cast<qreal>(m_totalBytes) : 0.0;
}
```

That derivation is the structural problem: **one** stored number is used
to express two quantities that differ by the root reserve — "space
occupied by files" and "space a normal user can still allocate". Current
state, with the reserve = 47.7 GiB:

| Q_PROPERTY | formula | value today | correct? |
|---|---|---|---|
| `used` | `m_usedBytes` | 224.8 GiB | **wrong**, over by 47.7 (real: 177.1) |
| `free` | `total - m_usedBytes` | 712.0 GiB | **correct** — it happens to equal `bytesAvailable()` |
| `perc` | `m_usedBytes / m_totalBytes` | 24.0% | **wrong** (see below for what "correct" is) |

So `free` is accidentally right: `total - (total - avail) == avail`. It
reports exactly the space available to an unprivileged user, which is the
right thing to show a user.

**Warning:** applying the `bytesFree()` fix to `storage.cpp` alone will
*break* `free`. With `usedBytes = total - f_bfree`, the derived value
becomes `total - used == f_bfree` = 759.7 GiB, i.e. it would start
counting the 47.7 GiB root reserve as free space the user can use. That is
a regression in the one field that is currently correct, and it would make
any "low disk" threshold fire ~48 GiB too late.

### Required shape of the fix

Store the two quantities separately instead of deriving one from the other.
Add an explicit available-bytes field alongside `usedBytes` and pass
`bytesAvailable()` through it:

```cpp
// storage.cpp — gather all three
const auto totalBytes = static_cast<quint64>(v.bytesTotal());
const auto freeBytes  = static_cast<quint64>(v.bytesFree());
const auto availBytes = static_cast<quint64>(v.bytesAvailable());
const quint64 usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0;
// e.usedBytes = usedBytes; e.availBytes = availBytes;
```

```cpp
// diskinfo.cpp — free() reads the stored available value, no derivation
qreal DiskInfo::free() const {
    return static_cast<qreal>(m_availBytes) / kKib;
}
```

This keeps `used` = occupied by files, `free` = usable by a normal user,
and makes the identity `used + free == total` deliberately **not** hold on
filesystems with a reserve — which is correct, because the reserve is
neither used nor user-available. If any QML assumes that identity holds,
it needs to be found before merging:

```bash
grep -rn "\.perc\|\.free\b\|\.used\b" --include='*.qml' .
```

The `Accum`/`DeviceEntry` aggregation paths in `storage.cpp` (lines ~260,
273-274, 289, 292) sum and pass `usedBytes` across volumes; they must
carry the new field too, or multi-disk entries will keep deriving it.

### What `perc` should mean

Today `perc = 224.8 / 936.8 = 24.0%`. Two defensible targets, and they
differ:

- `used / total` = 177.1 / 936.8 = **18.9%**
- `used / (used + avail)` = 177.1 / 889.1 = **19.9%** — this is what
  `df`'s "Use%" column prints (verified: `df` shows 20%)

`df` deliberately excludes the reserve from the denominator, because the
reserve is not allocatable. Since users compare this popout against `df`,
**prefer the `df` formula**. Whichever is chosen, state it in a comment —
the current code has no comment and that is part of why the bug is easy to
reintroduce.

## Verification after the change

Must match `df` within rounding, on the same boot:

```bash
df -BG /                                   # expect Used = 178G
python3 -c 'import os;s=os.statvfs("/");bs=s.f_frsize;\
print(f"{(s.f_blocks-s.f_bfree)*bs/1024**3:.1f} GiB")'   # expect 177.1
```

Then compare against the shell's own IPC surface rather than eyeballing
the popout. Expected values on this host (root reserve 47.7 GiB):

| field | before | after (with the `df` perc formula) |
|---|---|---|
| `used` | 224.8 GiB | **177.1 GiB** |
| `free` | 712.0 GiB | **712.0 GiB** — must NOT change |
| `perc` | 0.240 | **0.199** (or 0.189 if `used/total` is chosen instead) |

`free` staying at 712.0 is the key assertion — it is the regression check
for the trap described above. If `free` moves to ~759.7, the fix was
applied to `storage.cpp` only and `DiskInfo::free()` is now deriving from
`usedBytes` again.

```bash
pgrep -af quickshell        # find the instance
# then via the shell's storage/disk IPC handler (see Storage service)
```

Regression guard: on a filesystem with **no** root reserve the numbers
must be unchanged. `/boot` (vfat, 1 GiB) is a cheap positive control —
verified on this host that `f_bfree == f_bavail` there exactly
(diff = 0.00 GiB), so `used` and `free` for that volume must be
byte-identical before and after the fix.

## Maintenance notes

- Do not fix this by subtracting a hardcoded 5%. The reserve is
  configurable (`tune2fs -m`) and differs per filesystem; it can also be
  zero. Read it from the API.
- The same `bytesAvailable()`-as-"free" mistake is a common pattern. If
  other services in the plugin report disk or memory figures, check them
  for the identical formula.
- This bug is invisible on tmpfs and btrfs, which is likely why it
  survived — it only shows up on an ext4 root with the default 5% reserve.
