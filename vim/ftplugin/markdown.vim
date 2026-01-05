vim9script
import "ftext.vim"

var compile_flags: string
def RenewCompiler()
    if getline(1) == "---" && getline(2) =~ "^compile_flags:"
        compile_flags = getline(2)["compile_flags:"->len() : ]
    else
        compile_flags = "-s --embed-resources --mathml --template default.html -L assets.lua -L diagram.lua -o %:h/%:t:r.html "
    endif
enddef
RenewCompiler()
autocmd BufWrite <buffer> RenewCompiler()

ftext.CmdEngine.new("Compile", (...args) => {
    if !&ro
        w
    endif
    const all_flags = compile_flags .. (type(b:compile_flags) == v:t_string ?
        b:compile_flags : b:compile_flags->join(" "))
    exec $"AsyncRun pandoc % {all_flags} {args->join(" ")}"
}).Do()
ftext.CmdEngine.new("Run", (...args) => {
    exec "!" .. (has("win32") ? "start" : "xdg-open") .. " %:h/%:t:r.html " .. args->join(" ")
}).Do()

b:coc_suggest_disable = 1

augroup ft_markdown
    au!
    au FocusLost <buffer> if get(b:, "enable_autocompile", false) | exec "Compile" | endif
augroup END
b:enable_autocompile = false

command! -buffer -range TableFormat TableFormat(<line1>, <line2>)
def TableFormat(lbeg: number, lend: number)
    if getline(lbeg) =~ '\v^\+(\-|\=)*'
        exec $':{lbeg},{lend}Tabularize /+\|\\\@<!|'
        for lno in range(lbeg, lend + 1)
            const ln = getline(lno)
            if ln !~ '\v\+((\-|\=)*\+)*'
                continue
            endif
            setline(lno, ln->substitute(' ', ln =~ '-' ? '-' : '=', 'g'))
        endfor
    else
        echom "Unimpl"
    endif
enddef
