// Usage: incgen [-c] [-e <pattern> [-e ...]] <src dir> <dest dir>
// Copy or make reference for include directory

#include <iostream>
#include <regex>
#include <functional>
#include <filesystem>
#include <cstdio>

#include <stdimpl.h>

using namespace StdImpl;

namespace fs = std::filesystem;

static void processHeaders(const fs::path &src, const fs::path &dest,
                           const TStringList &ignorePatterns, bool copy) {
    // Remove target directory
    if (fs::exists(dest)) {
        std::filesystem::remove_all(dest);
    }

    fs::path privatePath = dest / "private";
    for (const auto &entry : fs::recursive_directory_iterator(src)) {
        if (entry.is_regular_file()) {
            const auto &path = entry.path();
            if (path.extension() == _TSTR(".h") || path.extension() == _TSTR(".hpp")) {
                // Check if should exclude
                bool skip = false;
                for (const auto &pattern : ignorePatterns) {
                    const TString &pathString = path;
                    if (std::regex_search(pathString.begin(), pathString.end(),
                                          std::basic_regex<TChar>(pattern))) {
                        skip = true;
                        break;
                    }
                }

                if (skip)
                    continue;

                const fs::path &targetDir = TString(path.stem())
                                                    .substr(path.stem().string().length() - 2, 2)
                                                    .ends_with(_TSTR("_p"))
                                                ? (privatePath)
                                                : (dest);

                // Create directory
                if (!fs::exists(targetDir)) {
                    fs::create_directories(targetDir);
                }

                auto targetPath = targetDir / path.filename();
                if (copy) {
                    // Copy
                    fs::copy(path, targetPath, fs::copy_options::overwrite_existing);
                } else {
                    // Make relative reference
                    auto rel = fs::relative(path, targetDir).string();
                    std::replace(rel.begin(), rel.end(), '\\', '/');

                    // Create file
                    auto f = _FOPEN(targetPath.c_str(), _TSTR("w"));
                    if (!f) {
                        continue;
                    }
                    fprintf(f, R"(#include "%s")", rel.data());
                    fclose(f);
                }

                // Set the timestamp
                fs::last_write_time(targetPath, fs::last_write_time(path));
            }
        }
    }
}

int main(int argc, char *argv[]) {
    (void) argc;
    (void) argv;

    // Parse arguments
    TStringList args = commandLineArguments();
    TStringList fileNames;
    TStringList excludes;
    bool copy = false;
    bool showHelp = false;

    for (int i = 1; i < args.size(); ++i) {
        if (!tstrcmp(args[i], _TSTR("--help")) || !tstrcmp(args[i], _TSTR("-h"))) {
            showHelp = true;
            break;
        }
        if (!tstrcmp(args[i], _TSTR("--exclude")) || !tstrcmp(args[i], _TSTR("-e"))) {
            if (i + 1 < args.size()) {
                excludes.emplace_back(args[i + 1]);
                i++;
            }
            continue;
        }
        if (!tstrcmp(args[i], _TSTR("--copy")) || !tstrcmp(args[i], _TSTR("-c"))) {
            copy = true;
            continue;
        }
        fileNames.push_back(args[i]);
    }

    if (fileNames.size() != 2 || showHelp) {
        tprintf(_TSTR("Usage: %s [options] <src dir> <dest dir>\n"), appName().data());
        tprintf(_TSTR("Options:\n"));
        tprintf(_TSTR("    %-20s    Exclude a file name pattern\n"), _TSTR("-e/--exclude <regex>"));
        tprintf(_TSTR("    %-20s    Copy files rather than indirect reference\n"),
                _TSTR("-c/--copy"));
        tprintf(_TSTR("    %-20s    Show help message\n"), _TSTR("-h/--help"));
        return 0;
    }

    const auto &src = fileNames.at(0);
    const auto &dest = fileNames.at(1);
    if (!fs::is_directory(src)) {
        tprintf(_TSTR("Error: \"%s\" is not a directory.\n"), src.data());
        return -1;
    }

    try {
        processHeaders(src, dest, excludes, copy);
    } catch (const std::exception &e) {
        std::cout << "Error: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}