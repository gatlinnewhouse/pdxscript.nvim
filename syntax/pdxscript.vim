if exists("b:current_syntax")
  finish
endif

" Patch operations
syntax match   pdxPatchOp    /\<\(REPLACE\|INJECT\|REMOVE\|ADD\|INSERT\|MODIFY\):/

" Logic keywords
syntax keyword pdxLogic      AND OR NOT if else_if else
syntax keyword pdxLogicBlock limit trigger effect potential allow

" Scope iterators
syntax match   pdxScope      /\<\(every\|any\|ordered\|random\)_[a-zA-Z_]\+/

" Effects (imperative verbs)
syntax match   pdxEffect     /\<\(add\|remove\|set\|create\|destroy\|kill\|change\|activate\|deactivate\|trigger\|move\|transfer\|annex\|integrate\)_[a-zA-Z_]\+/

" Triggers (query predicates)
syntax match   pdxTrigger    /\<\(has\|is\|can\|owns\|exists\|controls\|check\|was\)_[a-zA-Z_]\+/

" Variables, macros, directives
syntax match   pdxDirective  /@:[a-zA-Z_]\+/
syntax match   pdxVariable   /@[a-zA-Z_][a-zA-Z0-9_.]*/
syntax region  pdxCalcExpr   start=/@\[/ end=/\]/
syntax match   pdxMacroParam /\$[A-Z_][A-Z0-9_]*\$/

" Primitives
syntax match   pdxComment    /#.*/
syntax region  pdxString     start=/"/ end=/"/ skip=/\\"/
syntax match   pdxNumber     /\<-\?\d\+\(\.\d\+\)\?\>/
syntax keyword pdxBoolean    yes no true false
syntax match   pdxComparator /[?!<>]=/
syntax match   pdxComparator /[<>]/
syntax match   pdxBrace      /[{}]/

" Generic key (fallback, lower priority)
syntax match   pdxKey        /^\s*[a-zA-Z_][a-zA-Z0-9_.]*\s*\ze[?!<>]*=/

hi def link pdxComment    Comment
hi def link pdxString     String
hi def link pdxNumber     Number
hi def link pdxBoolean    Boolean
hi def link pdxVariable   Identifier
hi def link pdxMacroParam Macro
hi def link pdxDirective  PreProc
hi def link pdxComparator Operator
hi def link pdxBrace      Delimiter
hi def link pdxKey        Keyword
hi def link pdxCalcExpr   Special
hi def link pdxPatchOp    WarningMsg
hi def link pdxLogic      Conditional
hi def link pdxLogicBlock Structure
hi def link pdxScope      Repeat
hi def link pdxEffect     Function
hi def link pdxTrigger    Type

let b:current_syntax = "pdxscript"
