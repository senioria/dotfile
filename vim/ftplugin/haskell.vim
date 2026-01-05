vim9script
import "ftext.vim"

ftext.CmdEngine.new("Compile", "AsyncRun ghc -dynamic % {args}").Do()

ftext.CmdEngine.new("Run", (...args) => {
    ftext.TermRun(["ghci", expand("%")] + args, { persist: true, unique: false })
    doautocmd WinEnter !.
}).Do()

set autoindent ts=2 sw=2
