;extends
; Mockup 01: singletons and attached types used as objects (Theme.…, Niri.…, Qt.…) and ids (id: root, root.…,
; parent.…) in asagi (@module, t6) instead of the gold that ecma gives every capitalised identifier.
(member_expression
  object: (identifier) @module
  (#lua-match? @module "^[A-Z]")
  (#set! priority 105))

(ui_binding
  name: (identifier) @_key
  value: (expression_statement
    (identifier) @module)
  (#eq? @_key "id")
  (#set! priority 105))

(member_expression
  object: (identifier) @module
  (#any-of? @module "root" "parent")
  (#set! priority 105))
