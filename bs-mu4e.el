;;; bs-mu4e.el --- mu4e integration  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((emacs "30.1") (mu4e "1.12.13"))
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

;; This package provides personal mu4e extensions.

;;; Code:

(require 'subr-x)

(declare-function mu4e-contact-email "mu4e-contacts")
(declare-function mu4e-contact-name "mu4e-contacts")
(declare-function mu4e-message-field "mu4e-message")

(defun bs-mu4e-email-address-p (string)
  "Return non-nil when STRING is a bare email address."
  (string-match-p "\\`[^[:space:]<>@]+@[^[:space:]<>@]+\\'" string))

(defun bs-mu4e-trim-contact-name (name)
  "Return NAME without wrapper quotes or a trailing email address."
  (when (stringp name)
    (let ((name (string-trim name)))
      (when (and (> (length name) 1)
                 (string-prefix-p "\"" name)
                 (string-suffix-p "\"" name))
        (setq name (string-trim (substring name 1 -1))))
      (setq name
            (replace-regexp-in-string
             "[[:space:]]*<[^<>[:space:]]+@[^<>[:space:]]+>\\'"
             ""
             name))
      (unless (or (string-empty-p name)
                  (bs-mu4e-email-address-p name))
        name))))

(defun bs-mu4e-contact-display-name (contact)
  "Return the display name for CONTACT, falling back to its email."
  (or (bs-mu4e-trim-contact-name (mu4e-contact-name contact))
      (mu4e-contact-email contact)
      "?"))

(defun bs-mu4e-contact-display-names (contacts)
  "Return a header string with display names from CONTACTS."
  (mapconcat #'bs-mu4e-contact-display-name contacts ", "))

(defun bs-mu4e-headers-field-value (function msg field)
  "Format MSG FIELD, hiding email addresses embedded in From names.

This function is suitable as an around advice for
`mu4e~headers-field-value'.  It only changes the `:from' field and
delegates all other fields to FUNCTION."
  (if (eq field :from)
      (bs-mu4e-contact-display-names (mu4e-message-field msg :from))
    (funcall function msg field)))

(provide 'bs-mu4e)
;;; bs-mu4e.el ends here
