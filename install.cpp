#if 0 /* keep the file recognizable by treesitter
dotpath=$(readlink -f $(dirname $0))
cd $dotpath
[ ! -z "$DEBUG" ] && \
        flags='-Wall -Wextra -Weffc++ -Wpedantic -O0 -DDEBUG -ggdb -fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer -lrt -fno-sanitize-recover -fstack-protector -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC -std=c++23 -o .install -DDOTPATH="\"'$dotpath'\"" -DHOMEPATH="\"'$HOME'\"" -lstdc++exp' \
        || flags='-std=c++23 -o .install -DDOTPATH="\"'$dotpath'\"" -DHOMEPATH="\"'$HOME'\"" -lstdc++exp'
CXXFLAGS="$flags" make -sf <(echo -e '.install:install.cpp; $(CXX) $< $(CXXFLAGS)') .install || exit $?
exec ./.install $@
# */
#endif
// {{{ Premable
#include <cstdio>
#include <cassert>
#include <fstream>
#include <cstdlib>
#include <string>
#include <string_view>
#include <filesystem>
#include <concepts>
#include <list>
#include <algorithm>
#include <numeric>
#include <unordered_map>
#include <functional>
#include <version>
#if __cpp_lib_stacktrace >= 202011L
#  include <stacktrace>
#endif  // __cpp_lib_stacktrace
using std::string;
using std::to_string;
using std::string_literals::operator""s;
namespace fs = std::filesystem;
// }}} End premable



// {{{ Environment & options
struct {
    string dotpath {}, homepath {}, datapath {};
    const bool iswin =
#ifdef _WIN32
        true
#else
        false
#endif
        ;  // Resume the Vim indent ><
    bool has_x11 = false;
    bool has_wl = false;
    const char *helpmsg = R"(Usage: %o <options> <configs>
A dotfile installation helper. If no option is specified, default to -i,
if no config is specified either, default is -l.
A special config 'available' stands for all config available on the system;
and 'everything' stands for all config

  -h, --help    print the message and quit
  -i, --install install given configurations
  -l, --list    list information of given configurations, grouped by their state.
                if not given, list all configurations
  -r, --reached list installed configurations
  -u, --pending list configurations not yet installed
)";
} env;
// }}} End environment & options



// {{{1 General helpers
struct Logger
{
    enum Level : unsigned {
        Error,
        InternalError,
        Warn,
        Output,  // Required output
        Progress,  // The main progress of a process
        Info,  // Information that may be useful
        Hint,  // Small hints
        ProgressDetail,  // The detailed progress of a process
        LV_MAX_,
    };
    unsigned curlv = ProgressDetail, depth = 0;
    inline static const char *LevelMsg[] = {
        "[ERROR] ",
        "[INTERNAL ERROR] ",
        "[Warn] ",
        "",  // Required output shouldn't be logged
        ":: ",
        "[Info] ",
        "[Hint] ",
        "-> ",
    };
    static_assert(sizeof(LevelMsg) / sizeof(*LevelMsg) == Level::LV_MAX_,
                  "There should be exactly one message for each of the log levels");

    void log(Level lv, const char *fmt, const auto &...args);
    auto withstage(Level lv, const char *fmt, const auto &...args)
    {
        log(lv, fmt, args...);
        return [this] (auto f) { ++depth; f(); --depth; };
    }
} logger;

// {{{ fn format
string to_string(string s) { return s; }
string to_string(char c) { return string(1, c); }
string format(std::string_view pat, auto ...args)
{
    // Stringfy the args
    std::vector<string> argstr { to_string(args)... };
    // Iterate and replace format patterns
    auto argit = argstr.begin();
    string res;
    auto prev = 0uz, pos = pat.find('%');
    for (res += pat.substr(prev, pos - prev); pos != pat.npos;
         prev = pos + 1, pos = pat.find('%', pos), res += pat.substr(prev, pos - prev))
        if (++pos < pat.size())
            switch (pat[pos])
            {
            case 'D':
                res += env.dotpath;
                break;
            case 'H':
                res += env.homepath;
                break;
            case 'o':
                if (argit == argstr.end())
                {
                    logger.log(logger.InternalError, "Too few arguments for format");
                    exit(3);
                }
                res += *argit++;
                break;
            case '%':
                res += '%';
                break;
            default:
                logger.log(logger.InternalError, "Unrecognized pattern '%o'", pat[pos]);
                exit(3);
            }
        else
        {
            logger.log(logger.InternalError, "Trailing %% in pattern string");
            exit(3);
        }
    if (argit != argstr.end())
    {
        logger.log(logger.InternalError, "Too much arguments for format");
        exit(3);
    }
    return res;
}
// }}} End fn format

