#include "utils.hh"

#include <iterator>
#include <memory>
#include <spdlog/logger.h>
#include <spdlog/pattern_formatter.h>
#include <spdlog/sinks/stdout_color_sinks.h>

namespace {

    class source_flag final : public spdlog::custom_flag_formatter {
    public:
        void format(const spdlog::details::log_msg& msg, const std::tm&, spdlog::memory_buf_t& dest) override {
            const spdlog::string_view_t level_name = spdlog::level::to_string_view(msg.level);
            const spdlog::string_view_t file = msg.source.filename ? spdlog::string_view_t{msg.source.filename} : spdlog::string_view_t{"?", 1};
            fmt::format_to(std::back_inserter(dest), "{}@{}:{}", level_name, file, msg.source.line);
        }

        std::unique_ptr<custom_flag_formatter> clone() const override {
            return spdlog::details::make_unique<source_flag>();
        }
    };

} // namespace

void logutil::init() noexcept {
    auto formatter = std::make_unique<spdlog::pattern_formatter>();
    formatter->add_flag<source_flag>('*').set_pattern("[%^%*%$] %v");

    auto logger = std::make_shared<spdlog::logger>("", std::make_shared<spdlog::sinks::stderr_color_sink_mt>());
    logger->set_formatter(std::move(formatter));
    logger->set_level(spdlog::level::debug);

    spdlog::set_default_logger(std::move(logger));
    spdlog::set_level(spdlog::level::debug);
}
