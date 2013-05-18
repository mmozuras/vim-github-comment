" github-comment: Make GitHub comments straight from within Vim
" Author:         mmozuras
" HomePage:       https://github.com/mmozuras/vim-github-comment
" Readme:         https://github.com/mmozuras/vim-github-comment/blob/master/README.md
" Version:        0.0.1

function! s:CommitShaForCurrentLine()
  let linenumber=line('.')
  let path=expand('%:p')

  let cmd = 'git blame -L'.linenumber.','.linenumber.' --porcelain '.path
  let blame_text = system(cmd)

  return matchstr(blame_text, '\w\+')
endfunction
