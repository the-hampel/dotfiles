set textwidth=0
let fortran_free_source=1
let fortran_have_tabs=1
let fortran_more_precise=1
let fortran_do_enddo=1
let fortran_CUDA=1

"match every whole word *assert*
syntax match unitTestKeyword '\<assert\>'
"match all *test_* if they are preceeded by *subroutine*
syntax match unitTestKeyword '\(subroutine\s*\)\@<=test_'
"hightlight unit test keywords in the same way as Fortran keywords
highlight link unitTestKeyword fortranKeyword

syn region fortranDirective start=/!$ACC.\{-}/ end=/[^\&]$/
hi def link fortranDirective PreProc

