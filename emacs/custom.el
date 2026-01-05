;; The mirror of custom variables
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ein:jupyter-server-use-subcommand "server")
 '(ein:output-area-inlined-images t)
 '(evil-undo-system 'undo-redo)
 '(inhibit-startup-screen t)
 '(lsp-fsharp-use-dotnet-tool-for-fsac nil)
 '(lsp-keymap-prefix "C-c C-l")
 '(lsp-semantic-tokens-allow-delta-requests nil)
 '(lsp-semantic-tokens-enable t)
 '(lsp-semantic-tokens-honor-refresh-requests t)
 '(make-backup-files nil)
 '(markdown-enable-highlighting-syntax t)
 '(markdown-enable-math t)
 '(markdown-fontify-code-blocks-natively t)
 '(markdown-header-scaling t)
 '(org-format-latex-options
   '(:foreground default :background default :scale 2.0 :html-foreground "Black" :html-background "Transparent" :html-scale
                 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
 '(package-packages-selected
   '(cape company corfu ein ement f flycheck fsharp-mode jupyter lsp-mode lsp-treemacs magit-section marginalia
          markdown-mode meow orderless powerline rime slime slime-company smartparens solarized-theme switch-window
          telega treemacs tuareg use-package vertico))
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
