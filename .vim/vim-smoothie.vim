Plug 'psliwka/vim-smoothie'               " Smooth scroll
let g:smoothie_no_default_mappings = 1
silent! nmap <unique> <PageDown> <Plug>(SmoothieForwards)
silent! nmap <unique> <PageUp>   <Plug>(SmoothieBackwards)
