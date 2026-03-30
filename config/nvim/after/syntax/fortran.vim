setlocal textwidth=0

"match every whole word *assert*
syntax match unitTestKeyword '\<assert\>'
"match all *test_* if they are preceeded by *subroutine*
syntax match unitTestKeyword '\(subroutine\s*\)\@<=test_'
"hightlight unit test keywords in the same way as Fortran keywords
highlight link unitTestKeyword fortranKeyword

syn region fortranDirective start=/!$ACC.\{-}/ end=/[^\&]$/
hi def link fortranDirective PreProc

syn region fortranDirective start=/!$OMP.\{-}/ end=/[^\&]$/
hi def link fortranDirective PreProc