void Logger::log(Level lv, const char *fmt, const auto &...args)
{
    if (lv > curlv)
        return;
    auto target = lv == Error || lv == InternalError ? stderr : stdout;
    string msg = ::format(fmt, args...);
    fprintf(target, "%s%s%s\n", string(depth * 2, ' ').c_str(), LevelMsg[lv], msg.c_str());
#if __cpp_lib_stacktrace >= 202011L
    if (lv == Error || lv == InternalError)
        fprintf(stderr, "Trace: %s\n", std::to_string(std::stacktrace::current()).c_str());
#endif  // __cpp_lib_stacktrace
}
// }}}1 End general helpers



// {{{1 Config helpers
template<class T>
concept ConfigInstaller = requires(const T a) {
    { a.is_installed() } -> std::convertible_to<bool>;
} && requires(T a) {
    a.install();
} && std::move_constructible<T> && std::destructible<T>;

// {{{ Config info and box

// `Box<dyn ConfigInstaller>`, use fat pointer to implement polymorphism
struct InstallerBox
{
private:
    struct VTable_t
    {
        void (*install)(void*);
        bool (*is_installed)(const void *);
        void (*destructor)(void*);
    };
    template<ConfigInstaller T>
    inline static const VTable_t VTable_v {
        [] (void *p) { static_cast<T*>(p)->install(); },
        [] (const void *p) { return static_cast<const T*>(p)->is_installed(); },
        [] (void *p) { static_cast<T*>(p)->~T(); },
    };
    const VTable_t *vt;
    void *data;

public:
    // Explicitly exclude self to make clang happy
    template<class T> requires (!std::same_as<InstallerBox, T>) && ConfigInstaller<T>
    InstallerBox(T inst) : vt(&VTable_v<T>), data(std::aligned_alloc(alignof(T), sizeof(T)))
    {
        new(data) T(std::move(inst));
    }
    ~InstallerBox()
    {
        if (data)
        {
            vt->destructor(data);
            std::free(data);
        }
    }
    InstallerBox(const InstallerBox &) = delete;
    InstallerBox &operator=(const InstallerBox &) = delete;
    InstallerBox(InstallerBox &&o) : vt(o.vt), data(o.data) { o.data = nullptr; }
    InstallerBox &operator=(InstallerBox &&o)
    {
        assert(this != &o && "There shouldn't be self-assigning");
        this->~InstallerBox();
        new(this) InstallerBox(std::move(o));
        return *this;
    }
    void install() { vt->install(data); }
    bool is_installed() const { return vt->is_installed(data); }
};

struct ConfigInfo
{
public:
    inline static const char *OSName[] = { "", "UNIX", "Win", "All" };
    enum OSCatalog {
        UNIX = 0x1, Win, AllOS,
    };

    const char *name;
    OSCatalog os;
    const char *description;
    std::function<InstallerBox()> gen;

public:
    template<class F, ConfigInstaller T = std::invoke_result_t<F>>
    ConfigInfo(const char *n, OSCatalog o, const char *desc, F &&instgen)
        : name(n), os(o), description(desc), gen([instgen = std::move(instgen)] { return instgen(); })
    {
    }
    ConfigInfo(const ConfigInfo &) = delete;
    ConfigInfo &operator=(const ConfigInfo &) = delete;
    ConfigInfo(ConfigInfo &&o) = default;
    ConfigInfo &operator=(ConfigInfo &&o) = default;
    ~ConfigInfo() = default;
};

