;; -*- lexical-binding: t; -*-
(require 'dbus)
(require 'eshell)
(require 'notifications)

(defun seni/agentsh/hook ()
  (display-line-numbers-mode -1)
  (display-fill-column-indicator-mode -1)
  (auto-fill-mode -1)
  (setq seni/agentsh/notification-subscription
        (agent-shell-subscribe-to
         :shell-buffer (current-buffer)
         :on-event #'seni/agentsh/handle-event)))
(add-hook 'agent-shell-mode-hook #'seni/agentsh/hook)

(defvar-local seni/agentsh/notification-subscription nil
  "Subscription token for agent-shell desktop notifications.")
(defvar-local seni/agentsh/notification-list nil
  "The list of notifications in the buffer")

(defun seni/agentsh/get-dbus-bus ()
  (let* ((env (frame-parameter nil 'environment)) ; Yes, to selected frame to show to the user
         (env-str "DBUS_SESSION_BUS_ADDRESS=")
         (bus-str (car (member-if (lambda (s) (string-prefix-p env-str s)) env)))
         (bus (ignore-errors (substring bus-str (length env-str)))))
    (when bus (dbus-init-bus bus))
    (or bus :session)))

(defun seni/agentsh/clear-notification (frame &optional win)
  (let ((bus (seni/agentsh/get-dbus-bus)))
    (dolist (notif seni/agentsh/notification-list)
      (notifications-close-notification notif bus)))
  (setq seni/agentsh/notification-list nil)
  (remove-hook 'window-selection-change-functions #'seni/agentsh/clear-notification t))
(defun seni/agentsh/notify (summary body)
  "Send a desktop notification with SUMMARY and BODY over D-Bus."
  (let ((bus (seni/agentsh/get-dbus-bus)))
    (unless (eq (current-buffer) (window-buffer (selected-window)))
      (condition-case err
          (push
           (notifications-notify
            :bus (or bus :session)
            :title summary :body body :urgency 'normal :timeout 30000)
           seni/agentsh/notification-list)
        (error
         (message "Error sending notification: %s" err)))
      (add-hook 'window-selection-change-functions #'seni/agentsh/clear-notification 0 t))))

(defvar-local seni/agentsh/permission-pending nil
  "The pending list for permissions and their info")

(defun seni/agentsh/handle-event (event)
  "Send desktop notifications for relevant agent-shell EVENTs."
  (pcase (map-elt event :event)
    ('turn-complete
     (seni/agentsh/notify
      "Agent turn complete"
      (format "%s is ready for input again."
              (buffer-name (current-buffer)))))
    ('tool-call-update
     (when-let*
         ((data (map-elt event :data))
          (call-id (map-elt data :tool-call-id))
          (call (map-elt data :tool-call))
          (info (assoc call-id seni/agentsh/permission-pending))
          ((string= (map-elt call :status) "in_progress")))
       (message "update call %s" call-id)
       (condition-case err
           (if (seni/agentsh/auto-permit call)
               (progn
                 (message "info: %s on client %s" info
                          (map-elt (agent-shell--state) :client))
                 (agent-shell--send-permission-response
                  :client (map-elt (agent-shell--state) :client)
                  :request-id (map-elt info :request-id)
                  :option-id (map-elt info :allow-option)
                  :tool-call-id call-id
                  :state (agent-shell--state))
                 (message "auto permitted for %s: %s" call-id
                          (map-elt call :command)))
             (seni/agentsh/notify
              "Agent needs permission"
              (format "%s is waiting for permission: %s"
                      (buffer-name (current-buffer))
                      (or (map-elt call :title) "(untitled tool call)")))
             (message "notify for %s" call-id))
         (error (message "got err when trying to permit: %s" err)))
       (assoc-delete-all call-id seni/agentsh/permission-pending)))))

(cl-defun seni/agentsh/tweak-permission (orig-fn &rest args)
  "Advice to collect permission options and fix the tool call title"
  (let* ((req (map-elt args :acp-request))
         (params (map-elt req 'params))
         (call-id (map-nested-elt params '(toolCall toolCallId)))
         (debug-on-signal t))
    (message "insert call %s" call-id)
    (if-let*
        ((call
          (gv-ref (alist-get call-id seni/agentsh/permission-pending nil nil #'equal)))
         ((and (gv-deref call))))
        (message "found, ignoring")
      (setf (gv-deref call)
       (list
        :request-id (map-elt req 'id)
        :allow-option
        (cl-some
         (lambda (l) (when (eq (map-elt l 'kind) 'allow_once) (map-elt l 'optionId)))
         (map-elt params 'options)))))
    (cl-letf*
        ((orig-title (symbol-function 'agent-shell--permission-title))
         ((symbol-function 'agent-shell--permission-title)
          (lambda (&rest args)
            (let ((title (apply orig-title args)))
              (if (member (downcase title)
                          '("bash" "sh" "shell" "excute" "run" "command"))
                  (format "```shell\n%s\n```\n"
                          (map-nested-elt params '(toolCall rawInput)))
                title)))))
      (apply orig-fn args))))
(advice-add 'agent-shell--make-tool-call-permission-text
            :around #'seni/agentsh/tweak-permission)

(cl-defun seni/agentsh/auto-permit (call)
  (unless (member (map-elt call :title) '("bash" "run"))
    (cl-return-from seni/agentsh/auto-permit))
  (let* ((cmd-str (map-elt call :command))
         (cmd (seni/agentsh/shell-parse cmd-str)))
    (message "got cmd %s" cmd)
    (seni/agentsh/verify-cmd cmd)))

(cl-defun seni/agentsh/verify-cmd (cmd)
  (pcase cmd
    (`(and . ,elem)
     (cl-loop
      for part on elem
      for (is-prefix . passed) = (seni/agentsh/verify-prefix (car part))
      if is-prefix
      when (not passed) return nil end
      else if (cdr part) return nil
      else return (seni/agentsh/verify-cmd (car part))))
    (`(pipe ,car . ,cdr)
     (and (seni/agentsh/verify-cmd car)
          (all #'seni/agentsh/verify-filter cdr)))
    (`(cmd "cargo" ,(or "check" "build") . ,(or `nil `(:redir ((fd . 2) . (fd . 1)))))
     t)
    (`(cmd "cargo" "clippy" . ,args)
     (when (all (lambda (a) (member a '("--all-targets"))) args)
       t))
    (_ nil)))

(defun seni/agentsh/verify-prefix (cmd)
  (pcase cmd
    (`(cmd "cd" ,path)
     (cons t (file-in-directory-p path (project-root (project-current)))))
    (_
     (cons nil nil))))

(cl-defun seni/agentsh/verify-filter (cmd)
  (pcase cmd
    (`(cmd ,(or "head" "tail") .
           ,(or `("-n" (pred string-to-number))
                (pred (lambda (s) (string-match "-[0-9]+" s 0 t)))))
     t)
    (_ nil)))

;;; Shell parsing
(defvar seni/agentsh/sh-specials (rx (or space ?= ?\' ?\\ ?\" ?| ?& ?> ?\; ?\( ?\) ?$)))
(defvar seni/agentsh/sh-ops "[|&;()]")
(defun seni/agentsh/sh-word ()
  (cl-loop
   with quote = nil
   with res = nil
   for prev = (point)
   for front = (re-search-forward seni/agentsh/sh-specials nil 1)
   when front do (goto-char (match-beginning 0))
   when (looking-at "\\$") do (error "variables are not allowed")
   do (push
       (buffer-substring-no-properties prev (point)) res)
   until (or (not front) (looking-at seni/agentsh/sh-ops))
   while (or quote (looking-at (rx (or ?\' ?\\ ?\"))))
   do (pcase (char-after)
        (?\' (if quote
                 (push "'" res)
               (let* ((start (goto-char (1+ (point))))
                      (end (re-search-forward "'" nil 1)))
                 (unless end (error "non ended single quote"))
                 (push (buffer-substring-no-properties start (goto-char (1- end)))
                       res))))
        (?\\ (goto-char (1+ (point)))
             (push (pcase (char-after)
                     (?n "\n") (?t "\t") (ch (char-to-string ch)))
                   res))
        (?\" (setq quote (not quote)))
        (ch (push (char-to-string ch) res)))
   do (goto-char (1+ (point)))
   finally do (when quote (error "non ended double quote"))
   finally return (apply #'concat (nreverse res))))

(defun seni/agentsh/sh-ws ()
  (when (re-search-forward "\\S-" nil 1)
    (goto-char (match-beginning 0))))

(defun seni/agentsh/sh-cmd ()
  (let (env body redir)
    ;; First part: envs
    (cl-loop
     for name = (and (seni/agentsh/sh-ws) (seni/agentsh/sh-word))
     unless (eq (char-after) ?=)
     do (when name (push name body))
     and return nil
     do (goto-char (1+ (point)))
     for value = (seni/agentsh/sh-word)
     do (push (cons name value) env)
     until (or (eq (point) (point-max)) (looking-at seni/agentsh/sh-ops)))
    ;; With the first body: seek for more, or redir
    (cl-loop
     do (seni/agentsh/sh-ws)
     until (or (eq (point) (point-max)) (looking-at seni/agentsh/sh-ops))
     if (looking-at "\\([0-9]*\\)>") do
     (let* ((src (match-string 1))
            (srcf (or
                   (when src
                     (goto-char (match-end 0))
                     `(fd . ,(string-to-number src)))
                   'stdout))
            (dstf (if (looking-at "\\&\\([0-9]+\\)")
                      (progn
                        (goto-char (match-end 0))
                        `(fd . ,(string-to-number (match-string 1))))
                    `(file . ,(seni/agentsh/sh-word)))))
       (push (cons srcf dstf) redir))
     else do (push (seni/agentsh/sh-word) body))
    ;; Result
    (let ((cmd `(cmd ,@(nreverse body)
                     ,@(when redir `(:redir ,@(nreverse redir))))))
      (if env `(env (,@(nreverse env)) ,cmd) cmd))))

(defvar seni/agentsh/sh-oplist
  `((chain . ";") (or . "||") (and . "&&")
    (pipe . ,(rx ?| (or (not ?|) eos)))))
(defun seni/agentsh/sh-subsh ()
  (seni/agentsh/sh-ws)
  (if (looking-at "(")
      (let ((body (seni/agentsh/sh-op sh-oplist)))
        (seni/agentsh/sh-ws)
        (unless (looking-at ")") (error "unclosed subshell"))
        body)
    (seni/agentsh/sh-cmd)))

(defun seni/agentsh/sh-op (ops)
  (cl-loop
   with name = (caar ops) and pat = (cdar ops) and rest = (cdr ops)
   with res = nil
   for cur = (if rest (seni/agentsh/sh-op rest) (seni/agentsh/sh-subsh))
   do (seni/agentsh/sh-ws)
   until (eq (point) (point-max))
   while (looking-at pat)
   do (progn (push cur res) (goto-char (match-end 0)))
   finally return (if res `(,name ,@(nreverse res) ,cur) cur)))

(defun seni/agentsh/shell-parse (src)
  (with-temp-buffer
    (insert src)
    (goto-char (point-min))
    (seni/agentsh/sh-op seni/agentsh/sh-oplist)))

