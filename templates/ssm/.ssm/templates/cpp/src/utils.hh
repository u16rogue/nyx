#pragma once

#include <spdlog/spdlog.h> // IWYU pragma: keep -- used by the log macros

namespace logutil {

    /// Initialize logger
    void init() noexcept;

} // namespace logutil

#define logdbg(_fmt, ...) SPDLOG_DEBUG(_fmt __VA_OPT__(,) __VA_ARGS__)
#define logerr(_fmt, ...) SPDLOG_ERROR(_fmt __VA_OPT__(,) __VA_ARGS__)
