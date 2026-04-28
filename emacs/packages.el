;; Init packages
(require 'package)
(setq package-archives
      '(("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
        ("elpa" . "http://mirrors.ustc.edu.cn/elpa/gnu/")
        ("melpa-orig" . "https://melpa.org/packages/")))
(package-initialize)
(setf package-selected-packages
      (cl-union
       package-selected-packages
       `(powerline treemacs use-package markdown-mode meow switch-window org-fragtog vertico orderless corfu cape marginalia slime smartparens rime lsp-mode lsp-treemacs rust-mode yaml-mode)))

;; Check for uninstalled packages and install them
(let ((package-install-list (seq-remove #'package-installed-p package-selected-packages)))
  (unless (eq nil package-install-list)
    (package-refresh-contents)
    (package-install-selected-packages)))

(require 'use-package)

;; Individual package config
(use-package everforest-theme
  :vc (:url "https://github.com/theorytoe/everforest-emacs.git" :rev :newest))

(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :config (load-file (concat dotdir "pkgconf/markdown.el")))

(use-package rust-mode
  :mode (("\\.rs\\'" . rust-mode)))

(use-package yaml-mode
  :mode (("\\.ya?ml\\'" . yaml-mode)))

(use-package indent-bars
  :defer t
  :hook
  (((python-mode python-ts-mode) . #'indent-bars-mode))
  :config
  (set-face-extend 'line-number t))

(use-package visual-fill-column
  :defer t
  :config
  (add-hook 'visual-line-mode-hook #'visual-fill-column-for-vline))

(use-package treesit-auto
  :custom (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(use-package rime
  :defer t
  :hook (markdown-mode org-mode telega-load)
  :config
  (add-hook 'markdown-mode-hook (lambda () (setq-local seni-meow-last-imstate "rime")))
  (add-hook 'telega-chat-mode-hook
            (lambda () (setq-local seni-meow-last-imstate "rime"))))

(use-package treemacs
  :defer t
  :config (load-file (concat dotdir "pkgconf/treemacs.el")))
(use-package lsp-treemacs
  :defer t)

(use-package magit
  :defer t
  :config
  (transient-suffix-put 'magit-dispatch "k" :key "\\"))

(use-package vertico
  :init (vertico-mode))
(use-package marginalia
  :init (marginalia-mode))

(use-package savehist
  :init (savehist-mode))
(use-package corfu
  :ensure t
  :init
  (setq tab-always-indent 'complete)
  (global-corfu-mode)
  (when (fboundp 'global-company-mode) (global-company-mode -1))
  :custom (corfu-auto t)
  (corfu-cycle t)
  (corfu-preselect 'first)
  (corfu-popupinfo-mode t)
  (corfu-quit-no-match t))

(use-package cape
  :config)

(use-package lsp-mode
  :defer t
  :custom
  (lsp-completion-provider :none)
  :init
  (defun seni-lsp-setup-completion ()
    (setf (alist-get 'styles (alist-get 'lsp-capf completion-category-defaults))
          '(orderless partial-completion)))
  :hook
  (lsp-completion-mode . seni-lsp-setup-completion)
  :config
  (load-file (concat dotdir "pkgconf/lsp.el")))

(use-package lsp-ui
  :defer t
  :after lsp-mode
  :custom-face
  (lsp-ui-doc-background ((t (:background nil :inherit hl-line)))))

(use-package flycheck
  :defer t
  :ensure nil
  :config
  (add-to-list 'display-buffer-alist
             `(,(rx bos "*Flycheck errors*" eos)
              (display-buffer-reuse-window
               display-buffer-in-side-window)
              (side            . bottom)
              (reusable-frames . visible)
              (window-height   . 0.20))))

(use-package telega
  :defer t
  :config
  (define-advice telega-chars-xheight
      (:around (orig n) seni-fix)
    (+ (funcall orig n) (* n 10)))
  (telega-notifications-mode)
  (define-key telega-chat-mode-map (kbd "C-<return>") #'telega-chatbuf-newline-or-input-send)
  (defun seni-telega-chat-config ()
    (auto-fill-mode -1))
  (add-hook 'telega-chat-mode-hook #'seni-telega-chat-config))

(use-package slime
  :defer t
  :config
  (setq slime-lisp-implementations '((sbcl ("/usr/bin/sbcl"))))
  (setq inferior-lisp-program "sbcl")
  (slime-setup '(slime-fancy slime-quicklisp slime-asdf))
  (dolist (mode '(meow-normal-mode meow-insert-mode meow-paren-mode))
    (let ((meow-keys (assq mode minor-mode-map-alist)))
      (assq-delete-all mode minor-mode-map-alist)
      (add-to-list 'minor-mode-map-alist meow-keys))))

(use-package meow
  :config (load-file (concat dotdir "pkgconf/meow.el")))
(use-package meow-tree-sitter
  :init (meow-tree-sitter-register-defaults))

(use-package avy
  :defer t
  :config
  (avy-setup-default))

(use-package vundo
  :defer t
  :config
  (setq vundo-glyph-alist vundo-unicode-symbols))

(use-package slime-company
  :defer t
  :ensure nil
  :after (slime corfu)
  :config
  (setq slime-company-completion 'fuzzy
        slime-company-after-completion 'slime-company-just-one-space)
  (defvar seni-slime-capf (cape-company-to-capf #'company-slime))
  (defun seni-slime-cape-enable ()
    (add-to-list 'completion-at-point-functions seni-slime-capf))
  (dolist (h '(slime-mode-hook slime-repl-mode-hook))
    (add-hook h 'seni-slime-cape-enable t)))

(use-package smartparens
  :hook (emacs-lisp-mode lisp-mode scheme-mode slime-repl-mode slime-mrepl-mode)
  :config (load-file (concat dotdir "pkgconf/smartparens.el")))

(add-hook 'org-mode-hook 'org-fragtog-mode)

