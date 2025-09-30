if exists('b:current_syntax') | finish | endif

syn match gaHeader '^ \=\%(Commit\|Author\|Committer\):' display
syn match gaHash '\%(^ \=Commit: \+\)\@<=[[:xdigit:]]\+' display
syn match gaTime '\%(^ \=\%(Author\|Committer\): \+.*\)\@<=@.\{25}' display
hi def link gaHeader Constant
hi def link gaHash   Error
hi def link gaTime   Comment

let b:current_syntax = 'ga'
