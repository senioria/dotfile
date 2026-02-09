(setq markdown-command "pandoc")
(defun seni/md/start-hook ()
  (when (fboundp 'company-mode)
    (company-mode -1))
  )
(add-hook 'markdown-mode-hook #'seni/md/start-hook)

