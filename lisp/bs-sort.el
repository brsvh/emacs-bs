;;; bs-sort.el --- Line sorting helpers  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is not part of GNU Emacs.

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, either version 3 of the License,
;; or (at your option) any later version.

;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Sort complete lines with per-operation Transient options, or use
;; `bs-sort-lines-natural' directly for natural/version ordering.

;;; Code:

(require 'sort)
(require 'transient)

(defun bs-sort--region (begin end natural ignore-case reverse)
  "Sort complete lines from BEGIN to END.
Use natural/version order when NATURAL is non-nil, otherwise lexical
order.  IGNORE-CASE folds case; REVERSE selects descending order."
  (unless (and (save-excursion (goto-char begin) (bolp))
               (save-excursion
                 (goto-char end) (or (bolp) (eobp))))
    (user-error "Select complete lines to sort"))
  (save-excursion
    (save-restriction
      (narrow-to-region begin end)
      (goto-char (point-min))
      (sort-subr
       reverse #'forward-line #'end-of-line
       (lambda ()
         (let ((key (buffer-substring-no-properties
                     (point) (line-end-position))))
           (if ignore-case (downcase key) key)))
       nil
       (if natural #'string-version-lessp #'string-lessp)))))

(defun bs-sort--apply (natural)
  "Sort the menu's saved region, using natural order if NATURAL."
  (pcase-let* ((`(,begin . ,end)
                (oref transient-current-prefix scope))
               (buffer (marker-buffer begin))
               (args (transient-args 'bs-sort-menu)))
    (unless buffer
      (user-error "The source buffer was closed"))
    (with-current-buffer buffer
      (bs-sort--region begin end natural
                       (member "--ignore-case" args)
                       (member "--reverse" args)))))

(defun bs-sort--lexical ()
  "Sort the menu's saved region in lexical order."
  (interactive)
  (bs-sort--apply nil))

(defun bs-sort--natural ()
  "Sort the menu's saved region in natural/version order."
  (interactive)
  (bs-sort--apply t))

;;;###autoload
(defun bs-sort-lines-natural (begin end &optional reverse)
  "Sort complete lines from BEGIN to END in natural/version order.
A prefix argument or non-nil REVERSE selects descending order."
  (interactive "*r\nP")
  (bs-sort--region begin end t nil reverse))

;;;###autoload
(transient-define-prefix
 bs-sort-menu (begin end)
 "Choose sorting options for complete lines from BEGIN to END.
Options apply only to this invocation."
 [["Options for this operation"
   ("-i" "Ignore case" "--ignore-case")
   ("-r" "Descending" "--reverse")]
  ["Sort selected lines"
   ("l" "Lexical" bs-sort--lexical)
   ("v" "Natural / version" bs-sort--natural)]]
 (interactive "r")
 (transient-setup 'bs-sort-menu nil nil
                  :scope (cons (copy-marker begin)
                               (copy-marker end t))
                  :value nil))

(provide 'bs-sort)
;;; bs-sort.el ends here
