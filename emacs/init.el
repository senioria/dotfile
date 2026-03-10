;;; -*- lexical-binding: t; -*-
;; Set the custom file
(setq custom-file "~/.emacs.d/custom.el")
(load-file custom-file)

;; Load local configs
(setq dotdir (file-name-directory load-file-name))
(dolist (f '("packages.el" "ftplugin.el"))
  (load-file (concat dotdir f)))
(load-file (concat dotdir (if (display-graphic-p) "gui.el" "tui.el")))

;; Configs
(setq-default truncate-lines t)
(global-display-line-numbers-mode t)
(show-paren-mode)

(setq-default indent-tabs-mode nil)
(setq-default fill-column 120)
(setq-default auto-fill-function 'do-auto-fill)
(global-display-fill-column-indicator-mode t)
(global-set-key (kbd "s-SPC") 'ignore)

(use-package powerline)
(powerline-default-theme)

;; switch-window
(require 'switch-window)
;; tab bar mode
(tab-bar-mode t)

;; Fuzzy completion
(setq-default completion-styles '(flex orderless partial-completion))
