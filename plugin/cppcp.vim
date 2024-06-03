if exists("g:loaded_cppcp")
  finish
endif
let g:loaded_cppcp= 1

let s:plugindir = expand('<sfile>:p:h')

command! -nargs=0 DnSamples call cppcp#download()
command! -nargs=0 RunTest call cppcp#run_test()
command! -nargs=0 Make call cppcp#make()

function RegisterCmd()
  let cxx_flags = " -Wall -Wextra -pedantic -std=c++17 -g -O2 -Wshadow -Wformat=2 -Wfloat-equal -Wconversion -Wlogical-op -Wshift-overflow=2 -Wduplicated-cond -Wcast-qual -Wcast-align -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC -D_FORTIFY_SOURCE=2 -fno-sanitize-recover -fstack-protector"
  let command = [
        \"g++",
        \"-Wno-unused-parameter",
        \cxx_flags,
        \"-o",
        \expand("%:r"),
        \expand("%p"),
        \s:plugindir . "\\segfault.cpp"
        \]
  let &l:makeprg=join(command, " ")
  set errorformat=%A%f:%l:%c:\ %t%*[^:]:\ %m,%-G%.%#
  nnoremap <F8> :w <bar> !gcc -fpreprocessed -dD -E % \| sed "/^\# /d" \| clip<CR>
  "nnoremap <F4> :call cppcp#make<CR>
  "inoremap <F4> <ESC>:call cppcp#make<CR>
  nnoremap <F5> :call cppcp#run_test()<CR>
  inoremap <F5> <ESC>:call cppcp#run_test()<CR>

  let g:clang_format_path = s:plugindir . "/clang-format.exe"
  execute "map <F4> :pyf " . s:plugindir. "/clang-format.py<cr>"
  execute "imap <F4> <c-o>:pyf " . s:plugindir . "/clang-format.py<cr>"
endfunction

autocmd BufNewFile c:/data/codeforces/*.cpp 0r c:/data/codeforces/template.cpp | $d | call RegisterCmd()
autocmd BufRead c:/data/codeforces/*.cpp call RegisterCmd()

execute "autocmd BufNewFile c:/data/baekjoon/*.cpp 0r " . s:plugindir . "/template.cpp | $d | call cppcp#writedesc() | call RegisterCmd() | 15"
autocmd BufRead c:/data/baekjoon/*.cpp call RegisterCmd()
