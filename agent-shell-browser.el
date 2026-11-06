;;; agent-shell-browser.el --- Send browser content to agent-shell sessions -*- lexical-binding: t; -*-

;; Author: Daniel Gempesaw <gempesaw@modular.com>
;; URL: https://github.com/gempesaw/agent-shell-browser
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (agent-shell "0.1.0"))
;; Keywords: tools, convenience

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Send a browser selection or page into a live agent-shell session.
;; See README.md for setup.

;;; Code:

(require 'agent-shell)
(require 'json)
(require 'seq)
(require 'subr-x)

(defgroup agent-shell-browser nil
  "Send browser content to agent-shell sessions."
  :group 'agent-shell)

(defcustom agent-shell-browser-session-functions nil
  "Functions adding fields to a session listed in the browser picker.
Each is called with an agent-shell buffer and returns an alist of
extra fields, or nil.  The picker displays `description' and
`detail'; other fields are passed through.  Earlier functions win
when two return the same key, and all of them win over the built-in
fields."
  :type 'hook)

(defcustom agent-shell-browser-format-function #'agent-shell-browser-format
  "Function turning a send request into prompt text.
Called with the request alist, whose keys include `instruction',
`kind' (\"selection\" or \"page\"), `url', `title' and `content'."
  :type 'function)

(defcustom agent-shell-browser-raise-frame t
  "When non-nil, staging raises and focuses the frame showing the session."
  :type 'boolean)

(defcustom agent-shell-browser-stage-poll-interval 1
  "Seconds between checks while waiting for a busy session to accept input."
  :type 'number)

(defun agent-shell-browser-format (request)
  "Return the default prompt text for REQUEST."
  (let-alist request
    (let ((instruction (string-trim (or .instruction "")))
          (source (if (string-empty-p (or .title ""))
                      .url
                    (format "[%s](%s)" .title .url))))
      (concat (unless (string-empty-p instruction)
                (concat instruction "\n\n"))
              (format "%s from %s:\n\n"
                      (if (equal .kind "selection") "Selection" "Page")
                      source)
              (string-trim (or .content ""))))))

(defun agent-shell-browser--busy-p (buffer)
  (with-current-buffer buffer
    (shell-maker-busy)))

(defun agent-shell-browser--describe (buffer)
  (let ((extra (seq-mapcat (lambda (fn) (funcall fn buffer))
                           agent-shell-browser-session-functions))
        (base `((id . ,(buffer-name buffer))
                (title . ,(buffer-name buffer))
                (cwd . ,(abbreviate-file-name
                         (buffer-local-value 'default-directory buffer)))
                (busy . ,(if (agent-shell-browser--busy-p buffer) t :false)))))
    (seq-uniq (append extra base)
              (lambda (a b) (eq (car a) (car b))))))

(defun agent-shell-browser-sessions ()
  "Describe live agent-shell sessions, most recently used first."
  (mapcar #'agent-shell-browser--describe (agent-shell-buffers)))

(defun agent-shell-browser--session-buffer (id)
  (let ((buffer (get-buffer id)))
    (unless (and buffer (memq buffer (agent-shell-buffers)))
      (user-error "No agent-shell session named %s" id))
    buffer))

(defun agent-shell-browser--can-insert-p (buffer)
  (if (fboundp 'agent-shell--can-insert-into-prompt-p)
      (agent-shell--can-insert-into-prompt-p :shell-buffer buffer)
    (not (agent-shell-browser--busy-p buffer))))

(defun agent-shell-browser--raise (buffer)
  (when-let* ((agent-shell-browser-raise-frame)
              (window (get-buffer-window buffer t)))
    (select-frame-set-input-focus (window-frame window))
    (select-window window)))

(defun agent-shell-browser--insert (buffer text)
  (agent-shell-insert :text text :shell-buffer buffer)
  (agent-shell-browser--raise buffer))

(defun agent-shell-browser--stage-when-ready (buffer text)
  (let (timer)
    (setq timer
          (run-at-time
           agent-shell-browser-stage-poll-interval
           agent-shell-browser-stage-poll-interval
           (lambda ()
             (cond ((not (buffer-live-p buffer))
                    (cancel-timer timer))
                   ((agent-shell-browser--can-insert-p buffer)
                    (cancel-timer timer)
                    (agent-shell-browser--insert buffer text))))))))

(defun agent-shell-browser--stage (buffer text)
  (if (agent-shell-browser--can-insert-p buffer)
      (progn
        (agent-shell-browser--insert buffer text)
        "staged")
    (agent-shell-browser--stage-when-ready buffer text)
    "staged after the current turn"))

(defun agent-shell-browser--submit (buffer text)
  (let ((busy (agent-shell-browser--busy-p buffer)))
    (with-current-buffer buffer
      (agent-shell-prompt-queue text))
    (if busy "queued" "submitted")))

(defun agent-shell-browser-send (request)
  "Deliver REQUEST to the session it names; return a status string."
  (let-alist request
    (let ((buffer (agent-shell-browser--session-buffer .session))
          (text (funcall agent-shell-browser-format-function request)))
      (if (eq .submit t)
          (agent-shell-browser--submit buffer text)
        (agent-shell-browser--stage buffer text)))))

(defun agent-shell-browser--handle (request)
  (pcase (alist-get 'action request)
    ("list" `((ok . t) (sessions . ,(vconcat (agent-shell-browser-sessions)))))
    ("send" `((ok . t) (status . ,(agent-shell-browser-send request))))
    (action (error "Unknown action: %S" action))))

(defun agent-shell-browser--read-json (file)
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (json-parse-buffer :object-type 'alist
                       :null-object nil
                       :false-object :false)))

(defun agent-shell-browser--write-json (file object)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file file
      (json-insert object))))

;;;###autoload
(defun agent-shell-browser-dispatch (request-file response-file)
  "Answer the JSON request in REQUEST-FILE by writing RESPONSE-FILE.
Entry point for the native messaging host, which passes files rather
than arguments so page content never goes through elisp quoting."
  (agent-shell-browser--write-json
   response-file
   (condition-case err
       (agent-shell-browser--handle
        (agent-shell-browser--read-json request-file))
     (error `((ok . :false) (error . ,(error-message-string err))))))
  nil)

(provide 'agent-shell-browser)
;;; agent-shell-browser.el ends here
