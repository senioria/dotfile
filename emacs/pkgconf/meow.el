;;; -*- lexical-binding: t; -*-
;; Default setup
(setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

(meow-define-keys 'insert
  '("C-[" . seni/meow/insert-exit)
  '("<escape>" . seni/meow/insert-exit)
  '("ESC" . seni/meow/insert-exit)
  '("RET" . newline-and-indent))
(meow-motion-define-key
 '("j" . meow-next)
 '("k" . meow-prev))
(meow-leader-define-key
 ;; SPC j/k will run the original command in MOTION state.
 '("j" . "H-j")
 '("k" . "H-k")
 ;; Use SPC (0-9) for digit arguments.
 '("1" . meow-digit-argument)
 '("2" . meow-digit-argument)
 '("3" . meow-digit-argument)
 '("4" . meow-digit-argument)
 '("5" . meow-digit-argument)
 '("6" . meow-digit-argument)
 '("7" . meow-digit-argument)
 '("8" . meow-digit-argument)
 '("9" . meow-digit-argument)
 '("0" . meow-digit-argument)
 '("/" . meow-keypad-describe-key)
 '("?" . meow-cheatsheet))
(meow-normal-define-key
 '("0" . meow-expand-0)
 '("9" . meow-expand-9)
 '("8" . meow-expand-8)
 '("7" . meow-expand-7)
 '("6" . meow-expand-6)
 '("5" . meow-expand-5)
 '("4" . meow-expand-4)
 '("3" . meow-expand-3)
 '("2" . meow-expand-2)
 '("1" . meow-expand-1)
 '("-" . negative-argument)
 '(";" . meow-reverse)
 '("," . meow-inner-of-thing)
 '("." . meow-bounds-of-thing)
 '("<" . meow-beginning-of-thing)
 '(">" . meow-end-of-thing)
 '("[" . seni/meow/ts-node-prev)
 '("]" . seni/meow/ts-node-next)
 '("a" . meow-append)
 '("A" . meow-open-below)
 '("b" . meow-back-word)
 '("B" . meow-back-symbol)
 '("c" . meow-change)
 '("d" . meow-delete)
 '("D" . meow-backward-delete)
 '("e" . meow-next-word)
 '("E" . meow-next-symbol)
 '("f" . meow-find)
 '("F" . avy-goto-char)
 '("g" . meow-cancel-selection)
 '("G" . meow-grab)
 '("h" . meow-left)
 '("H" . meow-page-up)
 '("i" . meow-insert)
 '("I" . meow-open-above)
 '("j" . meow-next)
 '("J" . scroll-down-line)
 '("k" . meow-prev)
 '("K" . scroll-up-line)
 '("l" . meow-right)
 '("L" . meow-page-down)
 '("m" . meow-join)
 '("n" . meow-search)
 '("o" . meow-tree-sitter-node)
 '("O" . seni/meow/extend-to-lines)
 '("p" . meow-yank)
 '("q" . imenu)
 '("Q" . seni/meow/quick-kmacro)
 '("r" . meow-replace)
 '("R" . meow-swap-grab)
 '("s" . meow-kill)
 '("t" . meow-till)
 '("u" . meow-undo)
 '("U" . vundo)
 '("v" . meow-visit)
 '("w" . meow-mark-word)
 '("W" . meow-mark-symbol)
 '("x" . meow-line)
 '("X" . meow-goto-line)
 '("y" . meow-save)
 '("Y" . meow-sync-grab)
 '("z" . meow-pop-selection)
 '("=" . seni/meow/indent)
 '("<escape>" . keyboard-quit))

;; Action helper functions
(defun seni/meow/insert-exit ()
  (interactive)
  (if smartparens-mode (meow-paren-mode) (meow-insert-exit)))

(defun seni/meow/quick-kmacro ()
  (interactive)
  (if defining-kbd-macro
      (meow-end-or-call-kmacro)
    (meow-beacon-start)))

(defun seni/meow/ts-node-step/raw (n)
  (when-let*
      ((orig (point))
       (boundary-func
        (if (> n 0)
            (lambda (cur) (< (treesit-node-start cur) orig))
          (lambda (cur) (> (treesit-node-end cur) orig))))
       (node (treesit-node-at orig))
       (node
        (named-let step ((cur node) (prev node))
          (if (or
               (null cur)
               (funcall boundary-func cur)
               (equal cur (treesit-buffer-root-node)))
              prev
            (step (treesit-node-parent cur) cur))))
       (next-func (if (> n 0) #'treesit-node-next-sibling #'treesit-node-prev-sibling))
       (next
        (cl-loop
         for cur = node then
         (named-let step ((node cur)
                          (next (funcall next-func node)))
           (if next next
             (when-let ((par (treesit-node-parent node)))
               (step par (funcall next-func par)))))
         repeat (abs n)
         finally return cur))
       (p (treesit-node-start next)))
    p))

(defun seni/meow/ts-node-next-1 ()
  (when-let ((p (seni/meow/ts-node-step/raw 1)))
    (goto-char p)))
(defun seni/meow/ts-node-prev-1 ()
  (when-let ((p (seni/meow/ts-node-step/raw -1)))
    (goto-char p)))

(defun seni/meow/ts-node-next (n)
  (interactive "p")
  (when-let
      ((orig (point))
       (p (seni/meow/ts-node-step/raw n)))
    (thread-first
     (meow--make-selection '(expand . symbol) orig p nil)
     (meow--select t))
    (meow--maybe-highlight-num-positions '(seni/meow/ts-node-prev-1 . seni/meow/ts-node-next-1))))
(defun seni/meow/ts-node-prev (n)
  (interactive "p")
  (seni/meow/ts-node-next (- n)))

(defun seni/meow/indent (&optional start end)
  (interactive)
  (let* ((sel (if (region-active-p)
                  `(,(point-marker) ,(mark-marker))
                `(,(line-beginning-position) ,(line-end-position))))
         (start (or start (min (car sel) (cadr sel))))
         (end (or end (max (car sel) (cadr sel)))))
    (indent-region start end)))

(defun seni/meow/extend-to-lines (&optional start end)
  (interactive)
  (pcase-let*
      ((`(,sel-point ,sel-mark)
        (if (region-active-p)
            `(,(point-marker) ,(mark-marker))
          `(,(line-beginning-position) ,(line-end-position))))
       (start (save-excursion
                (goto-char (or start (min sel-point sel-mark)))
                (line-beginning-position)))
       (end (save-excursion
              (goto-char (or end (max sel-point sel-mark)))
              (line-end-position)))
       (`(,point, mark)
        (if (and (region-active-p) (not (or start end)))
            (if (<= sel-point sel-mark) `(,start ,end) `(,end ,start))
          `(,end ,start))))
    (thread-first
      (meow--make-selection '(expand . line) mark point nil)
      (meow--select t))))

;; Window and tab switching
(define-prefix-command 'window-and-tab-bar-map)
(global-set-key (kbd "C-t") 'window-and-tab-bar-map)
(add-to-list 'meow-keypad-start-keys '(?t . ?t))
(dolist (key '(
               ("0" delete-window)
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

;; Input method
;; @seni/meow/last-imstate: Whether emacs IM enabled in insert mode
;; @seni/meow/last-sys-imstate: Fcitx5 state (0/1 for inactivative, 2 for activative)
(setq-default seni/meow/last-imstate nil)
(setq-default seni/meow/last-sys-imstate nil)

(defmacro seni/meow/fcitx5-controller (fun &optional var &rest body)
  (declare (indent 2) (debug (symbolp body)))
  (require 'dbus)
  (let ((cb (cond
             (body `(lambda (,var) ,@body))
             (var var)
             (t `nil))))
    `(dbus-call-method-asynchronously
      :session "org.fcitx.Fcitx5" "/controller" "org.fcitx.Fcitx.Controller1" ,fun ,cb)))

(defun seni/meow/record-im ()
  (delete-trailing-whitespace (pos-bol) (pos-eol))
  (seni/meow/fcitx5-controller "State" im
    (setq-local seni/meow/last-sys-imstate im)
    (when (eq im 2) (seni/meow/fcitx5-controller "Deactivate")))
  (if current-input-method
      (progn
        (setq-local seni/meow/last-imstate current-input-method)
        (set-input-method nil))
    (setq-local seni/meow/last-imstate nil)))
(add-hook 'meow-insert-exit-hook #'seni/meow/record-im)

(defun seni/meow/recover-im ()
  (when (and (boundp 'seni/meow/last-sys-imstate) (eq seni/meow/last-sys-imstate 2))
    (seni/meow/fcitx5-controller "Activate"))
  (when (bound-and-true-p seni/meow/last-imstate)
    (set-input-method seni/meow/last-imstate)))
(add-hook 'meow-insert-enter-hook #'seni/meow/recover-im)

;; Config for specified modes
(defun seni/meow/disable ()
  (when (bound-and-true-p meow-mode) (meow-mode -1)))
(defun seni/meow/custom-mode-spc ()
  (interactive)
  (if (and (widget-at (point)) (get-text-property (point) 'field))
      (self-insert-command)
    (meow-keypad)))
(defun seni/meow/major-dispatch ()
  (pcase major-mode
    ('debugger-mode (seni/meow/disable))
    ('sldb-mode (meow-insert-mode))
    ('Custom-mode (seni/meow/disable)
                  (define-key custom-mode-map (kbd "SPC") #'seni/meow/custom-mode-spc)))
  (when (bound-and-true-p smartparens-mode) (meow-paren-mode)))
(add-hook 'meow-mode-hook #'seni/meow/major-dispatch)

;; Enable
(meow-global-mode 1)
