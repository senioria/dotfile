(defun seni-lsp-hook-auto-enable (&optional lsp-arg)
  (add-hook (intern (format "%s-hook" major-mode)) #'lsp))
(advice-add 'lsp :before #'seni-lsp-hook-auto-enable)
(seni-lsp-hook-auto-enable)  ;; Enable for current major mode