template<ConfigInstaller T, ConfigInstaller U>
auto operator&(T a, U b)
{
    struct {
        T a; U b;
        void install() { a.install(); b.install(); }
        bool is_installed() const { return a.is_installed() && b.is_installed(); }
    } res{std::move(a), std::move(b)};
    return res;
}

std::vector<ConfigInfo> conf_list;
struct ConfigAdder
{
    ConfigAdder(ConfigInfo &&conf) { conf_list.push_back(std::move(conf)); }
};
#define add_conf_impl(ln) ConfigAdder add_conf_var_##ln = ConfigInfo
#define add_conf_2(ln) add_conf_impl(ln)
#define add_conf add_conf_2(__LINE__)
// }}} End config info and box

// {{{ BindFnConfig
class BindFnConfig
{
public:
    std::function<void()> install;
    std::function<bool()> is_installed;
};
// }}} End BindFnConfig

// {{{ InvokerConfig
class InvokerConfig
{
private:
    fs::path file;
    const string begline, endline;
    string commands;
    std::list<string> readfile() const
    {
        std::list<string> res;
        std::ifstream in(file);
        if (!in)
            return res;
        while (!in.eof())
        {
            res.push_back("");
            std::getline(in, res.back());
        }
        return res;
    }
public:
    InvokerConfig(fs::path f, string comment_prefix, string name, string cmd)
        : file(env.homepath / f),
          begline(comment_prefix + " {{{ Generated by dotfile installer: " + name),
          endline(comment_prefix + " }}} End dotfile installer generated: " + name),
          commands(cmd) { if (commands.back() != '\n') commands.push_back('\n'); }
    void install()
    {
        logger.log(logger.ProgressDetail, "[invoker %o] installing invoker", file);
        auto ctnt = readfile();
        auto insertion = begline + "\n" + commands + endline;
        auto beg = std::find(ctnt.begin(), ctnt.end(), begline);
        auto end = std::find(beg, ctnt.end(), endline);
        if (end == ctnt.end())
            ctnt.push_back(insertion);
        else
        {
            ctnt.insert(beg, insertion);
            ctnt.erase(beg, ++end);
        }
        if (!fs::exists(file.parent_path()))
            fs::create_directories(file.parent_path());
        std::ofstream out(file);
        // When there's eol at the end of file, do not include the empty line
        if (ctnt.back().empty())
            ctnt.pop_back();
        for (auto line : ctnt)
            out << line << "\n";
        out.close();
    }
    bool is_installed() const
    {
        auto ctnt = readfile();
        auto beg = std::find(ctnt.begin(), ctnt.end(), begline);
        auto end = std::find(beg, ctnt.end(), endline);
        if (end == ctnt.end())
        {
            logger.log(logger.Hint, "[invoker %o] not found invoking line", file);
            return false;
        }
        else if (std::accumulate(++beg, end, string(), [](auto a, auto b) { return a + b + "\n"; }) != commands)
        {
            logger.log(logger.Hint, "[invoker %o] invoke commands differ", file);
            return false;
        }
        else
            return true;
    }
};
// }}} End InvokerConfig

