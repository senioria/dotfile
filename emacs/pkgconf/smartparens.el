(require 'smartparens-config)

(setq meow-paren-keymap (define-keymap :parent meow-normal-state-keymap))
(meow-define-state paren
  "Meow state for parens editing"
  :lighter "[NP]"
  :keymap meow-paren-keymap)

(defun seni-meow-paren-kill ()
  (interactive)
  (if (region-active-p) (meow-kill) (sp-kill-sexp)))

(meow-define-keys 'paren
  '("]" . sp-down-sexp)
  '("[" . sp-up-sexp)
  '("{" . meow-beginning-of-thing)
  '("}" . meow-end-of-thing)
  '("e" . sp-next-sexp)
  '("b" . sp-previous-sexp)
  '("<" . sp-beginning-of-sexp)
  '(">" . sp-end-of-sexp)
  '("s" . seni-meow-paren-kill))

(sp-with-modes sp-lisp-modes
  (sp-local-pair "[" "]" :unless '(sp-in-string-p))
  (sp-local-pair "{" "}" :unless '(sp-in-string-p sp-in-comment-p))
  (sp-local-pair "(" ")" :unless '(sp-in-string-p sp-in-comment-p)))

(defun seni/sp/start-hook () (meow-paren-mode) (smartparens-strict-mode))
(add-hook 'smartparens-mode-hook #'seni/sp/start-hook)

