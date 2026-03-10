(require 'smartparens-config)

(setq meow-paren-keymap (define-keymap :parent meow-normal-state-keymap))
(meow-define-state paren
  "Meow state for parens editing"
  :lighter "[NP]"
  :keymap meow-paren-keymap)

(defun seni/meow/paren/kill ()
  (interactive)
  (if (region-active-p) (meow-kill) (sp-kill-sexp)))

(defun seni/meow/paren/wrap ()
  (interactive)
  (when-let*
      ((pairs
        (cl-loop
         for pair in sp-local-pairs
         for open = (plist-get pair :open)
         for close = (plist-get pair :close)
         when (not (null close))
         collect `(,(format "%s%s" open close) . ,open)))
       (selected (completing-read "Wrap with pair: " pairs nil t))
       (selpair (cdr (assoc selected pairs))))
    (sp-wrap-with-pair selpair)))

(meow-define-keys 'paren
  '("]" . sp-down-sexp)
  '("[" . sp-up-sexp)
  '("}" . seni/meow/paren/wrap)
  '("{" . sp-unwrap-sexp)
  '("e" . sp-next-sexp)
  '("b" . sp-previous-sexp)
  '("s" . seni/meow/paren/kill))

(sp-with-modes sp-lisp-modes
  (sp-local-pair "[" "]" :unless '(sp-in-string-p))
  (sp-local-pair "{" "}" :unless '(sp-in-string-p sp-in-comment-p))
  (sp-local-pair "(" ")" :unless '(sp-in-string-p sp-in-comment-p)))

(defun seni/sp/start-hook () (meow-paren-mode) (smartparens-strict-mode))
(add-hook 'smartparens-mode-hook #'seni/sp/start-hook)

