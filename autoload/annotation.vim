let s:ga = {'job_id': 0}

function! s:on_error(msg) abort
	echohl ErrorMsg | echom a:msg | echohl None
endfunction

function! s:on_close() abort
	if !has_key(s:ga, 'bufnr') | return | endif
	let winnr = win_id2win(s:ga.win_id)
	if winnr > 0 | noautocmd execute winnr . 'wincmd c' | endif
	unlet s:ga.bufnr s:ga.win_id
endfunction

function! s:reveal_diff(all, m) abort
	wincmd c
	let path = a:all ? '' : ' -- ' . fnameescape(s:ga.file) . ' | normal zr'
	execute a:m . ' G ' . (s:ga.committed ? 'show ' . s:ga.hash : 'diff') . path
endfunction

function! s:on_output(job, data, event) abort
	if a:data == [''] | return | endif
	call map(a:data, 'v:val[len(v:val)-1] ==# "\r" ? v:val[:-2] : v:val')
	let s:ga[a:event][-1] .= a:data[0]
	call extend(s:ga[a:event], a:data[1:])
endfunction

function! s:on_exit(job, code, event) abort
	if a:code | return s:on_error('[annotation] '.s:ga.stderr[0].': `'.join(s:ga.cmd).'` exited with status '.a:code) | endif
	let s:ga.job_id = 0
	let stdout = s:ga.stdout
	if len(stdout) < 11 | return s:on_error('[annotation] unexpected `git blame` output:'.join(stdout, '\n')) | endif
	let s:ga.hash = stdout[0][:39]
	let s:ga.committed = s:ga.hash !~# '^0\+$'
	let contents = [' Commit:    ' . s:ga.hash . ' ']
	let author = stdout[1][7:]
	let atime = stdout[3][12:]
	let contents += [' Author:    ' . author . ' @' . strftime('%F %T %z', atime)]
	if s:ga.committed
		let committer = stdout[5][10:]
		let ctime = stdout[7][15:]
		let summary = stdout[9][7:]
		let contents += [' Committer: ' . committer . ' @' . strftime('%F %T %z', ctime)] + [''] + [summary]
	else
		let contents += [''] + [' Not Committed Yet']
	endif

	let pos = win_screenpos('.')
	let opened_at = [pos[0] + winline() - 1, pos[1] + wincol() - 1]
	" | Commit:    a54e46630737ca325b9a952640a8a0d992b8dda9 |
	let width = 53
	let height = 4 + s:ga.committed
	if opened_at[0] + height <= &lines - 1
		let vert = 'N'
		let row = opened_at[0]
	else
		let vert = 'S'
		let row = opened_at[0] - 1
	endif
	if opened_at[1] + width <= &columns
		let hor = 'W'
		let col = opened_at[1] - 1
	else
		let hor = 'E'
		let col = opened_at[1]
	endif
	let s:ga.win_id = nvim_open_win(0, v:true, {
		\ 'relative': 'editor',
		\ 'anchor': vert . hor,
		\ 'row': row,
		\ 'col': col,
		\ 'width': width,
		\ 'height': height,
		\ 'style': 'minimal'})

	enew!
	let s:ga.bufnr = bufnr()
	call setline(1, contents)
	setlocal buftype=nofile bufhidden=wipe nowrap nomodifiable filetype=ga winblend=0
	autocmd BufLeave <buffer> call s:on_close()
	nnoremap <buffer><silent> d :<C-u>call <SID>reveal_diff(0, 'tab')<CR>
	nnoremap <buffer><silent> D :<C-u>call <SID>reveal_diff(1, 'tab')<CR>
	nnoremap <buffer><silent> s :<C-u>call <SID>reveal_diff(0, 'hor')<CR>
	nnoremap <buffer><silent> S :<C-u>call <SID>reveal_diff(1, 'hor')<CR>
	nnoremap <buffer><silent> o :<C-u>call <SID>reveal_diff(0, 'vert')<CR>
	nnoremap <buffer><silent> O :<C-u>call <SID>reveal_diff(1, 'vert')<CR>
	nnoremap <buffer><silent> a :<C-u>close \| .Flog<CR>
	nnoremap <buffer><silent> q :<C-u>close<CR>
endfunction

function! annotation#show(file, line) abort
	if has_key(s:ga, 'bufnr') | return s:on_close() | endif
	if s:ga.job_id > 0 | call jobstop(s:ga.job_id) | endif
	let s:ga.dir = FugitiveWorkTree()
	if s:ga.dir ==# '' | return s:on_error('[annotation] not inside a git repository') | endif
	let s:ga.file = a:file
	let s:ga.line = a:line
	let s:ga.cmd = ['git', '-C', s:ga.dir, '--no-pager', 'blame', '--porcelain', '-L', s:ga.line . ',+1', '--', s:ga.file]
	let s:ga.stdout = ['']
	let s:ga.stderr = ['']
	let s:ga.job_id = jobstart(s:ga.cmd, {
		\ 'on_stdout': function('s:on_output'),
		\ 'on_stderr': function('s:on_output'),
		\ 'on_exit'  : function('s:on_exit')})
	if s:ga.job_id <= 0 | call s:on_error('[annotation] failed to execute: '.join(s:ga.cmd)) | endif
endfunction
