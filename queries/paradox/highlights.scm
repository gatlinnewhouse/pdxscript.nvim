; extends

(string) @string
(comment) @comment
(number) @number
(boolean) @constant.builtin

(identifier) @variable
(variable) @variable.parameter   ; $MACRO$ params

(condition_keyword) @keyword.control
(logical_keyword) @keyword.operator
(scope_keyword) @variable.builtin

; assignment keys
(assignment key: (identifier) @variable.member)

; block braces
"{" @punctuation.bracket
"}" @punctuation.bracket
"=" @operator