// {{{ SymlinkConfig
class SymlinkConfig
{
private:
    fs::path src, dst;
public:
    SymlinkConfig(fs::path s, fs::path d)
        : src(env.dotpath / s), dst(fs::path(d).is_absolute() ? d : env.homepath / d) {}
    void install()
    {
        auto link_file = [this] (fs::path src, fs::path dst) {
            if (fs::exists(dst))
            {
                if (fs::is_symlink(dst))
                {
                    logger.log(logger.ProgressDetail, "[symlink %o] removing target %o", this->src, dst);
                    fs::remove(dst);
                }
                else
                {
                    logger.log(logger.Warn, "[symlink %o] target %o is not a symlink, skipping", this->src, dst);
                    return;
                }
            }
            logger.log(logger.ProgressDetail, "[symlink %o] making symlink: %o -> %o", this->src, dst, src);
            fs::create_directories(dst.parent_path());
            fs::create_symlink(src, dst);
        };
        if (fs::is_directory(src))
            for (fs::recursive_directory_iterator it { src, fs::directory_options::follow_directory_symlink };
                    it != decltype(it)(); ++it)
            {
                if (!it->is_directory())
                    link_file(*it, dst / it->path().lexically_relative(src));
            }
        else
            link_file(src, dst);
    }
    bool is_installed() const
    {
        if (fs::is_directory(src))
        {
            for (fs::recursive_directory_iterator it { src, fs::directory_options::follow_directory_symlink };
                    it != decltype(it)(); ++it)
                if (auto target = dst / it->path().lexically_relative(src); !fs::exists(target))
                {
                    logger.log(logger.Hint, "[symlink: %o] target %o not exist", src, target);
                    return false;
                }
            return true;
        }
        else if (!fs::exists(dst))
        {
            logger.log(logger.Hint, "[symlink: %o] target %o not exist", src, dst);
            return false;
        }
        else
            return true;
    }
};
// }}} End SymlinkConfig

// {{{ X11Config and WlConfig
#define config_tmpl(cls, conf) \
    class cls \
    { \
    private: \
        std::vector<InstallerBox> sub; \
    public: \
        cls(ConfigInstaller auto ...xs) \
        { \
            sub.reserve(sizeof...(xs)); \
            (sub.emplace_back(std::move(xs)), ...); \
        } \
        cls(const cls &) = delete; \
        cls &operator=(const cls &) = delete; \
        cls(cls &&o) : sub(std::move(o.sub)) {} \
        cls &operator=(cls &&o) \
        { \
            assert(this != &o && "There shouldn't be self-assigning"); \
            this->~cls(); \
            new(this) cls(std::move(o)); \
            return *this; \
        } \
        void install() \
        { \
            if (!env.conf) \
                return; \
            for (auto &it : sub) \
                it.install(); \
        } \
        bool is_installed() const \
        { \
            return env.conf ? \
                std::all_of(sub.begin(), sub.end(), [] (const auto &it) { \
                    return it.is_installed(); \
                }) : \
                /* Always treat everything as installed when no corresponding env */ \
                true; \
        } \
    }
config_tmpl(X11Config, has_x11);
config_tmpl(WlConfig, has_wl);
#undef config_tmpl
// }}} End X11Config and WlConfig
// }}}1 End config helpers



