Plug 'ludovicchabant/vim-gutentags'
let g:gutentags_project_root = ['.git', '.svn', '.root', '.hg', '.project']
let g:gutentags_ctags_tagfile = '.tags'
let s:vim_tags = expand('~/.cache/tags')
let g:gutentags_cache_dir = s:vim_tags
let g:gutentags_ctags_extra_args = ['--fields=+niazS', '--extra=+q', '--c++-kinds=+px', '--c-kinds=+px']
let g:gutentags_trace = 1
let g:gutentags_file_list_command = {
            \  'markers': {
                \  '.git': 'git ls-files',
                 \  '.hg': 'hg files',
                 \  }
             \  }
