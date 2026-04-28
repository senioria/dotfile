;; The mirror of custom variables
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ein:jupyter-server-use-subcommand "server")
 '(ein:output-area-inlined-images t)
 '(imenu-flatten 'prefix)
 '(indent-bars-treesit-support t)
 '(inhibit-startup-screen t)
 '(lsp-fsharp-use-dotnet-tool-for-fsac nil)
 '(lsp-keymap-prefix "C-c C-l")
 '(lsp-semantic-tokens-enable t)
 '(lsp-semantic-tokens-honor-refresh-requests t)
 '(lsp-treemacs-error-list-expand-depth 10)
 '(lsp-ui-doc-alignment 'window)
 '(lsp-ui-doc-enhanced-markdown nil)
 '(lsp-ui-doc-max-height 30)
 '(lsp-ui-doc-max-width 80)
 '(lsp-ui-doc-position 'bottom)
 '(lsp-ui-doc-show-with-cursor t)
 '(lsp-ui-sideline-diagnostic-max-lines 3)
 '(lsp-ui-sideline-ignore-duplicate t)
 '(lsp-ui-sideline-show-code-actions t)
 '(lsp-ui-sideline-show-hover t)
 '(lsp-ui-sideline-wait-for-all-symbols nil)
 '(make-backup-files nil)
 '(markdown-enable-highlighting-syntax t)
 '(markdown-enable-math t)
 '(markdown-fontify-code-blocks-natively t)
 '(markdown-header-scaling t)
 '(org-export-backends '(ascii html icalendar latex md odt))
 '(org-format-latex-options
   '(:foreground default :background default :scale 2.0 :html-foreground "Black" :html-background "Transparent" :html-scale
                 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
 '(package-selected-packages
   '(agent-shell-sidebar cape corfu direnv everforest-theme flycheck fsharp-mode indent-bars lsp-pyright lsp-treemacs
                         lsp-ui magit marginalia meow-tree-sitter orderless org-fragtog ox-gfm powerline rime rust-mode
                         signa slime smartparens switch-window treesit-auto tuareg vertico visual-fill-column vundo
                         yaml-mode))
 '(package-vc-selected-packages
   '((agent-shell-sidebar :url "https://github.com/cmacrae/agent-shell-sidebar")
     (everforest-theme :url "https://github.com/theorytoe/everforest-emacs.git")))
 '(smtpmail-smtp-server "localhost")
 '(smtpmail-smtp-service 1025)
 '(telega-server-libs-prefix "/usr")
 '(truncate-lines nil)
 '(truncate-partial-width-windows 30)
 '(warning-minimum-level :error))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(markdown-code-face ((t (:inherit normal))))
 '(markdown-header-face-1 ((t (:inherit markdown-header-face :height 2.0))))
 '(markdown-header-face-2 ((t (:inherit markdown-header-face :height 1.6))))
 '(markdown-header-face-3 ((t (:inherit markdown-header-face :height 1.2)))))
