(defmacro seni/lsp/with-current-project (name &rest body)
  (declare (indent 1) (debug (symbolp body)))
  `(when-let* ((pr (project-current))
               (,name (project-root pr)))
     ,@body))

(defvar seni/lsp/project-list '())
(defun seni/lsp/autostart ()
  (seni/lsp/with-current-project pr
    (when (member pr seni/lsp/project-list)
      (lsp))))

(defun seni/lsp/hook-enable-project (&optional lsp-arg)
  (add-hook (intern (format "%s-hook" major-mode)) #'seni/lsp/autostart)
  (seni/lsp/with-current-project pr
    (add-to-list 'seni/lsp/project-list pr)))
(defun seni/lsp/hook-shutdown (&optional lsp-arg)
  (seni/lsp/with-current-project pr
    (setq seni/lsp/project-list (delete pr seni/lsp/project-list))))

(advice-add 'lsp :before #'seni/lsp/hook-enable-project)
(advice-add 'lsp-workspace-shutdown :before #'seni/lsp/hook-shutdown)

(defun seni/lsp/python-mode-hook () (require 'lsp-pyright))
(add-hook 'python-mode-hook #'seni/lsp/python-mode-hook)

(seni/lsp/hook-enable-project)  ;; Enable for current major mode
