set rtp+=.
set rtp+=../plenary.nvim
set noswapfile
runtime! plugin/plenary.vim

nnoremap ,,x lua require('plenary').reload_module('gcr', true) require('gcr').setup()<CR>
