;;; agent-shell-browser-test.el --- Dispatch protocol tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'agent-shell-browser)

(defun agent-shell-browser-test--dispatch (request)
  (let ((request-file (make-temp-file "asb-request" nil ".json"))
        (response-file (make-temp-file "asb-response" nil ".json")))
    (unwind-protect
        (progn
          (agent-shell-browser--write-json request-file request)
          (agent-shell-browser-dispatch request-file response-file)
          (agent-shell-browser--read-json response-file))
      (delete-file request-file)
      (delete-file response-file))))

(ert-deftest agent-shell-browser-test-list-returns-array ()
  (let ((response (agent-shell-browser-test--dispatch '((action . "list")))))
    (should (eq (alist-get 'ok response) t))
    (should (vectorp (alist-get 'sessions response)))))

(ert-deftest agent-shell-browser-test-errors-become-responses ()
  (dolist (request '(((action . "nope"))
                     ((action . "send") (session . "no such buffer") (content . "x"))))
    (let ((response (agent-shell-browser-test--dispatch request)))
      (should (eq (alist-get 'ok response) :false))
      (should (stringp (alist-get 'error response))))))

(ert-deftest agent-shell-browser-test-non-ascii-round-trips ()
  (let ((request '((action . "list") (content . "naïve — 日本語 🚀"))))
    (should (equal (agent-shell-browser--read-json
                    (let ((file (make-temp-file "asb" nil ".json")))
                      (agent-shell-browser--write-json file request)
                      file))
                   request))))

(ert-deftest agent-shell-browser-test-format-includes-instruction-and-source ()
  (let ((text (agent-shell-browser-format
               '((instruction . " summarize ") (kind . "selection")
                 (url . "https://example.com") (title . "Ex")
                 (content . "body")))))
    (should (equal text "summarize\n\nSelection from [Ex](https://example.com):\n\nbody"))))

;;; agent-shell-browser-test.el ends here
