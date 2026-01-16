" {{{ Settings
set nocp  | " Vi is old
set display=truncate,uhex
set incsearch
set langnoremap
set nolangremap
set nrformats=bin,hex
set suffixes=.bak,~,.swp,.o,.info,.aux,.log,.dvi,.bbl,.blg,.brf,.cb,.ind,.idx,.ilg,.inx,.out,.toc,.png,.jpg
set ttimeout
set ttimeoutlen=100
" Command line completion
set wildmenu wildmode=lastused:longest:full,lastused:full
set wildoptions=fuzzy,pum
" Set encodings
set encoding=utf-8
set termencoding=utf-8
set fileencodings=ucs-bom,utf-8,default,latin1,cp936
" Set language of help document
set helplang=cn
" Highlight search result
set hlsearch
" Disables mouse in insert mode
set mouse=nvcr
" Open the syntax and corresponding highlight
syntax on
" Highlight corrent line
set cursorline
" Open the line number when is not pager
set number
" Show entered commands
set showcmd
" Set the width of indent and tab
set shiftwidth=4 tabstop=4 expandtab softtabstop=-1
" Let backspace more friendly
set bs=3
" Open code folding
set foldmethod=syntax
" .viminfo is not needed > <
set viminfofile=NONE
" Width for line breaking and vertical prompt line
set textwidth=120
set colorcolumn=+0
" Break more humanitily
set linebreak
" Use LF by default
set fileformat=unix
set fileformats=unix,dos
" Set the splitting behavior
set splitright noequalalways
set switchbuf=usetab,split,uselast
" Status line :)
set laststatus=2  | " Ensure that status line is shown
set noshowmode  | " The mode will be shown in status line
" Formatting ><
set formatoptions+=/j
" Search
if executable("rg")
    let &grepprg = "rg --vimgrep"
endif
" Better spliting
let &fillchars .= ",vert:\u2502,fold:\u2500"
" 'Solider' foldings
set foldopen=hor,mark,quickfix,search,tag,undo

" Color scheme
import "plgext.vim"
if s:plgext.Installed("start/everforest")
    colo everforest
    "colo solarized8_flat
else
    colo desert
endif
" }}} End settings

" {{{ Mappings
" Reset the leader
let mapleader=' '
" Fast fold code
map <leader><space> za
" Terminal normal, Use <Esc> (or its equivant) will cause E21 qwq
tnoremap <C-\> <C-W>N
" Clear search
nnoremap <silent><leader>/ <Cmd>let @/=''<CR>
" Make cursor move visually :)
noremap <silent> j gj
noremap <silent> k gk
noremap <silent> gj j
noremap <silent> gk k
" Emacs style motion in cmdline mode(q: may be better)
cnoremap <C-B> <Left>
cnoremap <C-F> <Right>
cnoremap <A-b> <C-Left>
cnoremap <A-f> <C-Right>
cnoremap <C-A> <Home>
cnoremap <C-E> <End>
set cedit=\<C-]>
" Run shell commands -- :! is considered not useful
nnoremap <leader>; :AsyncRun<space>
nnoremap <leader>: :term ++shell<space>
" Quick compile & Run
nnoremap <silent><leader>cc <Cmd>Compile<CR>
nnoremap <silent><leader>cr <Cmd>Run<CR>
" Expand snippets
xnoremap <silent><Tab> :call UltiSnips#SaveLastVisualSelection()<CR>gvs
snoremap <silent><expr><Tab> <Esc>:call UltiSnips#ExpandSnippet()<CR>
" Autoselect suggest in completion & expand snippets
inoremap <silent><expr><Tab> pumvisible() ? "<C-N>" : "<Tab>"
inoremap <silent><expr><S-Tab> pumvisible() ? "<C-P>" : "<Tab>"
" Confirm completion
inoremap <silent><expr><CR> pumvisible() ? "<C-Y>" : "<CR>"
autocmd User BeforeCocNvimInit {
    iunmap <Tab>
    iunmap <S-Tab>
    iunmap <CR>
    inoremap <silent><expr><Tab>
                \ UltiSnips#CanExpandSnippet() ? "<C-R>=UltiSnips#ExpandSnippet()<CR>" :
                \ pumvisible() ? "<C-N>" :
                \ coc#pum#visible() ? coc#pum#next(1) :
                \ UltiSnips#CanJumpForwards() ? "<C-R>=UltiSnips#JumpForwards()<CR>" : "<Tab>"
    inoremap <silent><expr><S-Tab>
                \ pumvisible() ? "<C-P>" :
                \ coc#pum#visible() ? coc#pum#prev(1) :
                \ UltiSnips#CanJumpBackwards() ? "<C-R>=UltiSnips#JumpBackwards()<CR>" : "<Tab>"
    inoremap <silent><expr><CR>
                \ pumvisible() ? "<C-Y>" :
                \ coc#pum#visible() ? coc#_select_confirm() :
                \ "<CR>"
}
" LSP actions
nmap \a <plug>(coc-codeaction-cursor)
nmap \w <plug>(coc-codeaction)
vmap \w <plug>(coc-codeaction-line)
vmap \a <plug>(coc-codeaction-selected)
nmap \f <plug>(coc-fix-current)
noremap \? <Cmd>CocDiagnostics<CR>
nnoremap \\ <Cmd>call CocAction('doHover')<CR>
nmap gd <Plug>(coc-definition)
nmap gr <Plug>(coc-references)
nmap \j <Plug>(coc-diagnostic-next)
nmap \k <Plug>(coc-diagnostic-prev)
nmap \r <Plug>(coc-refactor)
nmap \= <Plug>(coc-format)
vmap \= <Plug>(coc-format-selected)
nmap \u <Plug>(coc-references)
nmap \d <Plug>(coc-implementation)
" }}} End mappings

