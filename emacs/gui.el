;; Colorscheme  -*- lexical-binding: t; -*-
(load-theme 'everforest-hard-light t)
;; GUI components
(tool-bar-mode 0)
(menu-bar-mode 0)

;; Fonts
(setq face-font-rescale-list '(("WenQuanYi Zen Hei" . 1.2)))
(setq font-use-system-font t)
(add-to-list 'default-frame-alist
             '(font . "Iosevka Custom 10"))
;(set-fontset-font t '(#x4e00 . #x9fff) "WenQuanYi Zen Hei")

