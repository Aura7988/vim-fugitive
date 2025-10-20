let g:flog_counter = 0
let g:flog_side_wins = {}
let g:flog_enable_extended_chars = len($KITTY_PID)

function! s:on_error(msg) abort
	echohl ErrorMsg | echom a:msg | echohl None
endfunction

function! s:get_index() abort
	return b:flog.line_commits[line('.') - 1]
endfunction

function! s:go_first(line) abort
	call cursor(a:line, 1)
	call search('\x', 'c', a:line)
	let lw = wincol() - getwininfo(win_getid())[0].textoff
	if lw < 5
		exe 'normal! ' . (5 - lw) . 'zh'
	endif
endfunction

function! s:jump_commit(count, open = 0) abort
	let offset = a:count + s:get_index()
	if offset < 0
		let offset = 0
	elseif offset >= len(b:flog.commits)
		let offset = -1
	endif
	call s:go_first(b:flog.commits[offset].line)
	if a:open
		call s:open_hash(b:flog.commits[offset].hash)
	endif
endfunction

function! s:jump_parent(count) abort
	let hash = get(b:flog.commits[s:get_index()].parents, a:count - 1)
	if empty(hash) | return | endif
	let offset = get(b:flog.commits_by_hash, hash, -1)
	if offset < 0 | return | endif
	call s:go_first(b:flog.commits[offset].line)
endfunction

function! s:jump_child(count) abort
	let offset = s:get_index()
	let hash = b:flog.commits[offset].hash
	let nchildren = 0
	let i = offset - 1
	while i >= 0 && nchildren != a:count
		if index(b:flog.commits[i].parents, hash) >= 0
			let offset = i
			let nchildren += 1
		endif
		let i -= 1
	endwhile
	if nchildren == a:count
		call s:go_first(b:flog.commits[offset].line)
	endif
endfunction

function! s:jump_ref(count) abort
	let step = a:count > 0 ? 1 : -1
	let end = len(b:flog.commits)
	let nrefs = 0
	let i = s:get_index() + step
	while i >= 0 && i < end && nrefs != a:count
		if len(b:flog.commits[i].refs)
			let offset = i
			let nrefs += step
		endif
		let i += step
	endwhile
	if nrefs != 0
		call s:go_first(b:flog.commits[offset].line)
	endif
endfunction

function! s:yank_hashes(reg, start, count) abort
	let first = b:flog.line_commits[line(a:start) - 1]
	let last = type(a:count) == v:t_number ? min([first + a:count, len(b:flog.commits)]) - 1 : b:flog.line_commits[line(a:count) - 1]
	let hashes = []
	for i in range(first, last)
		let hashes += [b:flog.commits[i].hash]
	endfor
	call setreg(a:reg, hashes, 'v')
endfunction

function! s:open_hash(sha = 0) abort
	let hash = empty(a:sha) ? b:flog.commits[s:get_index()].hash : a:sha
	let fid = b:flog.id
	if win_id2win(get(g:flog_side_wins, fid, 0))
		call win_gotoid(g:flog_side_wins[fid])
		exe 'Gedit ' . hash
	else
		exe 'rightbelow Gvsplit ' . hash
		let g:flog_side_wins[fid] = win_getid()
	endif
endfunction

function! flog#Show(range, line1, line2, bang, mods, args) abort
	if &filetype !=# 'flog'
		let gitdir = FugitiveGitDir()
		if gitdir ==# '' | return s:on_error('[flog] not inside a git repository') | endif
		let workdir = FugitiveWorkTree(gitdir)
		" The first time this is called, runs `git commit-graph write`
		if !filereadable(FugitiveGitDir() . '/objects/info/commit-graph')
			call system(['git', '-C', workdir, 'commit-graph', 'write', '--reachable', '--progress'])
		endif
		let cmd = 'git -C ' . shellescape(workdir) . ' log --no-color --pretty=' . shellescape('format:__L%n%h%n%p%n%D%n%h -%d %s %ai @%an')
	else
		let cmd = b:flog.cmd
		let workdir = b:flog.workdir
	endif

	let opts = a:bang ? '' : ' --parents --topo-order'
	let opts .= a:range > 0 ? (a:line1 != 0 ? ' -L'.a:line1.','.a:line2.':'.expand('%:p:S') : '') : ' -5999'
	let opts .= ' ' . a:args
	let graph = v:lua.require('flog/graph').get_graph(g:flog_counter, '__L', g:flog_enable_extended_chars, !a:bang, cmd.opts.' 2>&1')
	if empty(graph.output) | return s:on_error('[flog] failed to execute: ' . cmd.opts) | endif

	exe 'silent! ' . (len(a:mods) ? a:mods : 'tab') . ' split flog-' . g:flog_counter
	exe 'lcd ' . fnameescape(workdir)
	call setline(1, graph.output)
	let b:flog = {}
	let b:flog.cmd = cmd
	let b:flog.workdir = workdir
	let b:flog.id = g:flog_counter
	let b:flog.commits = graph.commits
	let b:flog.line_commits = graph.line_commits
	let b:flog.commits_by_hash = graph.commits_by_hash
	setlocal buftype=nofile bufhidden=wipe nowrap nomodeline nomodifiable filetype=flog concealcursor=n conceallevel=2 nolist
	call v:lua.require('flog/autocmd').nvim_create_graph_autocmds(bufnr(), g:flog_counter, !a:bang)
	let g:flog_counter += 1

	nnoremap <buffer>         .      :<C-u>Flog 
	nnoremap <buffer><silent> q      :<C-u>close<CR>
	nnoremap <buffer><silent> ^      :<C-u>call <SID>go_first(line('.'))<CR>
	nnoremap <buffer><silent> <CR>   :<C-u>call <SID>open_hash()<CR>
	nnoremap <buffer><silent> j      :<C-u>call <SID>jump_commit(v:count1)<CR>
	nnoremap <buffer><silent> k      :<C-u>call <SID>jump_commit(-v:count1)<CR>
	nnoremap <buffer><silent> ]]     :<C-u>call <SID>jump_parent(v:count1)<CR>
	nnoremap <buffer><silent> [[     :<C-u>call <SID>jump_child(v:count1)<CR>
	nnoremap <buffer><silent> <C-j>  :<C-u>call <SID>jump_commit(v:count1, 1)<CR>
	nnoremap <buffer><silent> <C-k>  :<C-u>call <SID>jump_commit(-v:count1, 1)<CR>
	nnoremap <buffer><silent> ]r     :<C-u>call <SID>jump_ref(v:count1)<CR>
	nnoremap <buffer><silent> [r     :<C-u>call <SID>jump_ref(-v:count1)<CR>
	nnoremap <buffer><silent> y<C-g> :<C-u>call <SID>yank_hashes(v:register, '.', v:count1)<CR>
	vnoremap <buffer><silent> y<C-g> :<C-u>call <SID>yank_hashes(v:register, "'<", "'>")<CR>
endfunction
