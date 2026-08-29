" Have j and k navigate visual lines rather than logical ones
" nmap j gj
" nmap k gk
" I like using H and L for beginning/end of line
" nmap H ^
" nmap L $
" Quickly remove search highlights
nmap <F9> :nohl<CR>

" Yank to system clipboard
set clipboard=unnamed

" Go back and forward with Ctrl+O and Ctrl+I
" (make sure to remove default Obsidian shortcuts for these to work)
" exmap back obcommand app:go-back
" nmap <C-o> :back<CR>
" exmap forward obcommand app:go-forward
" nmap <C-i> :forward<CR>

" Also works
" nmap <C-w>h :obcommand<space>workspace:split-horizontal<CR>

" " Leader key
" unmap <Space>
nmap <Space>w :w<CR>
nmap <Space>q :q<CR>
nmap <Space>/ :obcommand editor:toggle-comment<CR>

" Surround
exmap surround_wiki surround [[ ]]
" exmap surround_double_quotes surround " "
" exmap surround_single_quotes surround ' '
" exmap surround_backticks surround ` `
" exmap surround_brackets surround ( )
" exmap surround_square_brackets surround [ ]
" exmap surround_curly_brackets surround { }

" NOTE: must use 'map' and not 'nmap'
map [[ :surround_wiki<CR>
" nunmap s
" vunmap s
" map s" :surround_double_quotes<CR>
" map s' :surround_single_quotes<CR>
" map s` :surround_backticks<CR>
" map sb :surround_brackets<CR>
" map s( :surround_brackets<CR>
" map s) :surround_brackets<CR>
" map s[ :surround_square_brackets<CR>
" map s] :surround_square_brackets<CR>
" map s{ :surround_curly_brackets<CR>
" map s} :surround_curly_brackets<CR>
