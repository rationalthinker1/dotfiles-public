Plug 'scrooloose/nerdtree' " Shows file manager
" nerdtree - open when vim opesn
"          - switch to opened window
"          - close if last remaining window
"          - minimal UI
"          - show hidden files
"          - single click to open dir, double to open file
autocmd VimEnter * NERDTree
autocmd VimEnter * wincmd p
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
let NERDTreeMinimalUI=1
let NERDTreeShowHidden=1
let NERDTreeMouseMode=2
let NERDTreeIgnore=['.DS_Store', '.git', 'node_modules', '\.sublime-project', '\.sublime-workspace']
