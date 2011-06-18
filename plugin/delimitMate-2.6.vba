" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
plugin/delimitMate.vim	[[[1
434
" File:        plugin/delimitMate.vim
" Version:     2.6
" Modified:    2011-01-14
" Description: This plugin provides auto-completion for quotes, parens, etc.
" Maintainer:  Israel Chauca F. <israelchauca@gmail.com>
" Manual:      Read ":help delimitMate".
" ============================================================================

" Initialization: {{{

if exists("g:loaded_delimitMate") || &cp
	" User doesn't want this plugin or compatible is set, let's get out!
	finish
endif
let g:loaded_delimitMate = 1

if exists("s:loaded_delimitMate") && !exists("g:delimitMate_testing")
	" Don't define the functions if they already exist: just do the work
	" (unless we are testing):
	call s:DelimitMateDo()
	finish
endif

if v:version < 700
	echoerr "delimitMate: this plugin requires vim >= 7!"
	finish
endif

let s:loaded_delimitMate = 1
let delimitMate_version = "2.6"

function! s:option_init(name, default) "{{{
	let b = exists("b:delimitMate_" . a:name)
	let g = exists("g:delimitMate_" . a:name)
	let prefix = "_l_delimitMate_"

	if !b && !g
		let sufix = a:default
	elseif !b && g
		exec "let sufix = g:delimitMate_" . a:name
	else
		exec "let sufix = b:delimitMate_" . a:name
	endif
	if exists("b:" . prefix . a:name)
		exec "unlockvar! b:" . prefix . a:name
	endif
	exec "let b:" . prefix . a:name . " = " . string(sufix)
	exec "lockvar! b:" . prefix . a:name
endfunction "}}}

function! s:init() "{{{
" Initialize variables:

	" autoclose
	call s:option_init("autoclose", 1)

	" matchpairs
	call s:option_init("matchpairs", string(&matchpairs)[1:-2])
	call s:option_init("matchpairs_list", split(b:_l_delimitMate_matchpairs, ','))
	call s:option_init("left_delims", split(b:_l_delimitMate_matchpairs, ':.,\='))
	call s:option_init("right_delims", split(b:_l_delimitMate_matchpairs, ',\=.:'))

	" quotes
	call s:option_init("quotes", "\" ' `")
	call s:option_init("quotes_list", split(b:_l_delimitMate_quotes))

	" nesting_quotes
	call s:option_init("nesting_quotes", [])

	" excluded_regions
	call s:option_init("excluded_regions", "Comment")
	call s:option_init("excluded_regions_list", split(b:_l_delimitMate_excluded_regions, ',\s*'))
	let enabled = len(b:_l_delimitMate_excluded_regions_list) > 0
	call s:option_init("excluded_regions_enabled", enabled)

	" excluded filetypes
	call s:option_init("excluded_ft", "")

	" expand_space
	if exists("b:delimitMate_expand_space") && type(b:delimitMate_expand_space) == type("")
		echom "b:delimitMate_expand_space is '".b:delimitMate_expand_space."' but it must be either 1 or 0!"
		echom "Read :help 'delimitMate_expand_space' for more details."
		unlet b:delimitMate_expand_space
		let b:delimitMate_expand_space = 1
	endif
	if exists("g:delimitMate_expand_space") && type(g:delimitMate_expand_space) == type("")
		echom "delimitMate_expand_space is '".g:delimitMate_expand_space."' but it must be either 1 or 0!"
		echom "Read :help 'delimitMate_expand_space' for more details."
		unlet g:delimitMate_expand_space
		let g:delimitMate_expand_space = 1
	endif
	call s:option_init("expand_space", 0)

	" expand_cr
	if exists("b:delimitMate_expand_cr") && type(b:delimitMate_expand_cr) == type("")
		echom "b:delimitMate_expand_cr is '".b:delimitMate_expand_cr."' but it must be either 1 or 0!"
		echom "Read :help 'delimitMate_expand_cr' for more details."
		unlet b:delimitMate_expand_cr
		let b:delimitMate_expand_cr = 1
	endif
	if exists("g:delimitMate_expand_cr") && type(g:delimitMate_expand_cr) == type("")
		echom "delimitMate_expand_cr is '".g:delimitMate_expand_cr."' but it must be either 1 or 0!"
		echom "Read :help 'delimitMate_expand_cr' for more details."
		unlet g:delimitMate_expand_cr
		let g:delimitMate_expand_cr = 1
	endif
	if ((&backspace !~ 'eol' || &backspace !~ 'start') && &backspace != 2) &&
				\ ((exists('b:delimitMate_expand_cr') && b:delimitMate_expand_cr == 1) ||
				\ (exists('g:delimitMate_expand_cr') && g:delimitMate_expand_cr == 1))
		echom "delimitMate: There seems to be some incompatibility with your settings that may interfer with the expansion of <CR>. See :help 'delimitMate_expand_cr' for details."
	endif
	call s:option_init("expand_cr", 0)

	" smart_matchpairs
	call s:option_init("smart_matchpairs", '^\%(\w\|\!\|£\|\$\|_\|["'']\s*\S\)')

	" smart_quotes
	call s:option_init("smart_quotes", 1)

	" apostrophes
	call s:option_init("apostrophes", "")
	call s:option_init("apostrophes_list", split(b:_l_delimitMate_apostrophes, ":\s*"))

	" tab2exit
	call s:option_init("tab2exit", 1)

	" balance_matchpairs
	call s:option_init("balance_matchpairs", 0)

	let b:_l_delimitMate_buffer = []

endfunction "}}} Init()

"}}}

" Functions: {{{

function! s:Map() "{{{
	" Set mappings:
	try
		let save_cpo = &cpo
		let save_keymap = &keymap
		let save_iminsert = &iminsert
		let save_imsearch = &imsearch
		set keymap=
		set cpo&vim
		if b:_l_delimitMate_autoclose
			call s:AutoClose()
		else
			call s:NoAutoClose()
		endif
		call s:ExtraMappings()
	finally
		let &cpo = save_cpo
		let &keymap = save_keymap
		let &iminsert = save_iminsert
		let &imsearch = save_imsearch
	endtry

	let b:delimitMate_enabled = 1

endfunction "}}} Map()

function! s:Unmap() " {{{
	let imaps =
				\ b:_l_delimitMate_right_delims +
				\ b:_l_delimitMate_left_delims +
				\ b:_l_delimitMate_quotes_list +
				\ b:_l_delimitMate_apostrophes_list +
				\ ['<BS>', '<S-BS>', '<Del>', '<CR>', '<Space>', '<S-Tab>', '<Esc>'] +
				\ ['<Up>', '<Down>', '<Left>', '<Right>', '<LeftMouse>', '<RightMouse>'] +
				\ ['<Home>', '<End>', '<PageUp>', '<PageDown>', '<S-Down>', '<S-Up>', '<C-G>g']

	for map in imaps
		if maparg(map, "i") =~? 'delimitMate'
			if map == '|'
				let map = '<Bar>'
			endif
			exec 'silent! iunmap <buffer> ' . map
		endif
	endfor

	if !has('gui_running')
		silent! iunmap <C-[>OC
	endif

	let b:delimitMate_enabled = 0
endfunction " }}} s:Unmap()

function! s:TestMappingsDo() "{{{
	%d
	if !exists("g:delimitMate_testing")
		silent call delimitMate#TestMappings()
	else
		let temp_varsDM = [b:_l_delimitMate_expand_space, b:_l_delimitMate_expand_cr, b:_l_delimitMate_autoclose]
		for i in [0,1]
			let b:delimitMate_expand_space = i
			let b:delimitMate_expand_cr = i
			for a in [0,1]
				let b:delimitMate_autoclose = a
				call s:init()
				call s:Unmap()
				call s:Map()
				call delimitMate#TestMappings()
				call append(line('$'),'')
			endfor
		endfor
		let b:delimitMate_expand_space = temp_varsDM[0]
		let b:delimitMate_expand_cr = temp_varsDM[1]
		let b:delimitMate_autoclose = temp_varsDM[2]
		unlet temp_varsDM
	endif
	normal gg
	g/\%^$/d
endfunction "}}}

function! s:DelimitMateDo(...) "{{{

	" First, remove all magic, if needed:
	if exists("b:delimitMate_enabled") && b:delimitMate_enabled == 1
		call s:Unmap()
	endif

	" Check if this file type is excluded:
	if exists("g:delimitMate_excluded_ft") &&
				\ index(split(g:delimitMate_excluded_ft, ','), &filetype, 0, 1) >= 0

		" Finish here:
		return 1
	endif

	" Check if user tried to disable using b:loaded_delimitMate
	if exists("b:loaded_delimitMate")
		return 1
	endif

	" Initialize settings:
	call s:init()

	" Now, add magic:
	call s:Map()

	if a:0 > 0
		echo "delimitMate has been reset."
	endif
endfunction "}}}

function! s:DelimitMateSwitch() "{{{
	if exists("b:delimitMate_enabled") && b:delimitMate_enabled
		call s:Unmap()
		echo "delimitMate has been disabled."
	else
		call s:Unmap()
		call s:init()
		call s:Map()
		echo "delimitMate has been enabled."
	endif
endfunction "}}}

function! s:Finish() " {{{
	if exists('g:delimitMate_loaded')
		return delimitMate#Finish(1)
	endif
	return ''
endfunction " }}}

function! s:FlushBuffer() " {{{
	if exists('g:delimitMate_loaded')
		return delimitMate#FlushBuffer()
	endif
	return ''
endfunction " }}}

"}}}

" Mappers: {{{
function! s:NoAutoClose() "{{{
	" inoremap <buffer> ) <C-R>=delimitMate#SkipDelim('\)')<CR>
	for delim in b:_l_delimitMate_right_delims + b:_l_delimitMate_quotes_list
		if delim == '|'
			let delim = '<Bar>'
		endif
		exec 'inoremap <silent> <Plug>delimitMate' . delim . ' <C-R>=delimitMate#SkipDelim("' . escape(delim,'"') . '")<CR>'
		exec 'silent! imap <unique> <buffer> '.delim.' <Plug>delimitMate'.delim
	endfor
endfunction "}}}

function! s:AutoClose() "{{{
	" Add matching pair and jump to the midle:
	" inoremap <silent> <buffer> ( ()<Left>
	let i = 0
	while i < len(b:_l_delimitMate_matchpairs_list)
		let ld = b:_l_delimitMate_left_delims[i] == '|' ? '<bar>' : b:_l_delimitMate_left_delims[i]
		let rd = b:_l_delimitMate_right_delims[i] == '|' ? '<bar>' : b:_l_delimitMate_right_delims[i]
		exec 'inoremap <silent> <Plug>delimitMate' . ld . ' ' . ld . '<C-R>=delimitMate#ParenDelim("' . escape(rd, '|') . '")<CR>'
		exec 'silent! imap <unique> <buffer> '.ld.' <Plug>delimitMate'.ld
		let i += 1
	endwhile

	" Exit from inside the matching pair:
	for delim in b:_l_delimitMate_right_delims
		exec 'inoremap <silent> <Plug>delimitMate' . delim . ' <C-R>=delimitMate#JumpOut("\' . delim . '")<CR>'
		exec 'silent! imap <unique> <buffer> ' . delim . ' <Plug>delimitMate'. delim
	endfor

	" Add matching quote and jump to the midle, or exit if inside a pair of matching quotes:
	" inoremap <silent> <buffer> " <C-R>=delimitMate#QuoteDelim("\"")<CR>
	for delim in b:_l_delimitMate_quotes_list
		if delim == '|'
			let delim = '<Bar>'
		endif
		exec 'inoremap <silent> <Plug>delimitMate' . delim . ' <C-R>=delimitMate#QuoteDelim("\' . delim . '")<CR>'
		exec 'silent! imap <unique> <buffer> ' . delim . ' <Plug>delimitMate' . delim
	endfor

	" Try to fix the use of apostrophes (kept for backward compatibility):
	" inoremap <silent> <buffer> n't n't
	for map in b:_l_delimitMate_apostrophes_list
		exec "inoremap <silent> " . map . " " . map
		exec 'silent! imap <unique> <buffer> ' . map . ' <Plug>delimitMate' . map
	endfor
endfunction "}}}

function! s:ExtraMappings() "{{{
	" If pair is empty, delete both delimiters:
	inoremap <silent> <Plug>delimitMateBS <C-R>=delimitMate#BS()<CR>
	if !hasmapto('<Plug>delimitMateBS','i')
		silent! imap <unique> <buffer> <BS> <Plug>delimitMateBS
	endif
	" If pair is empty, delete closing delimiter:
	inoremap <silent> <expr> <Plug>delimitMateS-BS delimitMate#WithinEmptyPair() ? "\<C-R>=delimitMate#Del()\<CR>" : "\<S-BS>"
	if !hasmapto('<Plug>delimitMateS-BS','i')
		silent! imap <unique> <buffer> <S-BS> <Plug>delimitMateS-BS
	endif
	" Expand return if inside an empty pair:
	inoremap <silent> <Plug>delimitMateCR <C-R>=delimitMate#ExpandReturn()<CR>
	if b:_l_delimitMate_expand_cr != 0 && !hasmapto('<Plug>delimitMateCR', 'i')
		silent! imap <unique> <buffer> <CR> <Plug>delimitMateCR
	endif
	" Expand space if inside an empty pair:
	inoremap <silent> <Plug>delimitMateSpace <C-R>=delimitMate#ExpandSpace()<CR>
	if b:_l_delimitMate_expand_space != 0 && !hasmapto('<Plug>delimitMateSpace', 'i')
		silent! imap <unique> <buffer> <Space> <Plug>delimitMateSpace
	endif
	" Jump over any delimiter:
	inoremap <silent> <Plug>delimitMateS-Tab <C-R>=delimitMate#JumpAny("\<S-Tab>")<CR>
	if b:_l_delimitMate_tab2exit && !hasmapto('<Plug>delimitMateS-Tab', 'i')
		silent! imap <unique> <buffer> <S-Tab> <Plug>delimitMateS-Tab
	endif
	" Change char buffer on Del:
	inoremap <silent> <Plug>delimitMateDel <C-R>=delimitMate#Del()<CR>
	if !hasmapto('<Plug>delimitMateDel', 'i')
		silent! imap <unique> <buffer> <Del> <Plug>delimitMateDel
	endif
	" Flush the char buffer on movement keystrokes or when leaving insert mode:
	for map in ['Esc', 'Left', 'Right', 'Home', 'End']
		exec 'inoremap <silent> <Plug>delimitMate'.map.' <C-R>=<SID>Finish()<CR><'.map.'>'
		if !hasmapto('<Plug>delimitMate'.map, 'i')
			exec 'silent! imap <unique> <buffer> <'.map.'> <Plug>delimitMate'.map
		endif
	endfor
	" Except when pop-up menu is active:
	for map in ['Up', 'Down', 'PageUp', 'PageDown', 'S-Down', 'S-Up']
		exec 'inoremap <silent> <expr> <Plug>delimitMate'.map.' pumvisible() ? "\<'.map.'>" : "\<C-R>=\<SID>Finish()\<CR>\<'.map.'>"'
		if !hasmapto('<Plug>delimitMate'.map, 'i')
			exec 'silent! imap <unique> <buffer> <'.map.'> <Plug>delimitMate'.map
		endif
	endfor
	" Avoid ambiguous mappings:
	for map in ['LeftMouse', 'RightMouse']
		exec 'inoremap <silent> <Plug>delimitMateM'.map.' <C-R>=delimitMate#Finish(1)<CR><'.map.'>'
		if !hasmapto('<Plug>delimitMate'.map, 'i')
			exec 'silent! imap <unique> <buffer> <'.map.'> <Plug>delimitMateM'.map
		endif
	endfor

	" Jump over next delimiters
	inoremap <buffer> <Plug>delimitMateJumpMany <C-R>=len(b:_l_delimitMate_buffer) ? delimitMate#Finish(0) : delimitMate#JumpMany()<CR>
	if !hasmapto('<Plug>delimitMateJumpMany')
		imap <silent> <buffer> <C-G>g <Plug>delimitMateJumpMany
	endif

	" The following simply creates an ambiguous mapping so vim fully processes
	" the escape sequence for terminal keys, see 'ttimeout' for a rough
	" explanation, this just forces it to work
	if !has('gui_running')
		imap <silent> <C-[>OC <RIGHT>
	endif
endfunction "}}}

"}}}

" Commands: {{{

call s:DelimitMateDo()

" Let me refresh without re-loading the buffer:
command! -bar DelimitMateReload call s:DelimitMateDo(1)

" Quick test:
command! -bar DelimitMateTest silent call s:TestMappingsDo()

" Switch On/Off:
command! -bar DelimitMateSwitch call s:DelimitMateSwitch()
"}}}

" Autocommands: {{{

augroup delimitMate
	au!
	" Run on file type change.
	"autocmd VimEnter * autocmd FileType * call <SID>DelimitMateDo()
	autocmd FileType * call <SID>DelimitMateDo()

	" Run on new buffers.
	autocmd BufNewFile,BufRead,BufEnter *
				\ if !exists('b:delimitMate_was_here') |
				\   call <SID>DelimitMateDo() |
				\   let b:delimitMate_was_here = 1 |
				\ endif

	" Flush the char buffer:
	autocmd InsertEnter * call <SID>FlushBuffer()
	autocmd BufEnter *
				\ if mode() == 'i' |
				\   call <SID>FlushBuffer() |
				\ endif

augroup END

"}}}

" GetLatestVimScripts: 2754 1 :AutoInstall: delimitMate.vim
" vim:foldmethod=marker:foldcolumn=4
autoload/delimitMate.vim	[[[1
586
" File:        autoload/delimitMate.vim
" Version:     2.6
" Modified:    2011-01-14
" Description: This plugin provides auto-completion for quotes, parens, etc.
" Maintainer:  Israel Chauca F. <israelchauca@gmail.com>
" Manual:      Read ":help delimitMate".
" ============================================================================

" Utilities {{{

let delimitMate_loaded = 1

function! delimitMate#ShouldJump() "{{{
	" Returns 1 if the next character is a closing delimiter.
	let col = col('.')
	let lcol = col('$')
	let char = getline('.')[col - 1]

	" Closing delimiter on the right.
	for cdel in b:_l_delimitMate_right_delims + b:_l_delimitMate_quotes_list
		if char == cdel
			return 1
		endif
	endfor

	" Closing delimiter with space expansion.
	let nchar = getline('.')[col]
	if b:_l_delimitMate_expand_space && char == " "
		for cdel in b:_l_delimitMate_right_delims + b:_l_delimitMate_quotes_list
			if nchar == cdel
				return 1
			endif
		endfor
	endif

	" Closing delimiter with CR expansion.
	let uchar = getline(line('.') + 1)[0]
	if b:_l_delimitMate_expand_cr && char == ""
		for cdel in b:_l_delimitMate_right_delims + b:_l_delimitMate_quotes_list
			if uchar == cdel
				return 1
			endif
		endfor
	endif

	return 0
endfunction "}}}

function! delimitMate#IsEmptyPair(str) "{{{
	for pair in b:_l_delimitMate_matchpairs_list
		if a:str == join( split( pair, ':' ),'' )
			return 1
		endif
	endfor
	for quote in b:_l_delimitMate_quotes_list
		if a:str == quote . quote
			return 1
		endif
	endfor
	return 0
endfunction "}}}

function! delimitMate#IsCRExpansion() " {{{
	let nchar = getline(line('.')-1)[-1:]
	let schar = getline(line('.')+1)[:0]
	let isEmpty = getline('.') == ""
	if index(b:_l_delimitMate_left_delims, nchar) > -1 &&
				\ index(b:_l_delimitMate_left_delims, nchar) == index(b:_l_delimitMate_right_delims, schar) &&
				\ isEmpty
		return 1
	elseif index(b:_l_delimitMate_quotes_list, nchar) > -1 &&
				\ index(b:_l_delimitMate_quotes_list, nchar) == index(b:_l_delimitMate_quotes_list, schar) &&
				\ isEmpty
		return 1
	else
		return 0
	endif
endfunction " }}} delimitMate#IsCRExpansion()

function! delimitMate#IsSpaceExpansion() " {{{
	let line = getline('.')
	let col = col('.')-2
	if col > 0
		let pchar = line[col - 1]
		let nchar = line[col + 2]
		let isSpaces = (line[col] == line[col+1] && line[col] == " ")

		if index(b:_l_delimitMate_left_delims, pchar) > -1 &&
				\ index(b:_l_delimitMate_left_delims, pchar) == index(b:_l_delimitMate_right_delims, nchar) &&
				\ isSpaces
			return 1
		elseif index(b:_l_delimitMate_quotes_list, pchar) > -1 &&
				\ index(b:_l_delimitMate_quotes_list, pchar) == index(b:_l_delimitMate_quotes_list, nchar) &&
				\ isSpaces
			return 1
		endif
	endif
	return 0
endfunction " }}} IsSpaceExpansion()

function! delimitMate#WithinEmptyPair() "{{{
	let cur = strpart( getline('.'), col('.')-2, 2 )
	return delimitMate#IsEmptyPair( cur )
endfunction "}}}

function! delimitMate#WriteBefore(str) "{{{
	let len = len(a:str)
	let line = getline('.')
	let col = col('.')-2
	if col < 0
		call setline('.',line[(col+len+1):])
	else
		call setline('.',line[:(col)].line[(col+len+1):])
	endif
	return a:str
endfunction " }}}

function! delimitMate#WriteAfter(str) "{{{
	let len = len(a:str)
	let line = getline('.')
	let col = col('.')-2
	if (col) < 0
		call setline('.',a:str.line)
	else
		call setline('.',line[:(col)].a:str.line[(col+len):])
	endif
	return ''
endfunction " }}}

function! delimitMate#GetSyntaxRegion(line, col) "{{{
	return synIDattr(synIDtrans(synID(a:line, a:col, 1)), 'name')
endfunction " }}}

function! delimitMate#GetCurrentSyntaxRegion() "{{{
	let col = col('.')
	if  col == col('$')
		let col = col - 1
	endif
	return delimitMate#GetSyntaxRegion(line('.'), col)
endfunction " }}}

function! delimitMate#GetCurrentSyntaxRegionIf(char) "{{{
	let col = col('.')
	let origin_line = getline('.')
	let changed_line = strpart(origin_line, 0, col - 1) . a:char . strpart(origin_line, col - 1)
	call setline('.', changed_line)
	let region = delimitMate#GetSyntaxRegion(line('.'), col)
	call setline('.', origin_line)
	return region
endfunction "}}}

function! delimitMate#IsForbidden(char) "{{{
	if b:_l_delimitMate_excluded_regions_enabled == 0
		return 0
	endif
	"let result = index(b:_l_delimitMate_excluded_regions_list, delimitMate#GetCurrentSyntaxRegion()) >= 0
	if index(b:_l_delimitMate_excluded_regions_list, delimitMate#GetCurrentSyntaxRegion()) >= 0
		"echom "Forbidden 1!"
		return 1
	endif
	let region = delimitMate#GetCurrentSyntaxRegionIf(a:char)
	"let result = index(b:_l_delimitMate_excluded_regions_list, region) >= 0
	"return result || region == 'Comment'
	"echom "Forbidden 2!"
	return index(b:_l_delimitMate_excluded_regions_list, region) >= 0
endfunction "}}}

function! delimitMate#FlushBuffer() " {{{
	let b:_l_delimitMate_buffer = []
	return ''
endfunction " }}}

function! delimitMate#BalancedParens(char) "{{{
	" Returns:
	" = 0 => Parens balanced.
	" > 0 => More opening parens.
	" < 0 => More closing parens.

	let line = getline('.')
	let col = col('.') - 2
	let col = col >= 0 ? col : 0
	let list = split(line, '\zs')
	let left = b:_l_delimitMate_left_delims[index(b:_l_delimitMate_right_delims, a:char)]
	let right = a:char
	let opening = 0
	let closing = 0

	" If the cursor is not at the beginning, count what's behind it.
	if col > 0
		  " Find the first opening paren:
		  let start = index(list, left)
		  " Must be before cursor:
		  let start = start < col ? start : col - 1
		  " Now count from the first opening until the cursor, this will prevent
		  " extra closing parens from being counted.
		  let opening = count(list[start : col - 1], left)
		  let closing = count(list[start : col - 1], right)
		  " I don't care if there are more closing parens than opening parens.
		  let closing = closing > opening ? opening : closing
	endif

	" Evaluate parens from the cursor to the end:
	let opening += count(list[col :], left)
	let closing += count(list[col :], right)

	"echom "–––––––––"
	"echom line
	"echom col
	""echom left.":".a:char
	"echom string(list)
	"echom string(list[start : col - 1]) . " : " . string(list[col :])
	"echom opening . " - " . closing . " = " . (opening - closing)

	" Return the found balance:
	return opening - closing
endfunction "}}}

function! delimitMate#RmBuffer(num) " {{{
	if len(b:_l_delimitMate_buffer) > 0
	   call remove(b:_l_delimitMate_buffer, 0, (a:num-1))
	endif
	return ""
endfunction " }}}

" }}}

" Doers {{{
function! delimitMate#SkipDelim(char) "{{{
	if delimitMate#IsForbidden(a:char)
		return a:char
	endif
	let col = col('.') - 1
	let line = getline('.')
	if col > 0
		let cur = line[col]
		let pre = line[col-1]
	else
		let cur = line[col]
		let pre = ""
	endif
	if pre == "\\"
		" Escaped character
		return a:char
	elseif cur == a:char
		" Exit pair
		"return delimitMate#WriteBefore(a:char)
		return a:char . delimitMate#Del()
	elseif delimitMate#IsEmptyPair( pre . a:char )
		" Add closing delimiter and jump back to the middle.
		call insert(b:_l_delimitMate_buffer, a:char)
		return delimitMate#WriteAfter(a:char)
	else
		" Nothing special here, return the same character.
		return a:char
	endif
endfunction "}}}

function! delimitMate#ParenDelim(char) " {{{
	if delimitMate#IsForbidden(a:char)
		return ''
	endif
	" Try to balance matchpairs
	if b:_l_delimitMate_balance_matchpairs &&
				\ delimitMate#BalancedParens(a:char) <= 0
		return ''
	endif
	let line = getline('.')
	let col = col('.')-2
	let left = b:_l_delimitMate_left_delims[index(b:_l_delimitMate_right_delims,a:char)]
	let smart_matchpairs = substitute(b:_l_delimitMate_smart_matchpairs, '\\!', left, 'g')
	let smart_matchpairs = substitute(smart_matchpairs, '\\#', a:char, 'g')
	"echom left.':'.smart_matchpairs . ':' . matchstr(line[col+1], smart_matchpairs)
	if b:_l_delimitMate_smart_matchpairs != '' &&
				\ line[col+1:] =~ smart_matchpairs
		return ''
	elseif (col) < 0
		call setline('.',a:char.line)
		call insert(b:_l_delimitMate_buffer, a:char)
	else
		"echom string(col).':'.line[:(col)].'|'.line[(col+1):]
		call setline('.',line[:(col)].a:char.line[(col+1):])
		call insert(b:_l_delimitMate_buffer, a:char)
	endif
	return ''
endfunction " }}}

function! delimitMate#QuoteDelim(char) "{{{
	if delimitMate#IsForbidden(a:char)
		return a:char
	endif
	let line = getline('.')
	let col = col('.') - 2
	if line[col] == "\\"
		" Seems like a escaped character, insert one quotation mark.
		return a:char
	elseif line[col + 1] == a:char &&
				\ index(b:_l_delimitMate_nesting_quotes, a:char) < 0
		" Get out of the string.
		return a:char . delimitMate#Del()
	elseif (line[col] =~ '\w' && a:char == "'") ||
				\ (b:_l_delimitMate_smart_quotes &&
				\ (line[col] =~ '\w' ||
				\ line[col + 1] =~ '\w'))
		" Seems like an apostrophe or a smart quote case, insert a single quote.
		return a:char
	elseif (line[col] == a:char && line[col + 1 ] != a:char) && b:_l_delimitMate_smart_quotes
		" Seems like we have an unbalanced quote, insert one quotation mark and jump to the middle.
		call insert(b:_l_delimitMate_buffer, a:char)
		return delimitMate#WriteAfter(a:char)
	else
		" Insert a pair and jump to the middle.
		call insert(b:_l_delimitMate_buffer, a:char)
		call delimitMate#WriteAfter(a:char)
		return a:char
	endif
endfunction "}}}

function! delimitMate#JumpOut(char) "{{{
	if delimitMate#IsForbidden(a:char)
		return a:char
	endif
	let line = getline('.')
	let col = col('.')-2
	if line[col+1] == a:char
		return a:char . delimitMate#Del()
	else
		return a:char
	endif
endfunction " }}}

function! delimitMate#JumpAny(key) " {{{
	if delimitMate#IsForbidden('')
		return a:key
	endif
	if !delimitMate#ShouldJump()
		return a:key
	endif
	" Let's get the character on the right.
	let char = getline('.')[col('.')-1]
	if char == " "
		" Space expansion.
		"let char = char . getline('.')[col('.')] . delimitMate#Del()
		return char . getline('.')[col('.')] . delimitMate#Del() . delimitMate#Del()
		"call delimitMate#RmBuffer(1)
	elseif char == ""
		" CR expansion.
		"let char = "\<CR>" . getline(line('.') + 1)[0] . "\<Del>"
		let b:_l_delimitMate_buffer = []
		return "\<CR>" . getline(line('.') + 1)[0] . "\<Del>"
	else
		"call delimitMate#RmBuffer(1)
		return char . delimitMate#Del()
	endif
endfunction " delimitMate#JumpAny() }}}

function! delimitMate#JumpMany() " {{{
	let line = getline('.')[col('.') - 1 : ]
	let len = len(line)
	let rights = ""
	let found = 0
	let i = 0
	while i < len
		let char = line[i]
		if index(b:_l_delimitMate_quotes_list, char) >= 0 ||
					\ index(b:_l_delimitMate_right_delims, char) >= 0
			let rights .= "\<Right>"
			let found = 1
		elseif found == 0
			let rights .= "\<Right>"
		else
			break
		endif
		let i += 1
	endwhile
	if found == 1
		return rights
	else
		return ''
	endif
endfunction " delimitMate#JumpMany() }}}

function! delimitMate#ExpandReturn() "{{{
	if delimitMate#IsForbidden("")
		return "\<CR>"
	endif
	if delimitMate#WithinEmptyPair()
		" Expand:
		call delimitMate#FlushBuffer()
		"return "\<Esc>a\<CR>x\<CR>\<Esc>k$\"_xa"
		return "\<CR>\<UP>\<Esc>o"
	else
		return "\<CR>"
	endif
endfunction "}}}

function! delimitMate#ExpandSpace() "{{{
	if delimitMate#IsForbidden("\<Space>")
		return "\<Space>"
	endif
	if delimitMate#WithinEmptyPair()
		" Expand:
		call insert(b:_l_delimitMate_buffer, 's')
		return delimitMate#WriteAfter(' ') . "\<Space>"
	else
		return "\<Space>"
	endif
endfunction "}}}

function! delimitMate#BS() " {{{
	if delimitMate#IsForbidden("")
		return "\<BS>"
	endif
	if delimitMate#WithinEmptyPair()
		"call delimitMate#RmBuffer(1)
		return "\<BS>" . delimitMate#Del()
"        return "\<Right>\<BS>\<BS>"
	elseif delimitMate#IsSpaceExpansion()
		"call delimitMate#RmBuffer(1)
		return "\<BS>" . delimitMate#Del()
	elseif delimitMate#IsCRExpansion()
		return "\<BS>\<Del>"
	else
		return "\<BS>"
	endif
endfunction " }}} delimitMate#BS()

function! delimitMate#Del() " {{{
	if len(b:_l_delimitMate_buffer) > 0
		let line = getline('.')
		let col = col('.') - 2
		call delimitMate#RmBuffer(1)
		call setline('.', line[:col] . line[col+2:])
		return ''
	else
		return "\<Del>"
	endif
endfunction " }}}

function! delimitMate#Finish(move_back) " {{{
	let len = len(b:_l_delimitMate_buffer)
	if len > 0
		let buffer = join(b:_l_delimitMate_buffer, '')
		let len2 = len(buffer)
		" Reset buffer:
		let b:_l_delimitMate_buffer = []
		let line = getline('.')
		let col = col('.') -2
		"echom 'col: ' . col . '-' . line[:col] . "|" . line[col+len+1:] . '%' . buffer
		if col < 0
			call setline('.', line[col+len2+1:])
		else
			call setline('.', line[:col] . line[col+len2+1:])
		endif
		let i = 1
		let lefts = ""
		while i <= len && a:move_back
			let lefts = lefts . "\<Left>"
			let i += 1
		endwhile
		return substitute(buffer, "s", "\<Space>", 'g') . lefts
	endif
	return ''
endfunction " }}}

" }}}

" Tools: {{{
function! delimitMate#TestMappings() "{{{
	let options = sort(keys(delimitMate#OptionsList()))
	let optoutput = ['delimitMate Report', '==================', '', '* Options: ( ) default, (g) global, (b) buffer','']
	for option in options
		exec 'call add(optoutput, ''('.(exists('b:delimitMate_'.option) ? 'b' : exists('g:delimitMate_'.option) ? 'g' : ' ').') delimitMate_''.option.'' = ''.string(b:_l_delimitMate_'.option.'))'
	endfor
	call append(line('$'), optoutput + ['--------------------',''])

	" Check if mappings were set. {{{
	let imaps = b:_l_delimitMate_right_delims
	let imaps = imaps + ( b:_l_delimitMate_autoclose ? b:_l_delimitMate_left_delims : [] )
	let imaps = imaps +
				\ b:_l_delimitMate_quotes_list +
				\ b:_l_delimitMate_apostrophes_list +
				\ ['<BS>', '<S-BS>', '<Del>', '<S-Tab>', '<Esc>'] +
				\ ['<Up>', '<Down>', '<Left>', '<Right>', '<LeftMouse>', '<RightMouse>'] +
				\ ['<Home>', '<End>', '<PageUp>', '<PageDown>', '<S-Down>', '<S-Up>', '<C-G>g']
	let imaps = imaps + ( b:_l_delimitMate_expand_cr ?  ['<CR>'] : [] )
	let imaps = imaps + ( b:_l_delimitMate_expand_space ?  ['<Space>'] : [] )

	let vmaps =
				\ b:_l_delimitMate_right_delims +
				\ b:_l_delimitMate_left_delims +
				\ b:_l_delimitMate_quotes_list

	let ibroken = []
	for map in imaps
		if maparg(map, "i") !~? 'delimitMate'
			let output = ''
			if map == '|'
				let map = '<Bar>'
			endif
			redir => output | execute "verbose imap ".map | redir END
			let ibroken = ibroken + [map.": is not set:"] + split(output, '\n')
		endif
	endfor

	unlet! output
	if ibroken == []
		let output = ['* Mappings:', '', 'All mappings were set-up.', '--------------------', '', '']
	else
		let output = ['* Mappings:', ''] + ibroken + ['--------------------', '']
	endif
	call append('$', output+['* Showcase:', ''])
	" }}}
	if b:_l_delimitMate_autoclose
		" {{{
		for i in range(len(b:_l_delimitMate_left_delims))
			exec "normal Go0\<C-D>Open: " . b:_l_delimitMate_left_delims[i]. "|"
			exec "normal o0\<C-D>Delete: " . b:_l_delimitMate_left_delims[i] . "\<BS>|"
			exec "normal o0\<C-D>Exit: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . "|"
			if b:_l_delimitMate_expand_space == 1
				exec "normal o0\<C-D>Space: " . b:_l_delimitMate_left_delims[i] . " |"
				exec "normal o0\<C-D>Delete space: " . b:_l_delimitMate_left_delims[i] . " \<BS>|"
			endif
			if b:_l_delimitMate_expand_cr == 1
				exec "normal o0\<C-D>Car return: " . b:_l_delimitMate_left_delims[i] . "\<CR>|"
				exec "normal Go0\<C-D>Delete car return: " . b:_l_delimitMate_left_delims[i] . "\<CR>0\<C-D>\<BS>|"
			endif
			call append(line('$'), '')
		endfor
		for i in range(len(b:_l_delimitMate_quotes_list))
			exec "normal Go0\<C-D>Open: " . b:_l_delimitMate_quotes_list[i]	. "|"
			exec "normal o0\<C-D>Delete: " . b:_l_delimitMate_quotes_list[i] . "\<BS>|"
			exec "normal o0\<C-D>Exit: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . "|"
			if b:_l_delimitMate_expand_space == 1
				exec "normal o0\<C-D>Space: " . b:_l_delimitMate_quotes_list[i] . " |"
				exec "normal o0\<C-D>Delete space: " . b:_l_delimitMate_quotes_list[i] . " \<BS>|"
			endif
			if b:_l_delimitMate_expand_cr == 1
				exec "normal o0\<C-D>Car return: " . b:_l_delimitMate_quotes_list[i] . "\<CR>|"
				exec "normal Go0\<C-D>Delete car return: " . b:_l_delimitMate_quotes_list[i] . "\<CR>\<BS>|"
			endif
			call append(line('$'), '')
		endfor
		"}}}
	else
		"{{{
		for i in range(len(b:_l_delimitMate_left_delims))
			exec "normal GoOpen & close: " . b:_l_delimitMate_left_delims[i]	. b:_l_delimitMate_right_delims[i] . "|"
			exec "normal oDelete: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . "\<BS>|"
			exec "normal oExit: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . b:_l_delimitMate_right_delims[i] . "|"
			if b:_l_delimitMate_expand_space == 1
				exec "normal oSpace: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . " |"
				exec "normal oDelete space: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . " \<BS>|"
			endif
			if b:_l_delimitMate_expand_cr == 1
				exec "normal oCar return: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . "\<CR>|"
				exec "normal GoDelete car return: " . b:_l_delimitMate_left_delims[i] . b:_l_delimitMate_right_delims[i] . "\<CR>\<BS>|"
			endif
			call append(line('$'), '')
		endfor
		for i in range(len(b:_l_delimitMate_quotes_list))
			exec "normal GoOpen & close: " . b:_l_delimitMate_quotes_list[i]	. b:_l_delimitMate_quotes_list[i] . "|"
			exec "normal oDelete: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . "\<BS>|"
			exec "normal oExit: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . "|"
			if b:_l_delimitMate_expand_space == 1
				exec "normal oSpace: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . " |"
				exec "normal oDelete space: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . " \<BS>|"
			endif
			if b:_l_delimitMate_expand_cr == 1
				exec "normal oCar return: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . "\<CR>|"
				exec "normal GoDelete car return: " . b:_l_delimitMate_quotes_list[i] . b:_l_delimitMate_quotes_list[i] . "\<CR>\<BS>|"
			endif
			call append(line('$'), '')
		endfor
	endif "}}}
	redir => setoptions | set | filetype | redir END
	call append(line('$'), split(setoptions,"\n")
				\ + ['--------------------'])
	setlocal nowrap
endfunction "}}}

function! delimitMate#OptionsList() "{{{
	return {'autoclose' : 1,'matchpairs': &matchpairs, 'quotes' : '" '' `', 'nesting_quotes' : [], 'expand_cr' : 0, 'expand_space' : 0, 'smart_quotes' : 1, 'smart_matchpairs' : '\w', 'balance_matchpairs' : 0, 'excluded_regions' : 'Comment', 'excluded_ft' : '', 'apostrophes' : ''}
endfunction " delimitMate#OptionsList }}}
"}}}

" vim:foldmethod=marker:foldcolumn=4
doc/delimitMate.txt	[[[1
818
*delimitMate.txt*   Trying to keep those beasts at bay! v2.6     *delimitMate*



  MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
  MMMM  MMMMMMMMM  MMMMMMMMMMMMMMMMMMMMMMMMMM  MMMMM  MMMMMMMMMMMMMMMMMMMMM  ~
  MMMM  MMMMMMMMM  MMMMMMMMMMMMMMMMMMMMMMMMMM   MMM   MMMMMMMMMMMMMMMMMMMMM
  MMMM  MMMMMMMMM  MMMMMMMMMMMMMMMMMMMMM  MMM  M   M  MMMMMMMMMM  MMMMMMMMM  ~
  MMMM  MMM   MMM  MM  MM  M  M MMM  MM    MM  MM MM  MMM   MMM    MMM   MM
  MM    MM  M  MM  MMMMMM        MMMMMMM  MMM  MMMMM  MM  M  MMM  MMM  M  M  ~
  M  M  MM     MM  MM  MM  M  M  MM  MMM  MMM  MMMMM  MMMMM  MMM  MMM     M
  M  M  MM  MMMMM  MM  MM  M  M  MM  MMM  MMM  MMMMM  MMM    MMM  MMM  MMMM  ~
  M  M  MM  M  MM  MM  MM  M  M  MM  MMM  MMM  MMMMM  MM  M  MMM  MMM  M  M
  MM    MMM   MMM  MM  MM  M  M  MM  MMM   MM  MMMMM  MMM    MMM   MMM   MM  ~
  MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM



==============================================================================
 0.- CONTENTS                                           *delimitMate-contents*

    1. Introduction____________________________|delimitMateIntro|
    2. Customization___________________________|delimitMateOptions|
        2.1 Options summary____________________|delimitMateOptionSummary|
        2.2 Options details____________________|delimitMateOptionDetails|
    3. Functionality___________________________|delimitMateFunctionality|
        3.1 Automatic closing & exiting________|delimitMateAutoClose|
        3.2 Expansion of space and CR__________|delimitMateExpansion|
        3.3 Backspace__________________________|delimitMateBackspace|
        3.4 Smart Quotes_______________________|delimitMateSmartQuotes|
        3.5 Balancing matching pairs___________|delimitMateBalance|
        3.6 FileType based configuration_______|delimitMateFileType|
        3.7 Syntax awareness___________________|delimitMateSyntax|
    4. Commands________________________________|delimitMateCommands|
    5. Mappings________________________________|delimitMateMappings|
    6. Functions_______________________________|delimitMateFunctions|
    7. TODO list_______________________________|delimitMateTodo|
    8. Maintainer______________________________|delimitMateMaintainer|
    9. Credits_________________________________|delimitMateCredits|
   10. History_________________________________|delimitMateHistory|

==============================================================================
 1.- INTRODUCTION                                           *delimitMateIntro*

This plug-in provides automatic closing of quotes, parenthesis, brackets,
etc.; besides some other related features that should make your time in insert
mode a little bit easier.

Most of the features can be modified or disabled permanently, using global
variables, or on a FileType basis, using autocommands. With a couple of
exceptions and limitations, this features don't brake undo, redo or history.

NOTE 1: If you have any trouble with this plugin, please run |:DelimitMateTest|
in a new buffer to see what is not working.

NOTE 2: |'timeout'| needs to be set when working in the terminal, otherwise you
might find weird behaviour with mappings including <Esc> or arrow keys.

NOTE 3: Abbreiations set with |:iabbrev| will not be expanded by delimiters
used on delimitMate, you should use <C-]> (read |i_CTRL-]|) to expand them on
the go.

==============================================================================
 2. CUSTOMIZATION                                         *delimitMateOptions*

You can create your own mappings for some features using the global functions.
Read |DelimitMateFunctions| for more info.

------------------------------------------------------------------------------
   2.1 OPTIONS SUMMARY                              *delimitMateOptionSummary*

The behaviour of this script can be customized setting the following options
in your vimrc file. You can use local options to set the configuration for
specific file types, see |delimitMateOptionDetails| for examples.

|'loaded_delimitMate'|            Turns off the script.

|'delimitMate_autoclose'|         Tells delimitMate whether to automagically
                                insert the closing delimiter.

|'delimitMate_matchpairs'|        Tells delimitMate which characters are
                                matching pairs.

|'delimitMate_quotes'|            Tells delimitMate which quotes should be
                                used.

|'delimitMate_nesting_quotes'|    Tells delimitMate which quotes should be
                                allowed to be nested.

|'delimitMate_expand_cr'|         Turns on/off the expansion of <CR>.

|'delimitMate_expand_space'|      Turns on/off the expansion of <Space>.

|'delimitMate_smart_quotes'|      Turns on/off the "smart quotes" feature.

|'delimitMate_smart_matchpairs'|  Turns on/off the "smart matchpairs" feature.

|'delimitMate_balance_matchpairs'|Turns on/off the "balance matching pairs"
                                feature.

|'delimitMate_excluded_regions'|  Turns off the script for the given regions or
                                syntax group names.

|'delimitMate_excluded_ft'|       Turns off the script for the given file types.

|'delimitMate_apostrophes'|       Tells delimitMate how it should "fix"
                                balancing of single quotes when used as
                                apostrophes. NOTE: Not needed any more, kept
                                for compatibility with older versions.

------------------------------------------------------------------------------
   2.2 OPTIONS DETAILS                              *delimitMateOptionDetails*

Add the shown lines to your vimrc file in order to set the below options.
Buffer variables take precedence over global ones and can be used along with
autocmd to modify delimitMate's behavior for specific file types, read more in
|delimitMateFileType|.

Note: Use buffer variables only to set options for specific file types using
:autocmd, use global variables to set options for every buffer. Read more in
|g:var| and |b:var|.

------------------------------------------------------------------------------
                                                        *'loaded_delimitMate'*
                                                      *'b:loaded_delimitMate'*
This option prevents delimitMate from loading.
e.g.: >
        let loaded_delimitMate = 1
        au FileType mail let b:loaded_delimitMate = 1
<
------------------------------------------------------------------------------
                                                     *'delimitMate_autoclose'*
                                                   *'b:delimitMate_autoclose'*
Values: 0 or 1.                                                              ~
Default: 1                                                                   ~

If this option is set to 0, delimitMate will not add a closing delimiter
automagically. See |delimitMateAutoClose| for details.
e.g.: >
        let delimitMate_autoclose = 0
        au FileType mail let b:delimitMate_autoclose = 0
<
------------------------------------------------------------------------------
                                                    *'delimitMate_matchpairs'*
                                                  *'b:delimitMate_matchpairs'*
Values: A string with |'matchpairs'| syntax, plus support for multi-byte~
        characters.~
Default: &matchpairs                                                         ~

Use this option to tell delimitMate which characters should be considered
matching pairs. Read |delimitMateAutoClose| for details.
e.g: >
        let delimitMate_matchpairs = "(:),[:],{:},<:>"
        au FileType vim,html let b:delimitMate_matchpairs = "(:),[:],{:},<:>"
<
------------------------------------------------------------------------------
                                                        *'delimitMate_quotes'*
                                                      *'b:delimitMate_quotes'*
Values: A string of characters separated by spaces.                          ~
Default: "\" ' `"                                                            ~

Use this option to tell delimitMate which characters should be considered as
quotes. Read |delimitMateAutoClose| for details.
e.g.: >
        let delimitMate_quotes = "\" ' ` *"
        au FileType html let b:delimitMate_quotes = "\" '"
<
------------------------------------------------------------------------------
                                                *'delimitMate_nesting_quotes'*
                                              *'b:delimitMate_nesting_quotes'*
Values: A list of quotes.                                                    ~
Default: []                                                                  ~

Quotes listed here will not be able to jump out of the empty pair, thus
allowing the autoclosed quotes to be nested.
e.g.: >
        let delimitMate_nesting_quotes = ['"','`']
        au FileType python let b:delimitMate_nesting_quotes = ['"']
<
------------------------------------------------------------------------------
                                                     *'delimitMate_expand_cr'*
                                                   *'b:delimitMate_expand_cr'*
Values: 1 or 0                                                               ~
Default: 0                                                                   ~

This option turns on/off the expansion of <CR>. Read |delimitMateExpansion|
for details. NOTE This feature requires that 'backspace' is either set to 2 or
has "eol" and "start" as part of its value.
e.g.: >
        let delimitMate_expand_cr = 1
        au FileType mail let b:delimitMate_expand_cr = 1
<
------------------------------------------------------------------------------
                                                  *'delimitMate_expand_space'*
                                                *'b:delimitMate_expand_space'*
Values: 1 or 0                                                               ~
Default: 0                                                                   ~
This option turns on/off the expansion of <Space>. Read |delimitMateExpansion|
for details.
e.g.: >
        let delimitMate_expand_space = 1
        au FileType tcl let b:delimitMate_expand_space = 1
<
------------------------------------------------------------------------------
                                                  *'delimitMate_smart_quotes'*
                                                *'b:delimitMate_smart_quotes'*
Values: 1 or 0                                                               ~
Default: 1                              ~

This option turns on/off the smart quotes feature. Read
|delimitMateSmartQuotes| for details.
e.g.: >
        let delimitMate_smart_quotes = 0
        au FileType tcl let b:delimitMate_smart_quotes = 1
<
------------------------------------------------------------------------------
                                              *'delimitMate_smart_matchpairs'*
                                            *'b:delimitMate_smart_matchpairs'*
Values: Regexp                                                               ~
Default: '^\%(\w\|\!\|£\|\$\|_\|["'']\s*\S\)'                                ~

This regex is matched against the text to the right of cursor, if it's not
empty and there is a match delimitMate will not autoclose the pair. At the
moment to match the text, an escaped bang (\!) in the regex will be replaced
by the character being inserted, while an escaped number symbol (\#) will be
replaced by the closing pair.
e.g.: >
        let delimitMate_smart_matchpairs = ''
        au FileType tcl let b:delimitMate_smart_matchpairs = '^\%(\w\|\$\)'
<
------------------------------------------------------------------------------
                                            *'delimitMate_balance_matchpairs'*
                                          *'b:delimitMate_balance_matchpairs'*
Values: 1 or 0                                                               ~
Default: 0                                                                   ~

This option turns on/off the balancing of matching pairs. Read
|delimitMateBalance| for details.
e.g.: >
        let delimitMate_balance_matchpairs = 1
        au FileType tcl let b:delimitMate_balance_matchpairs = 1
<
------------------------------------------------------------------------------
                                              *'delimitMate_excluded_regions'*
Values: A string of syntax group names names separated by single commas.     ~
Default: Comment                                                             ~

This options turns delimitMate off for the listed regions, read |group-name|
for more info about what is a region.
e.g.: >
        let delimitMate_excluded_regions = "Comments,String"
<
------------------------------------------------------------------------------
                                                   *'delimitMate_excluded_ft'*
Values: A string of file type names separated by single commas.              ~
Default: Empty.                                                              ~

This options turns delimitMate off for the listed file types, use this option
only if you don't want any of the features it provides on those file types.
e.g.: >
        let delimitMate_excluded_ft = "mail,txt"
<
------------------------------------------------------------------------------
                                                   *'delimitMate_apostrophes'*
Values: Strings separated by ":".                                            ~
Default: No longer used.                                                     ~

NOTE: This feature is turned off by default, it's been kept for compatibility
with older version, read |delimitMateSmartQuotes| for details.
If auto-close is enabled, this option tells delimitMate how to try to fix the
balancing of single quotes when used as apostrophes. The values of this option
are strings of text where a single quote would be used as an apostrophe (e.g.:
the "n't" of wouldn't or can't) separated by ":". Set it to an empty string to
disable this feature.
e.g.: >
        let delimitMate_apostrophes = ""
        au FileType tcl let delimitMate_apostrophes = ""
<
==============================================================================
 3. FUNCTIONALITY                                   *delimitMateFunctionality*

------------------------------------------------------------------------------
   3.1 AUTOMATIC CLOSING AND EXITING                    *delimitMateAutoClose*

With automatic closing enabled, if an opening delimiter is inserted the plugin
inserts the closing delimiter and places the cursor between the pair. With
automatic closing disabled, no closing delimiters is inserted by delimitMate,
but when a pair of delimiters is typed, the cursor is placed in the middle.

When the cursor is inside an empty pair or located next to the left of a
closing delimiter, the cursor is placed outside the pair to the right of the
closing delimiter.

When |'delimitMate_smart_matchpairs'| is not empty and it matches the text to
the right of the cursor, delimitMate will not automatically insert the closing
pair.

Unless |'delimitMate_matchpairs'| or |'delimitMate_quotes'| are set, this
script uses the values in '&matchpairs' to identify the pairs, and ", ' and `
for quotes respectively.

<S-Tab> will jump over a single closing delimiter or quote, <C-G>g will jump
over contiguous delimiters and/or quotes.

The following table shows the behaviour, this applies to quotes too (the final
position of the cursor is represented by a "|"):

With auto-close: >
                          Type     |  You get
                        =======================
                           (       |    (|)
                        –––––––––––|–––––––––––
                           ()      |    ()|
                        –––––––––––|–––––––––––
                        (<S-Tab>   |    ()|
                        –––––––––––|–––––––––––
                        {("<C-G>g  |  {("")}|
<
Without auto-close: >

                          Type        |  You get
                        =========================
                           ()         |    (|)
                        –––––––––-----|––––––––––
                           ())        |    ()|
                        –––––––––-----|––––––––––
                        ()<S-Tab>     |    ()|
                        ––––––––––––––|–––––––––––
                        {}()""<C-G>g  |  {("")}|
<
NOTE: Abbreviations will not be expanded by delimiters used on delimitMate,
you should use <C-]> (read |i_CTRL-]|) to expand them on the go.

------------------------------------------------------------------------------
   3.2 EXPANSION OF SPACE AND CAR RETURN                *delimitMateExpansion*

When the cursor is inside an empty pair of delimiters, <Space> and <CR> can be
expanded, see |'delimitMate_expand_space'| and
|'delimitMate_expand_cr'|:

Expand <Space> to: >

                    <Space><Space><Left>  |  You get
                  ====================================
                              (|)         |    ( | )
<
Expand <CR> to: >

                      <CR><CR><Up>  |  You get
                    ============================
                           (|)      |    (
                                    |    |
                                    |    )
<

NOTE that the expansion of <CR> will brake the redo command.

Since <Space> and <CR> are used everywhere, I have made the functions involved
in expansions global, so they can be used to make custom mappings. Read
|delimitMateFunctions| for more details.

------------------------------------------------------------------------------
   3.3 BACKSPACE                                        *delimitMateBackspace*

If you press backspace inside an empty pair, both delimiters are deleted. When
expansions are enabled, <BS> will also delete the expansions. NOTE that
deleting <CR> expansions will brake the redo command.

If you type <S-BS> (shift + backspace) instead, only the closing delimiter
will be deleted. NOTE that this will not usually work when using Vim from the
terminal, see 'delimitMate#JumpAny()' below to see how to fix it.

e.g. typing at the "|": >

                  What  |      Before       |      After
               ==============================================
                  <BS>  |  call expand(|)   |  call expand|
               ---------|-------------------|-----------------
                  <BS>  |  call expand( | ) |  call expand(|)
               ---------|-------------------|-----------------
                  <BS>  |  call expand(     |  call expand(|)
                        |  |                |
                        |  )                |
               ---------|-------------------|-----------------
                 <S-BS> |  call expand(|)   |  call expand(|
<

------------------------------------------------------------------------------
   3.4 SMART QUOTES                                   *delimitMateSmartQuotes*

Only one quote will be inserted following a quote, a "\" or, following or
preceding a keyword character. This should cover closing quotes after a
string, opening quotes before a string, escaped quotes and apostrophes. Except
for apostrophes, this feature can be disabled setting the option
|'delimitMate_smart_quotes'| to 0.

e.g. typing at the "|": >

                     What |    Before    |     After
                  =======================================
                      "   |  Text |      |  Text "|"
                      "   |  "String|    |  "String"|
                      "   |  let i = "|  |  let i = "|"
                      'm  |  I|          |  I'm|
<
------------------------------------------------------------------------------
   3.4 SMART MATCHPAIRS                           *delimitMateSmartMatchpairs*

This is similar to "smart quotes", but applied to the characters in
|'delimitMate_matchpairs'|. The difference is that delimitMate will not
auto-close the pair when the regex matches the text on the right of the
cursor. See |'delimitMate_smart_matchpairs'| for more details.


e.g. typing at the "|": >

                     What |    Before    |     After
                  =======================================
                      (   |  function|   |  function(|)
                      (   |  |var        |  (|var
<
------------------------------------------------------------------------------
   3.5 BALANCING MATCHING PAIRS                           *delimitMateBalance*

When inserting an opening paren and |'delimitMate_balance_matchpairs'| is
enabled, delimitMate will try to balance the closing pairs in the current
line.

e.g. typing at the "|": >

                     What |    Before    |     After
                  =======================================
                      (   |      |       |     (|)
                      (   |      |)      |     (|)
                      ((  |      |)      |    ((|))
<
------------------------------------------------------------------------------
   3.6 FILE TYPE BASED CONFIGURATION                     *delimitMateFileType*

delimitMate options can be set globally for all buffers using global
("regular") variables in your |vimrc| file. But |:autocmd| can be used to set
options for specific file types (see |'filetype'|) using buffer variables in
the following way: >

   au FileType mail,text let b:delimitMate_autoclose = 0
         ^       ^           ^            ^            ^
         |       |           |            |            |
         |       |           |            |            - Option value.
         |       |           |            - Option name.
         |       |           - Buffer variable.
         |       - File types for which the option will be set.
         - Don't forget to put this event.
<
NOTE that you should use buffer variables (|b:var|) only to set options with
|:autocmd|, for global options use regular variables (|g:var|) in your vimrc.

------------------------------------------------------------------------------
   3.7 SYNTAX AWARENESS                                    *delimitMateSyntax*

The features of this plug-in might not be always helpful, comments and strings
usualy don't need auto-completion. delimitMate monitors which region is being
edited and if it detects that the cursor is in a comment it'll turn itself off
until the cursor leaves the comment. The excluded regions can be set using the
option |'delimitMate_excluded_regions'|. Read |group-name| for a list of
regions or syntax group names.

NOTE that this feature relies on a proper syntax file for the current file
type, if the appropiate syntax file doesn't define a region, delimitMate won't
know about it.

==============================================================================
 4. COMMANDS                                             *delimitMateCommands*

------------------------------------------------------------------------------
:DelimitMateReload                                        *:DelimitMateReload*

Re-sets all the mappings used for this script, use it if any option has been
changed or if the filetype option hasn't been set yet.

------------------------------------------------------------------------------
:DelimitMateSwitch                                        *:DelimitMateSwitch*

Switches the plug-in on and off.

------------------------------------------------------------------------------
:DelimitMateTest                                            *:DelimitMateTest*

This command tests every mapping set-up for this script, useful for testing
custom configurations.

The following output corresponds to the default values, it will be different
depending on your configuration. "Open & close:" represents the final result
when the closing delimiter has been inserted, either manually or
automatically, see |delimitMateExpansion|. "Delete:" typing backspace in an
empty pair, see |delimitMateBackspace|. "Exit:" typing a closing delimiter
inside a pair of delimiters, see |delimitMateAutoclose|. "Space:" the
expansion, if any, of space, see |delimitMateExpansion|. "Visual-L",
"Visual-R" and "Visual" shows visual wrapping, see
|delimitMateVisualWrapping|. "Car return:" the expansion of car return, see
|delimitMateExpansion|. The cursor's position at the end of every test is
represented by an "|": >

            * AUTOCLOSE:
            Open & close: (|)
            Delete: |
            Exit: ()|
            Space: ( |)
            Visual-L: (v)
            Visual-R: (v)
            Car return: (
            |)

            Open & close: {|}
            Delete: |
            Exit: {}|
            Space: { |}
            Visual-L: {v}
            Visual-R: {v}
            Car return: {
            |}

            Open & close: [|]
            Delete: |
            Exit: []|
            Space: [ |]
            Visual-L: [v]
            Visual-R: [v]
            Car return: [
            |]

            Open & close: "|"
            Delete: |
            Exit: ""|
            Space: " |"
            Visual: "v"
            Car return: "
            |"

            Open & close: '|'
            Delete: |
            Exit: ''|
            Space: ' |'
            Visual: 'v'
            Car return: '
            |'

            Open & close: `|`
            Delete: |
            Exit: ``|
            Space: ` |`
            Visual: `v`
            Car return: `
            |`
<

==============================================================================
 5. MAPPINGS                                             *delimitMateMappings*

delimitMate doesn't override any existing map, so you may encounter that it
doesn't work as expected because a mapping is missing. In that case, the
conflicting mappings should be resolved by either disabling the conflicting
mapping or creating a custom mappings.

In order to make custom mappings easier and prevent overwritting existing
ones, delimitMate uses the |<Plug>| + |hasmapto()| (|usr_41.txt|) construct
for its mappings.

These are the default mappings:

<BS>         is mapped to <Plug>delimitMateBS
<S-BS>       is mapped to <Plug>delimitMateS-BS
<S-Tab>      is mapped to <Plug>delimitMateS-Tab
<C-G>g       is mapped to <Plug>delimitMateJumpMany
<Del>        is mapped to <Plug>delimitMateDel
<Esc>        is mapped to <Plug>delimitMateEsc
<Left>       is mapped to <Plug>delimitMateLeft
<Right>      is mapped to <Plug>delimitMateRight
<Home>       is mapped to <Plug>delimitMateHome
<End>        is mapped to <Plug>delimitMateEnd
<Up>         is mapped to <Plug>delimitMateUp
<Down>       is mapped to <Plug>delimitMateDown
<PageUp>     is mapped to <Plug>delimitMatePageUp
<PageDown>   is mapped to <Plug>delimitMatePageDown
<S-Down>     is mapped to <Plug>delimitMateS-Down
<S-Up>       is mapped to <Plug>delimitMateS-Up
<LeftMouse>  is mapped to <Plug>delimitMateMLeftMouse
<RightMouse> is mapped to <Plug>delimitMateMRightMouse

The rest of the mappings correspond to parens, quotes, CR, Space, etc. and they
depend on the values of the delimitMate options, they have the following form:

<Plug>delimitMate + char

e.g.: for "(":

( is mapped to <Plug>delimitMate(

e.g.: If you have <CR> expansion enabled, you might want to skip it on pop-up
menus:

    imap <expr> <CR> pumvisible() ?
                     \"\<c-y>" :
                     \ "<Plug>delimitMateCR"


==============================================================================
 6. FUNCTIONS                                           *delimitMateFunctions*

------------------------------------------------------------------------------
delimitMate#WithinEmptyPair()                  *delimitMate#WithinEmptyPair()*

Returns 1 if the cursor is inside an empty pair, 0 otherwise.
e.g.: >

    inoremap <expr> <CR> delimitMate#WithinEmptyPair() ?
             \ "\<C-R>=delimitMate#ExpandReturn()\<CR>" :
             \ "external_mapping"
<

------------------------------------------------------------------------------
delimitMate#ShouldJump()                            *delimitMate#ShouldJump()*

Returns 1 if there is a closing delimiter or a quote to the right of the
cursor, 0 otherwise.

------------------------------------------------------------------------------
delimitMate#JumpAny(key)                               *delimitMate#JumpAny()*

This function returns a mapping that will make the cursor jump to the right
when delimitMate#ShouldJump() returns 1, returns the argument "key" otherwise.
e.g.: You can use this to create your own mapping to jump over any delimiter.
>
   inoremap <C-Tab> <C-R>=delimitMate#JumpAny("\<C-Tab>")<CR>
<

==============================================================================
 7. TODO LIST                                                *delimitMateTodo*

- Automatic set-up by file type.
- Make block-wise visual wrapping work on un-even regions.

==============================================================================
 8. MAINTAINER                                         *delimitMateMaintainer*

Hi there! My name is Israel Chauca F. and I can be reached at:
    mailto:israelchauca@gmail.com

Feel free to send me any suggestions and/or comments about this plugin, I'll
be very pleased to read them.

==============================================================================
 9. CREDITS                                               *delimitMateCredits*

Contributors: ~

  - Kim Silkebækken                                                         ~
    Fixed mappings being echoed in the terminal.

  - Eric Van Dewoestine                                                     ~
    Implemented smart matchpairs.

Some of the code that makes this script was modified or just shamelessly
copied from the following sources:

  - Ian McCracken                                                          ~
    Post titled: Vim, Part II: Matching Pairs:
    http://concisionandconcinnity.blogspot.com/

  - Aristotle Pagaltzis                                                    ~
    From the comments on the previous blog post and from:
    http://gist.github.com/144619

  - Karl Guertin                                                           ~
    AutoClose:
    http://www.vim.org/scripts/script.php?script_id=1849

  - Thiago Alves                                                           ~
    AutoClose:
    http://www.vim.org/scripts/script.php?script_id=2009

  - Edoardo Vacchi                                                         ~
    ClosePairs:
    http://www.vim.org/scripts/script.php?script_id=2373

This script was inspired by the auto-completion of delimiters on TextMate.

==============================================================================
 10. HISTORY                                               *delimitMateHistory*

  Version      Date      Release notes                                       ~
|---------|------------|-----------------------------------------------------|
    2.6     2011-01-14 * Current release:
                         - Add smart_matchpairs feature.
                         - Add mapping to jump over contiguous delimiters.
                         - Fix behaviour of b:loaded_delimitMate.
|---------|------------|-----------------------------------------------------|
    2.5.1   2010-09-30 * - Remove visual wrapping. Surround.vim offers a much
                           better implementation.
                         - Minor mods to DelimitMateTest.
|---------|------------|-----------------------------------------------------|
    2.5     2010-09-22 * - Better handling of mappings.
                         - Add report for mappings in |:DelimitMateTest|.
                         - Allow the use of "|" and multi-byte characters in
                           |'delimitMate_quotes'| and |'delimitMate_matchpairs'|.
                         - Allow commands to be concatenated using |.
|---------|------------|-----------------------------------------------------|
    2.4.1   2010-07-31 * - Fix problem with <Home> and <End>.
                         - Add missing doc on |'delimitMate_smart_quotes'|,
                           |delimitMateBalance| and
                           |'delimitMate_balance_matchpairs'|.
|---------|------------|-----------------------------------------------------|
    2.4     2010-07-29 * - Unbalanced parens: see :help delimitMateBalance.
                         - Visual wrapping now works on block-wise visual
                           with some limitations.
                         - Arrow keys didn't work on terminal.
                         - Added option to allow nested quotes.
                         - Expand Smart Quotes to look for a string on the
                           right of the cursor.

|---------|------------|-----------------------------------------------------|
    2.3.1   2010-06-06 * - Fix: an extra <Space> is inserted after <Space>
                           expansion.

|---------|------------|-----------------------------------------------------|
    2.3     2010-06-06 * - Syntax aware: Will turn off when editing comments
                           or other regions, customizable.
                         - Changed format of most mappings.
                         - Fix: <CR> expansion doesn't brake automatic
                           indentation adjustments anymore.
                         - Fix: Arrow keys would insert A, B, C or D instead
                           of moving the cursor when using Vim on a terminal.

|---------|------------|-----------------------------------------------------|
    2.2     2010-05-16 * - Added command to switch the plug-in on and off.
                         - Fix: some problems with <Left>, <Right> and <CR>.
                         - Fix: A small problem when inserting a delimiter at
                           the beginning of the line.

|---------|------------|-----------------------------------------------------|
    2.1     2010-05-10 * - Most of the functions have been moved to an
                           autoload script to avoid loading unnecessary ones.
                         - Fixed a problem with the redo command.
                         - Many small fixes.

|---------|------------|-----------------------------------------------------|
    2.0     2010-04-01 * New features:
                         - All features are redo/undo-wise safe.
                         - A single quote typed after an alphanumeric
                           character is considered an apostrophe and one
                           single quote is inserted.
                         - A quote typed after another quote inserts a single
                           quote and the cursor jumps to the middle.
                         - <S-Tab> jumps out of any empty pair.
                         - <CR> and <Space> expansions are fixed, but the
                           functions used for it are global and can be used in
                           custom mappings. The previous system is still
                           active if you have any of the expansion options
                           set.
                         - <S-Backspace> deletes the closing delimiter.
                         * Fixed bug:
                         - s:vars were being used to store buffer options.

|---------|------------|-----------------------------------------------------|
    1.6     2009-10-10 * Now delimitMate tries to fix the balancing of single
                         quotes when used as apostrophes. You can read
                         |delimitMate_apostrophes| for details.
                         Fixed an error when |b:delimitMate_expand_space|
                         wasn't set but |delimitMate_expand_space| wasn't.

|---------|------------|-----------------------------------------------------|
    1.5     2009-10-05 * Fix: delimitMate should work correctly for files
                         passed as arguments to Vim. Thanks to Ben Beuchler
                         for helping to nail this bug.

|---------|------------|-----------------------------------------------------|
    1.4     2009-09-27 * Fix: delimitMate is now enabled on new buffers even
                         if they don't have set the file type option or were
                         opened directly from the terminal.

|---------|------------|-----------------------------------------------------|
    1.3     2009-09-24 * Now local options can be used along with autocmd
                         for specific file type configurations.
                         Fixes:
                         - Unnamed register content is not lost on visual
                         mode.
                         - Use noremap where appropiate.
                         - Wrapping a single empty line works as expected.

|---------|------------|-----------------------------------------------------|
    1.2     2009-09-07 * Fixes:
                         - When inside nested empty pairs, deleting the
                         innermost left delimiter would delete all right
                         contiguous delimiters.
                         - When inside an empty pair, inserting a left
                         delimiter wouldn't insert the right one, instead
                         the cursor would jump to the right.
                         - New buffer inside the current window wouldn't
                         have the mappings set.

|---------|------------|-----------------------------------------------------|
    1.1     2009-08-25 * Fixed an error that ocurred when mapleader wasn't
                         set and added support for GetLatestScripts
                         auto-detection.

|---------|------------|-----------------------------------------------------|
    1.0     2009-08-23 * Initial upload.

|---------|------------|-----------------------------------------------------|


  `\|||/´         MMM           \|/            www            __^__          ~
   (o o)         (o o)          @ @           (O-O)          /(o o)\\        ~
ooO_(_)_Ooo__ ooO_(_)_Ooo___oOO_(_)_OOo___oOO__(_)__OOo___oOO__(_)__OOo_____ ~
_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|____ ~
__|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_ ~
_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|____ ~

vim:tw=78:et:ts=2:sw=2:ft=help:norl:formatoptions+=tcroqn:autoindent:
