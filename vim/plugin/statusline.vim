vim9script

import "lines9.vim"
import "lines9/color.vim"
import "lines9/utils.vim"
import "lines9/components.vim"

final conf = lines9.GetPreset("default")

var cached_val = {}
def UpdateChangedCache(_, pat: string)
    final bvar = b:
    for [name, Update] in cached_val->items()
        if bvar->has_key("cache_" .. name) && b:changedtick > bvar["cache_" .. name][0]
            bvar["cache_" .. name] = [b:changedtick, Update()]
        endif
    endfor
enddef

const wide_threshold = 80

# {{{ Listeners and dispatcher
var leaving = false
def LeavingRefresh(..._)
    leaving = true
    lines9.Refresh({ scope: "window" })
enddef

conf.autocmds += ["FileType", "TextChanged", "InsertLeave", "WinScrolled", ["User", "CocNvimInit"]]
conf.listeners->extend({
    "autocmd:WinLeave": { 0: [LeavingRefresh] },
    "autocmd:FileType": {
        0: [(..._) => lines9.Refresh({ scope: "window" })],
        1: [(..._) => lines9.Update({ type: "statusline" })],
    },
    "autocmd:User:CocNvimInit": {
        0: [(..._) => lines9.Refresh({ scope: "window" })],
        1: [(..._) => lines9.Update({ type: "statusline" })]
    },
    "autocmd:TextChanged": { 2: [UpdateChangedCache] },
    "autocmd:InsertLeave": { 2: [UpdateChangedCache] },
    "autocmd:WinScrolled": {
        0: [(_, winstr) => {
            const win = str2nr(winstr)
            const iswide = winwidth(win) >= wide_threshold
            if win->getwinvar("lines9_prev_iswide", null) != iswide
                setwinvar(win, "lines9_prev_iswide", iswide)
                lines9.Update({ type: "statusline" })
                lines9.Refresh({ scope: "window" })
            endif
        }]
    },
})

def DispatchWin(loc: any): string
    if loc.type == "tabline"
        return "tabline"
    else
        const prefix = (leaving || win_getid() != loc.winid) ? "inactive" : "active"
        const ft = getwinvar(loc.winid, "&ft")
        var ftspec = (ft == "nerdtree" || ft == "coc-explorer") ? "_tree" : ""
        if ftspec == "" && winwidth(loc.winid) < wide_threshold
            ftspec = "_narrow"
        endif
        leaving = false
        return prefix .. ftspec
    endif
enddef
conf.dispatch = DispatchWin
# }}} End listeners and dispatcher

# {{{ Wordcount
const wordcounted_filetypes = ["markdown", "mail", "text", "typst"]
var loaded_wordcount = false
if has("perl")
    cached_val.wordcount = () => $" {perleval("WordCount")} "
    def LoadWordCount()
        perl <<EOF
        sub WordCount {
            my $ctnt = join ' ', $curbuf->Get(1..$curbuf->Count());
            utf8::decode($ctnt);
            my $hanzi = 0 + $ctnt =~ s/\p{Han}/ i /g;
            my $count = () = $ctnt =~ /\b\w[\w'.]*\b/g;
            my $res = "$count WD";
            if ($hanzi != 0) {
                $res = $res . ", $hanzi HZ";
            }
            return $res;
        }
EOF
    enddef
elseif has("python3")
    cached_val.wordcount = () => py3eval("WordCount()")
    def LoadWordCount()
        python3 <<EOF
import re
hanzi_re = re.compile(u"[\u4e00-\u9fff]")
words_re = re.compile(r"\b\w[\w'.]*\b")
def WordCount():
    ctnt = "\n".join(vim.current.buffer[:])
    ctnt, hanzi_cnt = hanzi_re.subn(' i ', ctnt)
    tot_cnt = len(words_re.findall(ctnt))
    return f" {tot_cnt} WD, {hanzi_cnt} HZ "
EOF
    enddef
else
    cached_val.wordcount = () => ""
    def LoadWordCount()
    enddef
endif
def WordCount(win: number): string
    const buf = winbufnr(win)
    if index(wordcounted_filetypes, buf->getbufvar("&ft")) == -1 || buf->getbufvar("wordcount_disabled", false)
        return ""
    else
        if !loaded_wordcount
            loaded_wordcount = true
            LoadWordCount()
        endif
        setbufvar(buf, "cache_wordcount", [0, call(cached_val.wordcount, [])])
        return color.Highlight("StatusLine") .. "%{b:cache_wordcount[1]}"
    endif
enddef
conf.components.wordcount = utils.MakeComponent(WordCount)
# }}} End wordcount

# {{{ Space status
def UpdateSpace(): string
    var trailing = search('\s\+$', 'ncw')
    if trailing != 0
        return " Trailing: " .. trailing .. " "
    endif
    var mixing = search('^ \+', 'ncw') != 0 ? search('^\s*\t', 'ncw') : 0
    if mixing != 0
        return " Mixed indent: " .. mixing .. " "
    endif
    return ""
enddef
cached_val.spacestatus = UpdateSpace
conf.components.spacestatus = utils.MakeComponent((win) => {
    final bvar = winbufnr(win)->getbufvar("")
    if bvar->get("spacecheck_disabled", false) || bvar->get("&bt", "") == "terminal"
        return ""
    else
        bvar.cache_spacestatus = [0, ""]
        return color.Highlight("ErrorMsg") .. "%{get(b:, 'cache_spacestatus', [0, ''])[1]}"
    endif
})
# }}} End space status

conf.components.cocstatus = utils.MakeComponent((win) => {
    if exists(":CocInfo") == 2
        return color.Highlight("CursorLine") .. " %{coc#status()}"
    else
        return ""
    endif
})

conf.components.trunc = components.Trunc
conf.components.fname_short = color.HlComponent(components.FileName({ full: false }), "StatusLineNC")

conf.schemes.inactive_tree = ["fname_inactive", "sep", "index_inactive"]
conf.schemes.active_tree = ["fname", "sep", "index"]
conf.schemes.active = ["mode", "paste", "spell", "fname", "modified", "cocstatus",
            \ "sep", "fileinfo", "spacestatus", "wordcount", "percentage", "index"]
conf.schemes.active_narrow = ["mode", "fname_short", "modified", "trunc", "sep", "percentage", "index"]
conf.schemes.inactive_narrow = conf.schemes.inactive

lines9.Init(conf)
lines9.Enable()

