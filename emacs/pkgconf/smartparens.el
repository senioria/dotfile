;; -*- lexical-binding: t; -*-
(require 'smartparens-config)

(sp-with-modes sp-lisp-modes
  (sp-local-pair "[" "]" :unless '(sp-in-string-p))
  (sp-local-pair "{" "}" :unless '(sp-in-string-p sp-in-comment-p))
  (sp-local-pair "(" ")" :unless '(sp-in-string-p sp-in-comment-p)))

(defun seni/sp/start-hook () (smartparens-strict-mode))
(add-hook 'smartparens-mode-hook #'seni/sp/start-hook)
