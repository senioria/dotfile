;;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'signa-action)
(require 'signa-coop)

(eval `(signa-define-keys 'normal ,@signa-qwerty-map-definition-normal-state))
(eval `(signa-define-keys 'insert ,@signa-map-definition-insert-state))

(defun seni/signa/indent (&optional start end)
  (interactive)
  (let* ((sel (if (region-active-p)
                  (list (point) (mark))
                (list (line-beginning-position) (line-end-position))))
         (start (or start (apply #'min sel)))
         (end (or end (apply #'max sel))))
    (indent-region start end)))

(defvar-local seni/signa/last-imstate nil)
(defvar-local seni/signa/last-sys-imstate nil)

(defun seni/signa/record-im ()
  (delete-trailing-whitespace (pos-bol) (pos-eol))
  (when (require 'dbus nil t)
    (ignore-errors
      (dbus-call-method-asynchronously
       :session "org.fcitx.Fcitx5"
       "/controller"
       "org.fcitx.Fcitx.Controller1"
       "State"
       (lambda (im)
         (setq-local seni/signa/last-sys-imstate im)
         (when (eq im 2)
           (ignore-errors
             (dbus-call-method-asynchronously
              :session "org.fcitx.Fcitx5"
              "/controller"
              "org.fcitx.Fcitx.Controller1"
              "Deactivate"
              nil)))))))
  (if current-input-method
      (progn
        (setq-local seni/signa/last-imstate current-input-method)
        (set-input-method nil))
    (setq-local seni/signa/last-imstate nil)))

(defun seni/signa/recover-im ()
  (when (and (require 'dbus nil t) (eq seni/signa/last-sys-imstate 2))
    (ignore-errors
      (dbus-call-method-asynchronously
       :session "org.fcitx.Fcitx5"
       "/controller"
       "org.fcitx.Fcitx.Controller1"
       "Activate"
       nil)))
  (when (bound-and-true-p seni/signa/last-imstate)
    (set-input-method seni/signa/last-imstate)))

(add-hook 'signa-insert-enter-hook #'seni/signa/recover-im)
(add-hook 'signa-insert-exit-hook #'seni/signa/record-im)

(defun seni/signa/major-dispatch ()
  (when (bound-and-true-p signa-mode)
    (pcase major-mode
      ('debugger-mode (signa-mode -1))
      ('sldb-mode (signa-start-insert))
      ('Custom-mode (signa-mode -1))
      ('vundo-mode (signa-mode -1))
      ('ediff-mode (signa-mode -1)))))
(add-hook 'signa-mode-hook #'seni/signa/major-dispatch)

(signa-define-keys 'insert
  '("ESC" . signa-escape-to-normal)
  '("RET" . newline-and-indent))

(signa-define-keys 'normal
  '("U" . vundo)
  '("q" . imenu)
  '("F" . avy-goto-char)
  '("=" . seni/signa/indent))

(define-prefix-command 'window-and-tab-bar-map)
(global-set-key (kbd "C-t") 'window-and-tab-bar-map)
(dolist (key '(("0" delete-window)
               ("1" delete-other-windows)
               ("2" split-window-below)
               ("3" split-window-right)
               ("d" switch-window-then-delete)
               ("t" previous-window)
               ("o" switch-window)
               ("c" tab-bar-new-tab)
               ("w" tab-bar-close-tab)
               ("n" tab-bar-switch-to-next-tab)
               ("p" tab-bar-switch-to-prev-tab)
               ("b" switch-to-buffer)))
  (define-key window-and-tab-bar-map (kbd (car key)) (cadr key)))

(signa-global-mode 1)
