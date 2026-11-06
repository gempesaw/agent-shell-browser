;;; agent-shell-browser-dashboard.el --- Session summaries in the browser picker -*- lexical-binding: t; -*-

;; Author: Daniel Gempesaw <gempesaw@modular.com>
;; URL: https://github.com/gempesaw/agent-shell-browser
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (agent-shell-browser "0.1.0"))

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Optional layer: show agent-shell-dashboard session summaries in the
;; browser picker.  Enable with `agent-shell-browser-dashboard-mode'.

;;; Code:

(require 'agent-shell-browser)

(defun agent-shell-browser-dashboard-session-fields (buffer)
  "Return picker fields from BUFFER's agent-shell-dashboard summary."
  (when-let* (((boundp 'agent-shell-dashboard--buffer-summary))
              (summary (buffer-local-value 'agent-shell-dashboard--buffer-summary
                                           buffer))
              ((stringp summary))
              (lines (split-string summary "\n" t "[ \t]+")))
    `((description . ,(car lines))
      ,@(when (cdr lines)
          `((detail . ,(string-join (cdr lines) " ")))))))

;;;###autoload
(define-minor-mode agent-shell-browser-dashboard-mode
  "Show agent-shell-dashboard summaries in the browser session picker."
  :global t
  :group 'agent-shell-browser
  (if agent-shell-browser-dashboard-mode
      (add-hook 'agent-shell-browser-session-functions
                #'agent-shell-browser-dashboard-session-fields)
    (remove-hook 'agent-shell-browser-session-functions
                 #'agent-shell-browser-dashboard-session-fields)))

(provide 'agent-shell-browser-dashboard)
;;; agent-shell-browser-dashboard.el ends here
