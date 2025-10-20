if exists('b:current_syntax') | finish | endif

if g:flog_enable_extended_chars
	syn match gGraph nextgroup=gHash,@gDiff /\v^%(%(%uf5d0|%uf5d1|%uf5d4|%uf5d6|%uf5d7|%uf5d8|%uf5d9|%uf5da|%uf5db|%uf5dd|%uf5de|%uf5e0|%uf5e1|%uf5e5|%uf5e6|%uf5ea|%uf5ef|%uf5f6|%uf5f7|%uf5f9|%uf5fa|%uf5fb| ).)*/
else
	syn match gGraph nextgroup=gHash,@gDiff /\v^%(%(%u2022|%u2500|%u2502|%u250a|%u251c|%u2524|%u252c|%u2534|%u253c|%u256d|%u256e|%u256f|%u2570| ).)*/
endif
syn match gHash   contained /\x\{7,} / nextgroup=gMsg
syn match gMsg    contained /.*\ze[0-9+: -]\{27}@/ contains=gRef nextgroup=gDate
syn match gRef    contained /- \zs([^)]*) /
syn match gDate   contained /[0-9+: -]\{27}/ nextgroup=gAuthor
syn match gAuthor contained /@.*$/

syn cluster gDiff contains=diffBDiffer,diffAdded,diffChanged,diffComment,diffFile,diffIndexLine,diffLine,diffNewFile,diffNoEOL,diffOldFile,diffRemoved
syn match diffBDiffer   contained /Binary files .* and .* differ$/
syn match diffNoEOL     contained /\\ No newline at end of file.*/
syn match diffRemoved   contained /-.*/
syn match diffRemoved   contained /<.*/
syn match diffAdded     contained /+.*/
syn match diffAdded     contained />.*/
syn match diffChanged   contained /! .*/
syn match diffSubname   contained /@@..*/ms=s+3 containedin=diffSubname
syn match diffLine      contained /@.*/
syn match diffLine      contained /\*\*\*\*.*/
syn match diffLine      contained /---$/
syn match diffFile      contained /diff\>.*/
syn match diffFile      contained /Index: .*/
syn match diffFile      contained /==== .*/
syn match diffOldFile   contained /--- .*/
syn match diffNewFile   contained /+++ .*/
syn match diffIndexLine contained /index \x\x\x\x.*/
syn match diffComment   contained /#.*/

hi gHash   guifg=Red
hi gRef    guifg=#608e32
hi gDate   guifg=#6b98de
hi gAuthor gui=bold

hi flogBranch0 guifg=#608e32
hi flogBranch1 guifg=green3
hi flogBranch2 guifg=gold2
hi flogBranch3 guifg=orange2
hi flogBranch4 guifg=orangered3
hi flogBranch5 guifg=deeppink2
hi flogBranch6 guifg=darkviolet
hi flogBranch7 guifg=deepskyblue4
hi flogBranch8 guifg=cyan3

let b:current_syntax = 'flog'
