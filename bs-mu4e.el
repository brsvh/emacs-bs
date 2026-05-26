;;; bs-mu4e.el --- mu4e integration  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((ebdb "0.8.22") (emacs "30.1") (mu4e "1.12.13"))
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

(require 'cl-lib)
(require 'mail-parse)
(require 'subr-x)

(declare-function ebdb-complete-keybinding-setup "ebdb-complete")
(declare-function ebdb-dwim-mail "ebdb" (record &optional mail))
(declare-function ebdb-record-mail "ebdb" (record &optional no-roles label defunct))
(declare-function message-tab "message" ())
(declare-function mu4e--compose-complete-handler "mu4e-compose" (str pred action))
(declare-function mu4e-contact-email "mu4e-contacts")
(declare-function mu4e-contact-name "mu4e-contacts")
(declare-function mu4e-message-field "mu4e-message")
(declare-function mu4e~headers-field-value "mu4e-headers" (msg field))

(defvar ebdb-after-read-db-hook)
(defvar ebdb-dwim-completion-cache)
(defvar ebdb-mode-hook)
(defvar ebdb-mode-map)
(defvar ebdb-record-tracker)
(defvar mail-mode-map)
(defvar message-completion-alist)
(defvar message-mode-map)
(defvar mu4e--contacts-set)

(defgroup bs-mu4e nil
  "Personal mu4e extensions."
  :group 'mu4e)

(defcustom bs-mu4e-ebdb-ignored-local-part-regexp
  (concat
   "\\`\\(?:"
   "abuse\\|alerts?\\|announcements?\\|automated\\|autoreply\\|"
   "autoresponder\\|bot\\|bounces?.*\\|confirm\\(?:ation\\)?\\|"
   "deliverystatus\\|devnull\\|digest\\|donotreply\\|"
   "donotrespond\\|listrequest\\|mailerdaemon\\|maildaemon\\|noreply\\|"
   "noresponse\\|newsletter\\|newsletters\\|notifications?\\|notify\\|null\\|"
   "passwordreset\\|phish\\(?:ing\\)?\\|postmaster\\|"
   "reportabuse\\|reset\\|returnpath\\|spam\\|undeliverable\\|"
   "undisclosedrecipients\\|unsubscribe\\|updates?\\|"
   "verif\\(?:y\\|ication\\)"
   "\\)\\'")
  "Regexp matching compact email local parts ignored by EBDB completion.

The local part is lower-cased, truncated before a plus tag, and
then stripped of dots, dashes, and underscores before matching.
This intentionally focuses on automated and non-reply senders,
not every role-based mailbox such as support or info."
  :type 'regexp
  :group 'bs-mu4e)

(defcustom bs-mu4e-ebdb-ignored-display-name-regexp
  (regexp-opt
   '("auto generated"
     "alert"
     "alerts"
     "automated"
     "delivery status"
     "do not reply"
     "mailer daemon"
     "newsletter"
     "no reply"
     "noreply"
     "notification"
     "notifications"
     "password reset"
     "undeliverable"
     "unsubscribe"
     "verification")
   'words)
  "Regexp matching display names ignored by EBDB completion."
  :type 'regexp
  :group 'bs-mu4e)

(defun bs-mu4e-email-address-p (string)
  "Return non-nil when STRING is a bare email address."
  (string-match-p "\\`[^[:space:]<>@]+@[^[:space:]<>@]+\\'" string))

(defun bs-mu4e-trim-contact-name (name)
  "Return NAME without wrapper quotes or a trailing email address."
  (when (stringp name)
    (let ((name (string-trim
                 (replace-regexp-in-string "[\n\r][ \t]+" " " name))))
      (dotimes (_ 2)
        (when (and (> (length name) 1)
                   (string-prefix-p "\"" name)
                   (string-suffix-p "\"" name))
          (setq name (string-trim (substring name 1 -1))))
        (setq name
              (string-trim
               (replace-regexp-in-string
                "[[:space:]]*<[^<>[:space:]]+@[^<>[:space:]]+>\\'"
                ""
                name))))
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

(defun bs-mu4e-clean-mail-address (address)
  "Return ADDRESS with its display name normalized.

This applies the same display-name rule used for mu4e header
contacts: wrapper quotes and a trailing embedded email address are
removed, and bare email names fall back to the email address alone."
  (cond
   ((not (stringp address)) address)
   ((string-match-p
     "\\`[[:space:]\n\r]*<[^<>[:space:]]+@[^<>[:space:]]+>[[:space:]\n\r]*\\'"
     address)
    (string-trim address))
   (t
    (let* ((parsed (mail-header-parse-address-lax address))
           (email (if (consp parsed) (car parsed) parsed))
           (name (and (consp parsed)
                      (bs-mu4e-trim-contact-name (cdr parsed)))))
      (cond
       ((not (and (stringp email) (not (string-empty-p email)))) address)
       (name (format "%s <%s>" name email))
       (t email))))))

(defun bs-mu4e-email-compact-local-part (email)
  "Return EMAIL's local part normalized for ignore-rule matching."
  (when (and (stringp email)
             (string-match "\\`\\([^@]+\\)@" email))
    (let ((local-part (downcase (match-string 1 email))))
      (car (split-string
            (replace-regexp-in-string "[-_.]" "" local-part)
            "\\+"
            t)))))

(defun bs-mu4e-ignored-mail-address-p (address)
  "Return non-nil when ADDRESS looks like an automated sender."
  (let* ((parsed (and (stringp address)
                      (mail-header-parse-address-lax address)))
         (email (if (consp parsed) (car parsed) parsed))
         (name (and (consp parsed)
                    (bs-mu4e-trim-contact-name (cdr parsed))))
         (local-part (bs-mu4e-email-compact-local-part email)))
    (or (and local-part
             (string-match-p bs-mu4e-ebdb-ignored-local-part-regexp
                             local-part))
        (and name
             (string-match-p bs-mu4e-ebdb-ignored-display-name-regexp
                             (downcase name))))))

(defun bs-mu4e-ebdb-dwim-mail (function record &optional mail)
  "Call FUNCTION for EBDB RECORD MAIL and normalize the display name."
  (bs-mu4e-clean-mail-address (funcall function record mail)))

(defun bs-mu4e-completion-candidate (candidate)
  "Return normalized CANDIDATE, or nil when it should be hidden."
  (when (stringp candidate)
    (let ((candidate (bs-mu4e-clean-mail-address candidate)))
      (unless (bs-mu4e-ignored-mail-address-p candidate)
        candidate))))

(defun bs-mu4e-mu4e-contact-completion-set ()
  "Return a cleaned copy of `mu4e--contacts-set' for completion."
  (when (and (boundp 'mu4e--contacts-set)
             (hash-table-p mu4e--contacts-set))
    (let ((contacts (make-hash-table
                     :test 'equal
                     :size (hash-table-count mu4e--contacts-set))))
      (maphash
       (lambda (candidate _value)
         (when-let* ((candidate (bs-mu4e-completion-candidate candidate)))
           (puthash candidate t contacts)))
       mu4e--contacts-set)
      contacts)))

(defun bs-mu4e-mu4e-compose-complete-handler (function str pred action)
  "Call mu4e completion FUNCTION with cleaned contact candidates."
  (let ((mu4e--contacts-set
         (or (bs-mu4e-mu4e-contact-completion-set)
             mu4e--contacts-set)))
    (funcall function str pred action)))

(defun bs-mu4e-ebdb-mail-dwim-collection-function
    (function str pred action)
  "Call EBDB completion FUNCTION with cleaned candidates."
  (let ((ebdb-dwim-completion-cache
         (cl-loop for candidate in ebdb-dwim-completion-cache
                  for cleaned = (bs-mu4e-completion-candidate candidate)
                  when cleaned collect cleaned)))
    (funcall function str pred action)))

(defun bs-mu4e-ebdb-refresh-dwim-completion-cache (&optional _db)
  "Rebuild EBDB mail completion candidates with bs-mu4e names."
  (interactive)
  (when (and (boundp 'ebdb-dwim-completion-cache)
             (boundp 'ebdb-record-tracker))
    (setq ebdb-dwim-completion-cache nil)
    (dolist (record ebdb-record-tracker)
      (dolist (mail (ebdb-record-mail record))
        (let ((candidate (bs-mu4e-completion-candidate
                          (ebdb-dwim-mail record mail))))
          (when candidate
            (cl-pushnew candidate
                        ebdb-dwim-completion-cache
                        :test #'equal)))))))

(defun bs-mu4e-ebdb-complete-restore-standard-completion (&rest _)
  "Keep EBDB Complete from bypassing CAPF in mail buffers."
  (when (boundp 'ebdb-mode-hook)
    (remove-hook 'ebdb-mode-hook #'ebdb-complete-keybinding-setup))
  (when (boundp 'ebdb-mode-map)
    (define-key ebdb-mode-map (kbd "q") #'quit-window))
  (when (boundp 'message-completion-alist)
    (setq message-completion-alist
          (cl-remove 'ebdb-complete-mail message-completion-alist
                     :key #'cdr :test #'eq)))
  (when (boundp 'message-mode-map)
    (define-key message-mode-map (kbd "TAB") #'message-tab))
  (when (boundp 'mail-mode-map)
    (define-key mail-mode-map (kbd "TAB") nil)))

(defun bs-mu4e-add-around-advice (symbol function)
  "Add FUNCTION as around advice to SYMBOL unless already present."
  (unless (advice-member-p function symbol)
    (advice-add symbol :around function)))

;;;###autoload
(defun bs-mu4e-ebdb-enable ()
  "Make EBDB mail completion candidates use bs-mu4e display names."
  (interactive)
  (with-eval-after-load 'ebdb
    (bs-mu4e-add-around-advice 'ebdb-dwim-mail
                               #'bs-mu4e-ebdb-dwim-mail)
    (bs-mu4e-add-around-advice
     'ebdb-mail-dwim-collection-function
     #'bs-mu4e-ebdb-mail-dwim-collection-function)
    (add-hook 'ebdb-after-read-db-hook
              #'bs-mu4e-ebdb-refresh-dwim-completion-cache)
    (bs-mu4e-ebdb-refresh-dwim-completion-cache)))

;;;###autoload
(defun bs-mu4e-compose-completion-enable ()
  "Make mu4e compose contact completion use bs-mu4e candidates."
  (interactive)
  (with-eval-after-load 'mu4e-compose
    (bs-mu4e-add-around-advice
     'mu4e--compose-complete-handler
     #'bs-mu4e-mu4e-compose-complete-handler)))

;;;###autoload
(defun bs-mu4e-ebdb-complete-enable ()
  "Keep EBDB Complete completion on standard mail buffer CAPF."
  (interactive)
  (with-eval-after-load 'ebdb-complete
    (bs-mu4e-ebdb-complete-restore-standard-completion)
    (unless (advice-member-p #'bs-mu4e-ebdb-complete-restore-standard-completion
                             'ebdb-complete-enable)
      (advice-add 'ebdb-complete-enable
                  :after #'bs-mu4e-ebdb-complete-restore-standard-completion))))

(defun bs-mu4e-headers-field-value (function msg field)
  "Format MSG FIELD, hiding email addresses embedded in From names.

This function is suitable as an around advice for
`mu4e~headers-field-value'.  It only changes the `:from' field and
delegates all other fields to FUNCTION."
  (if (eq field :from)
      (bs-mu4e-contact-display-names (mu4e-message-field msg :from))
    (funcall function msg field)))

;;;###autoload
(defun bs-mu4e-headers-enable ()
  "Make mu4e headers use bs-mu4e contact display names."
  (interactive)
  (with-eval-after-load 'mu4e-headers
    (bs-mu4e-add-around-advice 'mu4e~headers-field-value
                               #'bs-mu4e-headers-field-value)))

(provide 'bs-mu4e)
;;; bs-mu4e.el ends here