// {{{ Main
int main(int, char **argv)
{
    // {{{ Process default parameters
    env.dotpath =
#ifndef DOTPATH
        fs::absolute(fs::path(argv[0]).parent_path());
#else
        DOTPATH;
#endif  // DOTPATH
    env.homepath =
#ifndef HOMEPATH
        std::getenv(env.iswin ? "USERPROFILE" : "HOME");
#else
        HOMEPATH;
#endif  // HOMEPATH
    env.datapath =
#ifndef DATAPATH
        env.iswin ? std::getenv("APPDATA") : [](auto n) {
            return n == nullptr ? (fs::path(std::getenv("HOME")) / ".local/share").string() : n;
        }(std::getenv("XDG_DATA_HOME"));
#else
        DATAPATH;
#endif  // DATAPATH
    env.has_x11 = env.iswin ? false : std::string("x11") == std::getenv("XDG_SESSION_TYPE");
    env.has_wl = env.iswin ? false : std::string("wayland") == std::getenv("XDG_SESSION_TYPE");
    // }}} End process default parameters

    fs::current_path(fs::path(argv[0]).remove_filename());

    std::unordered_map<string, size_t> config_id;
    for (auto id = 0uz; id != conf_list.size(); ++id)
        config_id[conf_list[id].name] = id;

    bool force = false;
    std::vector<bool> is_selected(conf_list.size(), false);
    size_t selected_size = 0;
    // {{{ Parse the arguments
    enum Action : int {
        Unset, List, Install, Help, ACTION_MAX,
    } action = Unset;
    std::vector<std::pair<string, Action>> longopts = {
        { "list", List },
        { "install", Install },
        { "help", Help },
    };
    std::unordered_map<char, Action> shortopts = {
        { 'l', List },
        { 'i', Install },
        { 'h', Help },
    };
    for (char **argp = argv; *++argp;)
    {
        string arg = *argp;
        if (arg.starts_with("--"))  // Long options
        {
            arg = arg.substr(2);
            if (arg == "force")
                force = true;
            else if (action != Unset)
                logger.log(logger.Error, "cannot specify multiple actions at the same time");
            else
            {
                for (auto it : longopts)
                    if (it.first.starts_with(arg))
                    {
                        action = it.second;
                        break;
                    }
                if (action == Unset)  // Specifying multiple actions is not considered
                    logger.log(logger.Error, "unrecognized option: %o", arg);
            }
        }
        else if (arg.starts_with("-"))  // Short options
        {
            for (auto &c : arg.substr(1))
                if (c == 'f')
                    force = true;
                else if (action != Unset)
                    logger.log(logger.Error, "cannot specify multiple actions at the same time");
                else if (auto it = shortopts.find(c); it != shortopts.end())
                    action = it->second;
                else
                    logger.log(logger.Error, "unrecognized option: %o", c);
        }
        else  // Ordinary config name
        {
            ++selected_size;
            if (auto it = config_id.find(arg); it == config_id.end())
                logger.log(logger.Error, "unknown config: %o", arg);
            else if (conf_list[it->second].os & (1 << env.iswin))
                is_selected[it->second] = true;
            else
                logger.log(logger.Hint, "not selecting %o, its target os is %o", arg,
                           ConfigInfo::OSName[conf_list[it->second].os]);
        }
    }
    // }}} End parsing the arguments

    // Process actions
    if (action == Help)
    {
        logger.log(logger.Output, env.helpmsg, argv[0]);
        return 0;
    }
    if (action == Unset)
        action = selected_size == 0 ? List : Install;

    // Deal with selections
    if (selected_size == 0)
        for (auto i = 0uz; i != is_selected.size(); ++i)
            if (conf_list[i].os & (1 << env.iswin))
                is_selected[i] = true;
    std::vector<std::pair<InstallerBox, size_t>> installers;
    installers.reserve(is_selected.size());
    for (auto id = 0uz; id != conf_list.size(); ++id)
        if (is_selected[id])
            installers.push_back({ conf_list[id].gen(), id });

    if (action == List)
    {
        if (force)
            logger.log(logger.Hint, "force is set but not effect in list operations");
        std::vector<size_t> colle[2];
        for (auto &&inst : installers)
            colle[inst.first.is_installed()].push_back(inst.second);
        auto print_conf = [&] (int &&which) {
            return [&] {
                for (auto id : colle[which])
                {
                    auto &conf = conf_list[id];
                    logger.log(logger.Output, "%o(%o): %o", conf.name, ConfigInfo::OSName[conf.os], conf.description);
                }
            };
        };
        logger.withstage(logger.Output, "Installed configs:")(print_conf(1));
        logger.withstage(logger.Output, "Not installed configs:")(print_conf(0));
    }
    if (action == Install)
        logger.withstage(logger.Progress, "Installing configs...")([&] {
            std::vector<size_t> done;
            for (auto &&inst : installers)
                if (force || !inst.first.is_installed())
                    logger.withstage(logger.Progress, "Installing %o",
                                     conf_list[inst.second].name)([&] { inst.first.install(); });
                else
                    done.push_back(inst.second);
            if (!done.empty())
            {
                string names;
                for (auto id : done)
                    names += conf_list[id].name + " "s;
                names.pop_back();
                logger.log(logger.ProgressDetail, "Already installed: %o", names);
            }
        });
}
// }}} End main



