" github-comment: Make GitHub comments straight from within Vim
" Author:         mmozuras
" HomePage:       https://github.com/mmozuras/vim-github-comment
" Readme:         https://github.com/mmozuras/vim-github-comment/blob/master/README.md
" Version:        0.0.4

let s:tokenfile = expand('~/.github-comment')

if !exists('g:github_user') && !executable('git')
  echohl ErrorMsg | echomsg "github-comment requires 'git'" | echohl None
  finish
endif

let s:system = function(get(g:, 'webapi#system_function', 'system'))

if !exists('g:github_user')
  let g:github_user = substitute(s:system('git config --get github.user'), "\n", '', '')
  if strlen(g:github_user) == 0
    let g:github_user = $GITHUB_USER
  end
endif

if strlen(g:github_user) == 0
  echohl ErrorMsg | echomsg "github-comment requires a github account. Set g:github_user or github.user in .gitconfig." | echohl None
  finish
endif

if !executable('curl')
  echohl ErrorMsg | echomsg "github-comment requires 'curl'" | echohl None
  finish
endif

" webapi uses autoload to define its functions, so they don't exist until they
" are called.
silent! call webapi#json#decode('{}')
if !exists('*webapi#json#decode')
  echohl ErrorMsg | echomsg "github-comment requires webapi (https://github.com/mattn/webapi-vim)" | echohl None
  finish
endif

com! -nargs=+ GHComment call GHComment(<q-args>)

function! GHComment(body)
  let auth = s:GetAuthHeader()
  if len(auth) == 0
    echohl ErrorMsg | echomsg "github-comment auth failed" | echohl None
    return
  endif

  let repo = s:GitHubRepository()
  let commit_sha = s:CommitShaForCurrentLine()
  let path = s:GetRelativePathOfBufferInRepository()
  let diff_position = s:GetDiffLineNumber(commit_sha, path)
  let comment = a:body
  let save_view = winsaveview()

  let response = s:CommentOnGitHub(auth, repo, commit_sha, path, diff_position, comment)

  if response.status == 201
    let body = webapi#json#decode(response.content)
    let html_url = body['html_url']
    if get(g:, 'github_comment_open_browser', 0) == 1
      call s:OpenBrowser(html_url)
    endif

    echomsg "Comment created: ".html_url
  else
    echohl ErrorMsg | echomsg "Could not create comment. You may not have the rights." | echohl None
  endif

  call winrestview(save_view)
endfunction

function! s:CommentOnGitHub(auth, repo, commit_sha, path, diff_position, comment)
  let request_uri = 'https://api.github.com/repos/'.a:repo.'/commits/'.a:commit_sha.'/comments'

  let response = webapi#http#post(request_uri, webapi#json#encode({
                  \  "sha" : a:commit_sha,
                  \  "path" : a:path,
                  \  "position" : a:diff_position,
                  \  "body" : a:comment
                  \}), {
                  \   "Authorization": a:auth,
                  \   "Content-Type": "application/json",
                  \})

  return response
endfunction

function! s:GitHubRepository()
  let cmd = 'git ls-remote --get-url'
  let remote = system(cmd)

  let name = split(remote, 'git://github\.com/')[0]
  let name = split(name, 'git@github\.com:')[0]
  let name = split(name, '\.git')[0]

  return name
endfunction

function! s:CommitShaForCurrentLine()
  let linenumber = line('.')
  let path = expand('%:p')

  let cmd = 'git blame HEAD -L'.linenumber.','.linenumber.' --porcelain '.path
  let blame_text = system(cmd)

  return matchstr(blame_text, '\w\+')
endfunction

function! s:GetDiffLineNumber(commit_sha, path)
  let line = getline('.')
  let cmd = 'git show --oneline '.a:commit_sha.' '.a:path.' | grep -nFx '.shellescape('+'.line)
  let diff_text = system(cmd)
  let split_line = split(diff_text, ':')
  return split_line[0] - 6
endfunction

function! s:GetAuthHeader()
  let token = ""
  if filereadable(s:tokenfile)
    let token = join(readfile(s:tokenfile), "")
  endif
  if len(token) > 0
    return token
  endif

  let password = inputsecret("GitHub password for ".g:github_user.": ")
  if len(password) > 0
    let authorization = s:Authorize(password)

    if has_key(authorization, 'token')
      let token = printf("token %s", authorization.token)
      execute s:WriteToken(token)
    elseif has_key(authorization, 'message')
      redraw
      echohl ErrorMsg | echomsg authorization.message | echohl None
    endif
  endif

  return token
endfunction

function! s:WriteToken(token)
  call writefile([a:token], s:tokenfile)
  call system("chmod go= ".s:tokenfile)
  echomsg printf(" -> wrote token to %s", s:tokenfile)
endfunction

function! s:Authorize(password)
  let auth = printf("basic %s", webapi#base64#b64encode(g:github_user.":".a:password))

  let auth_url = 'https://api.github.com/authorizations'
  let data = webapi#json#encode({ "scopes" : ["repo"], "note" : "vim-github-comment Authorization" })
  let header = { "Content-Type" : "application/json", "Authorization" : auth }

  let response = webapi#http#post(auth_url, data, header)

  let otp = filter(response.header, 'stridx(v:val, "X-GitHub-OTP:") == 0')
  if len(otp)
    let otp_token = inputsecret("GitHub authentication token: ")
    let header["X-GitHub-OTP"] = otp_token
    let response = webapi#http#post(auth_url, data, header)
  endif

  return webapi#json#decode(response.content)
endfunction

function! s:GetRelativePathOfBufferInRepository()
  let buffer_path = expand("%:p")
  let git_dir = s:GetGitTopDir()."/"

  return substitute(buffer_path, git_dir, "", "")
endfunction

function! s:GetGitTopDir()
  let buffer_path = expand("%:p")
  let buf = split(buffer_path, "/")

  while len(buf) > 0
    let path = "/".join(buf, "/")

    if empty(finddir(path."/.git"))
      call remove(buf, -1)
    else
      return path
    endif
  endwhile

  return ""
endfunction

function! s:OpenBrowser(url)
  if has('win32') || has('win64')
    let cmd = '!start rundll32 url.dll,FileProtocolHandler '.shellescape(a:url)
    silent! exec cmd
  elseif has('mac') || has('macunix') || has('gui_macvim')
    let cmd = 'open '.shellescape(a:url)
    call system(cmd)
  elseif executable('xdg-open')
    let cmd = 'xdg-open '.shellescape(a:url)
    call system(cmd)
  elseif executable('firefox')
    let cmd = 'firefox '.shellescape(a:url).' &'
    call system(cmd)
  else
    echohl WarningMsg | echomsg "That's weird. It seems that you don't have a web browser." | echohl None
  end
endfunction
