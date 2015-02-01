# vim-github-comment

Want to comment commits on [GitHub] straight from [Vim]? You can now. After [installation](#installation), from inside vim, just run `:GHComment <your-comment-here>`. This will create a comment on the commit that changed that line last.

![vim-github-comment demo](/doc/vim-github-comment.gif "")

## Installation

I use [pathogen], but you can install [vim-github-comment] using your favorite way too. Short instructions to use with pathogen follow.

Inside your .vim directory, run:

    git clone git://github.com/mmozuras/vim-github-comment.git bundle/vim-github-comment

vim-github-comment requires [webapi], so if you don't have it in your bundle yet:

    git clone git://github.com/mattn/webapi-vim.git bundle/webapi

## Setup

If you don't have `github.user` set in your `.gitconfig`, add the following
into your ~/.vimrc

    let g:github_user = '<your-github-username-here>'

Optionally, browser can be opened with your comment after you post it:

    let g:github_comment_open_browser = 1

You can always run `help` to get more information about vim-github-comment:

    :help github-comment

[vim-github-comment]://github.com/mmozuras/vim-github-comment
[webapi]://github.com/mattn/webapi-vim
[pathogen]://github.com/tpope/vim-pathogen
[Vim]:http://www.vim.org
[GitHub]://github.com