" {{{ GUI and System settings
" ======================================================================================================================
" Gui settings
" ======================================================================================================================
if has("gui_running")
    " Ban the annoying bell(cant be seen on Linux gui)
    set vb
    " No special options to workaround the bug infecting packager >_<
    set go=
    " Use a larger default size x_x
    set columns=135 lines=46
else  | " GUI ^^^ Term vvv
    set termguicolors
    set bg=dark
    "set term=xterm  | " Ignore the differences, just treat everything as xterm ><
endif

" ======================================================================================================================
" System settings
" ======================================================================================================================
if has("win32")  | " Windows
    set guifont=Consolas:h10
    set novb
    set shell=C:\\WINDOWS\\system32\\cmd.exe
else  | " Linux
    " Why not use zsh?
    set shell=/bin/zsh
    " Font
    " set guifont=Monaco
    set guifont=Iosevka\ Custom
endif
" }}} End GUI and system settings

" {{{ Package options
" ==================================================================================================================
" Language Server, UltiSnip, and DAP settings
" ==================================================================================================================
set completeopt=menuone,popup,noinsert,noselect
let g:UltiSnipsExpandTrigger = "<nop>"  | " The config will handle it ><
let g:coc_global_extensions = [ "coc-clangd", "coc-explorer", "coc-rust-analyzer", "coc-lua", "coc-json", ]
let g:vimspector_base_dir=expand("~")..'/.vim/vimspector'
let g:vimspector_enable_mappings = 'HUMAN'

" ==================================================================================================================
" Rainbow settings
" ==================================================================================================================
let g:rainbow_active = 1
let g:rainbow_conf = #{
            \     separately: #{
            \         c: #{ inherit: '', parentheses: [ "start=/{/ end=/}/ fold" ] },
            \         cpp: #{ inherit: 'c', parentheses: [] },
            \         sml: #{ parentheses: [ "start=/(*\@!/ end=/)/", "start=/\\[/ end=/]/", ] },
            \         typescript: #{ parentheses: [] },
            \     }
            \ }

" ==================================================================================================================
" VimOI settings
" ==================================================================================================================
if has('win32')
    let g:VimOI_CompileArgs = [ '/Od', '/nologo', '/utf-8', '/EHsc', '/W4', '/D_CRT_SECURE_NO_WARNINGS' ]
else
    let g:VimOI_CompileArgs = [ '-Wall', '-Wextra', '-DDEBUG' ]
endif

" ==================================================================================================================
" Vimtex, preview and markdown settings
" ==================================================================================================================
let g:tex_flavor = "latex"
let g:vimtex_enabled = 1
let g:vimtex_fold_enabled = 1
let g:vimtex_compiler_latexmk = {
            \     'options' : [
            \       '-xelatex',
            \     ],
            \ }
let g:livepreview_engine = 'xelatex'
if has("win32")
    let g:livepreview_previewer = 'start'
else
    let g:livepreview_previewer = 'zathura'
    set updatetime=400
endif
" Markdown options
let g:vim_markdown_math = 1
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_new_list_item_indent = 2
" Markdown preview
let g:mkdp_refresh_slow = 1
let g:mkdp_auto_close = 0
let g:mkdp_browser = 'firefox'

" ==================================================================================================================
" NERD Tree and Netrw settings
" ==================================================================================================================
let g:netrw_liststyle=3

" ==================================================================================================================
" Goyo settings
" ==================================================================================================================
let g:goyo_width = '80%'
let g:goyo_height = '95%'
let g:goyo_linenr = 1

" ==================================================================================================================
" Vimpager
" ==================================================================================================================
if has_key(g:, 'vimpager')
    set nonumber nocursorline
    let g:less = #{ enabled: 0 }
    " Go to last line when loaded
    autocmd BufReadPost * ++once normal L
endif
" }}} End package options

