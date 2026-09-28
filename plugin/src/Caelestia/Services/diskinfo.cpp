#include "diskinfo.hpp"

namespace caelestia::services {

namespace {

constexpr qreal kKib = 1024.0;

} // namespace

DiskInfo::DiskInfo(
    QString mount, quint64 usedBytes, quint64 availBytes, quint64 totalBytes, bool hasRoot, QObject* parent)
    : QObject(parent)
    , m_mount(std::move(mount))
    , m_usedBytes(usedBytes)
    , m_availBytes(availBytes)
    , m_totalBytes(totalBytes)
    , m_hasRoot(hasRoot) {}

QString DiskInfo::mount() const {
    return m_mount;
}

qreal DiskInfo::used() const {
    return static_cast<qreal>(m_usedBytes) / kKib;
}

qreal DiskInfo::total() const {
    return static_cast<qreal>(m_totalBytes) / kKib;
}

qreal DiskInfo::free() const {
    return static_cast<qreal>(m_availBytes) / kKib;
}

qreal DiskInfo::perc() const {
    // df's "Use%" ratio: the reserve is neither used nor allocatable, so it
    // stays out of the denominator. Deliberately NOT used / total — that
    // understates fullness by the reserve and disagrees with df.
    //
    // This returns the ratio; it is not df's printed integer. df ceils
    // (used*100 + avail - 1) / (used + avail), while the QML consumers here
    // render with Math.round, so the shell can read one point below df
    // (20% vs 21% on an ext4 root with a reserve). That is a rounding
    // convention difference, not a discrepancy in the underlying numbers.
    const quint64 denom = m_usedBytes + m_availBytes;
    return denom > 0 ? static_cast<qreal>(m_usedBytes) / static_cast<qreal>(denom) : 0.0;
}

bool DiskInfo::hasRoot() const {
    return m_hasRoot;
}

void DiskInfo::update(quint64 usedBytes, quint64 availBytes, quint64 totalBytes, bool hasRoot) {
    const bool usedDiff = usedBytes != m_usedBytes;
    const bool availDiff = availBytes != m_availBytes;
    const bool totalDiff = totalBytes != m_totalBytes;
    const bool rootDiff = hasRoot != m_hasRoot;

    m_usedBytes = usedBytes;
    m_availBytes = availBytes;
    m_totalBytes = totalBytes;
    m_hasRoot = hasRoot;

    if (usedDiff) {
        emit usedChanged();
    }
    if (availDiff) {
        emit freeChanged();
    }
    if (totalDiff) {
        emit totalChanged();
    }
    if (usedDiff || availDiff) {
        emit percChanged();
    }
    if (rootDiff) {
        emit hasRootChanged();
    }
}

} // namespace caelestia::services