add_conf { "awesome", ConfigInfo::UNIX, "AwesomeWM config",
    [] { return X11Config {
        InvokerConfig { ".config/awesome/rc.lua", "--", "awesome",
            format(R"(local args = args or {}
args[1] = "%D"
loadfile("%D/awesome/rc.lua")(args))") }, }; }
};

add_conf { "hyprland", ConfigInfo::UNIX, "Hyprland config",
    [] { return WlConfig {
        InvokerConfig { ".config/hypr/hyprland.conf", "#", "hyprland", format(
                R"(source = %D/hypr/hyprland.conf)") },
        InvokerConfig { ".config/hypr/hypridle.conf", "#", "hypridle", format(
                R"(source = %D/hypr/hypridle.conf)"
                ) }, };
    },
};

add_conf { "emacs", ConfigInfo::AllOS, "Emacs config",
    [] { return InvokerConfig { ".emacs.d/init.el", ";;", "emacs conf",
        format("(load-file \"%D/emacs/init.el\")") } &
            SymlinkConfig { "emacs/custom.el", ".emacs.d/custom.el" }; },
};

add_conf { "firefox", ConfigInfo::AllOS, "Firefox css & chrome",
    [] { return SymlinkConfig { "firefox", ".mozilla/firefox/userprofile" }; },
};

add_conf { "fonts", ConfigInfo::UNIX, "Extra font config",
    [] { return SymlinkConfig { "fonts", ".config/fontconfig/" }; },
};

add_conf { "kitty", ConfigInfo::UNIX, "Kitty terminal config",
    [] { return InvokerConfig { ".config/kitty/kitty.conf", "#", "kitty",
        format("include %D/kitty/kitty.conf") }; },
};

add_conf { "mutt", ConfigInfo::UNIX, "Mutt config",
    [] { return InvokerConfig { ".mutt/muttrc", "#", "mutt",
        format("set my_muttrc_path = %D/mutt\nsource %D/mutt/muttrc") }; },
};

add_conf { "pandoc", ConfigInfo::AllOS, "Pandoc assets",
    [] {
        return SymlinkConfig { "pandoc", fs::path(env.datapath) / "pandoc" };
    },
};

add_conf { "profile", ConfigInfo::UNIX, "Default user profiles",
    [] {
        return InvokerConfig { ".profile", "#", "profile", format("source %D/profile/profile") } &
            X11Config {
                InvokerConfig { ".xprofile", "#", "profile", format("source %D/profile/xprofile") },
                InvokerConfig { ".Xresources", "!", "profile", format(
                        R"(#include "%D/profile/Xresources")""\n"
                        R"(#include "%D/profile/Solarizedxterm/.Xdefaults")") },
            } &
            InvokerConfig { ".ssh/config", "#", "ssh config", format("Include %D/profile/ssh_config") } &
            InvokerConfig { ".gdbinit", "#", "gdb config", format("source %D/profile/gdbinit") } &
            SymlinkConfig { "profile/rustfmt.toml", ".config/rustfmt/rustfmt.toml" } &
            SymlinkConfig { "profile/picom.conf", ".config/picom.conf" } &
            SymlinkConfig { "profile/clang-format.yaml", ".clang-format" } &
            SymlinkConfig { "profile/clangd.yaml", ".config/clangd/config.yaml" } &
            SymlinkConfig { "profile/zathurarc", ".config/zathura/zathurarc" } &
            SymlinkConfig { "profile/gitignore", ".config/git/ignore" };
    },
};

add_conf { "utils", ConfigInfo::AllOS, "Some utilities to make life better",
    [] { return SymlinkConfig { "utils", ".local/bin" }; },
};

add_conf { "vim", ConfigInfo::AllOS, "Vim config",
    [] {
        return InvokerConfig { env.iswin ? "_vimrc" : ".vimrc", "\"", "vimrc", format("source %D/vim/vimrc") } &
            SymlinkConfig { "vim/vimfiles", ".vim" };
    },
};

add_conf { "zsh", ConfigInfo::AllOS, "Z shell config",
    [] { return InvokerConfig { ".zshrc", "#", "zshrc", format("source %D/zsh/zshrc") }; },
};

add_conf { "system", ConfigInfo::AllOS, "System setup",
    [] {
        return BindFnConfig {
            .install = [] {
                system(format("%o %D/system/%o%o",
                            env.iswin ? "powershell" : "sh",
                            env.iswin ? "win.ps1" : "arch.sh",
                            "").c_str());
            },
            .is_installed = [] { return true; },
        };
    },
};



// vim: fdm=marker
