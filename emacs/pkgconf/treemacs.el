(when (display-graphic-p)
    (let* ((face (face-attribute 'default :font))
           (pxheight (aref (font-info face) 2)))
      (treemacs-resize-icons (truncate (* pxheight 0.8)))))

(defun seni-treemacs-visit-node-tab (&optional arg)
  (interactive "P")
  (run-hook-with-args
   'treemacs-after-visit-functions
   (treemacs--execute-button-action
    :split-function #'tab-bar-new-tab
    :split-function #'split-window-horizontally
    :file-action (find-file (treemacs-safe-button-get btn :path))
    :dir-action (dired (treemacs-safe-button-get btn :path))
    :tag-section-action (treemacs--visit-or-expand/collapse-tag-node btn arg nil)
    :tag-action (treemacs--goto-tag btn)
    :window-arg arg
    :no-match-explanation "Node is neither a file, a directory or a tag - nothing to do here.")))
(keymap-set treemacs-node-visit-map (kbd "t") 'seni-treemacs-visit-node-tab)

