;;; bs-mu4e.el --- mu4e integration  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((ebdb "0.8.22") (emacs "30.1") (mu4e "1.14.2"))
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
(declare-function mu4e--modeline-update "mu4e-modeline" ())
(declare-function mu4e--compose-complete-handler "mu4e-compose" (str pred action))
(declare-function mu4e-contact-email "mu4e-contacts")
(declare-function mu4e-contact-name "mu4e-contacts")
(declare-function mu4e-get-headers-buffer "mu4e-buffer" (&optional name create))
(declare-function mu4e-get-view-buffer "mu4e-buffer" (&optional headers-buffer create))
(declare-function mu4e-get-view-buffers "mu4e-buffer" (&optional mapfunc))
(declare-function mu4e-headers-goto-message-id "mu4e-headers" (msgid))
(declare-function mu4e-headers-next "mu4e-headers" (&optional n))
(declare-function mu4e-headers-prev "mu4e-headers" (&optional n))
(declare-function mu4e-headers-view-message "mu4e-headers" ())
(declare-function mu4e-mark-at-point "mu4e-mark" (mark target))
(declare-function mu4e-mark-docid-marked-p "mu4e-mark" (docid))
(declare-function mu4e-mark-restore "mu4e-mark" (docid))
(declare-function mu4e-message-field "mu4e-message")
(declare-function mu4e-message-at-point "mu4e-message" (&optional noerror))
(declare-function mu4e-personal-address-p "mu4e-contacts" (address))
(declare-function mu4e-search-rerun "mu4e-search" ())
(declare-function mu4e-view "mu4e-view" (msg))
(declare-function mu4e~headers-apply-flags "mu4e-headers" (msg fieldval))
(declare-function mu4e~headers-clear "mu4e-headers" (&optional text))
(declare-function mu4e~headers-docid-at-point "mu4e-headers" (&optional point))
(declare-function mu4e~headers-docid-cookie "mu4e-headers" (docid))
(declare-function mu4e~headers-field-value "mu4e-headers" (msg field))
(declare-function mu4e~headers-flags-str "mu4e-headers" (flags))
(declare-function mu4e~headers-goto-docid "mu4e-headers" (docid &optional to-mark))
(declare-function mu4e~headers-highlight "mu4e-headers" (docid))
(declare-function mu4e~headers-human-date "mu4e-headers" (msg))
(declare-function mu4e~headers-thread-prefix "mu4e-headers" (thread))

(defvar ebdb-after-read-db-hook)
(defvar ebdb-dwim-completion-cache)
(defvar ebdb-mode-hook)
(defvar ebdb-mode-map)
(defvar ebdb-record-tracker)
(defvar mail-mode-map)
(defvar message-completion-alist)
(defvar message-mode-map)
(defvar mu4e--mark-fringe)
(defvar mu4e--mark-map)
(defvar mu4e--search-msgid-target)
(defvar mu4e--search-view-target)
(defvar mu4e--contacts-set)
(defvar mu4e--view-message)
(defvar mu4e-found-func)
(defvar mu4e-headers-append-func)
(defvar mu4e-headers-date-format)
(defvar mu4e-headers-fields)
(defvar mu4e-headers-mode-map)
(defvar mu4e-headers-open-after-move)
(defvar mu4e-headers-precise-alignment)
(defvar mu4e-headers-time-format)
(defvar mu4e-mu-version)
(defvar mu4e-remove-func)
(defvar mu4e-search-hide-enabled)
(defvar mu4e-search-hide-predicate)
(defvar mu4e-search-threads)
(defvar mu4e-update-func)
(defvar mu4e-use-fancy-chars)
(defvar mu4e~headers-hidden)
(defvar mu4e~headers-docid-pre)
(defvar mu4e~headers-thread-state)
(defvar mu4e~headers-view-win)
(defvar mu4e~highlighted-docid)

(defgroup bs-mu4e nil
  "Personal mu4e extensions."
  :group 'mu4e)

(defface bs-mu4e-headers-title-face
  '((t :inherit mu4e-header-title-face :weight bold))
  "Face for thread title lines."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-correspondent-face
  '((t :inherit mu4e-header-face :slant italic))
  "Face for message correspondents in thread listings."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-unread-correspondent-face
  '((t :inherit default :weight bold :slant italic))
  "Face for correspondents of unread messages."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-label-face
  '((t :inherit mu4e-header-face :weight regular :underline nil))
  "Parent face for labels in thread listings."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-thread-count-face
  '((t :inherit (font-lock-keyword-face bs-mu4e-headers-label-face)
       :weight semibold :inverse-video t))
  "Face for thread message-count labels."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-unread-thread-count-face
  '((t :inherit (error bs-mu4e-headers-label-face)
       :weight semibold :inverse-video t))
  "Face for thread message-count labels containing unread messages."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-tag-face
  '((t :inherit (font-lock-constant-face bs-mu4e-headers-label-face)
       :inverse-video t))
  "Face for message tag labels."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-timestamp-face
  '((t :inherit (shadow bs-mu4e-headers-label-face)
       :weight regular))
  "Face for message timestamps."
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-thread-count-digits 4
  "Minimum decimal digits reserved for thread message counts."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-thread-count-padding 0.5
  "Colored padding beside thread message counts, in character widths."
  :type 'number
  :group 'bs-mu4e)

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
  "Call Mu4e completion FUNCTION with STR, PRED, and ACTION.

Use cleaned contact candidates for the duration of the call."
  (let ((mu4e--contacts-set
         (or (bs-mu4e-mu4e-contact-completion-set)
             mu4e--contacts-set)))
    (funcall function str pred action)))

(defun bs-mu4e-ebdb-mail-dwim-collection-function
    (function str pred action)
  "Call EBDB completion FUNCTION with STR, PRED, and ACTION.

Use cleaned contact candidates for the duration of the call."
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

(defconst bs-mu4e--headers-minimum-version "1.14.2"
  "Minimum mu4e version supported by the custom headers renderer.")

(defconst bs-mu4e--headers-handler-specs
  '((mu4e-headers-append-func . bs-mu4e--headers-append-handler)
    (mu4e-found-func . bs-mu4e--headers-found-handler)
    (mu4e-update-func . bs-mu4e--headers-update-handler)
    (mu4e-remove-func . bs-mu4e--headers-remove-handler))
  "Mu4e handler variables and their bs-mu4e replacements.")

(defconst bs-mu4e--headers-required-functions
  '(mu4e-get-headers-buffer
    mu4e-headers-next
    mu4e-headers-prev
    mu4e-message-at-point
    mu4e-message-field
    mu4e-personal-address-p
    mu4e~headers-apply-flags
    mu4e~headers-clear
    mu4e~headers-docid-at-point
    mu4e~headers-docid-cookie
    mu4e~headers-goto-docid
    mu4e~headers-highlight
    mu4e~headers-thread-prefix)
  "Mu4e functions required by the custom headers renderer.")

(defconst bs-mu4e--headers-required-variables
  '(mu4e--mark-fringe
    mu4e-found-func
    mu4e-headers-append-func
    mu4e-headers-fields
    mu4e-headers-mode-map
    mu4e-remove-func
    mu4e-update-func)
  "Mu4e variables required by the custom headers renderer.")

(defconst bs-mu4e--headers-keybindings
  `((,(kbd "n") . bs-mu4e-headers-next)
    (,(kbd "p") . bs-mu4e-headers-previous)
    (,(kbd "<M-down>") . bs-mu4e-headers-next)
    (,(kbd "<M-up>") . bs-mu4e-headers-previous)
    (,(kbd "TAB") . bs-mu4e-headers-fold-toggle)
    (,(kbd "<tab>") . bs-mu4e-headers-fold-toggle))
  "Bindings installed in `mu4e-headers-mode-map'.")

(defvar bs-mu4e--headers-enabled nil
  "Non-nil when the custom headers renderer is installed.")

(defvar bs-mu4e--headers-original-handlers nil
  "Saved Mu4e handlers replaced by the custom headers renderer.")

(defvar bs-mu4e--headers-original-bindings nil
  "Saved bindings from `mu4e-headers-mode-map'.")

(defvar-local bs-mu4e--headers-current-thread nil
  "Thread currently receiving streamed messages.")

(defvar-local bs-mu4e--headers-fold-state nil
  "Hash table mapping folded thread keys to anchor docids.")

(defvar-local bs-mu4e--headers-initialized nil
  "Non-nil when the current headers buffer uses the custom model.")

(defvar-local bs-mu4e--headers-last-query nil
  "Last query rendered in the current headers buffer.")

(defvar-local bs-mu4e--headers-match-count 0
  "Number of directly matching messages received so far.")

(defvar-local bs-mu4e--headers-render-width nil
  "Width used for the latest headers render.")

(defvar-local bs-mu4e--headers-resize-timer nil
  "Idle timer used to debounce headers buffer resize rendering.")

(defvar-local bs-mu4e--headers-search-complete nil
  "Non-nil after mu4e reports that the current search is complete.")

(defvar-local bs-mu4e--headers-summary-end nil
  "Marker after the query summary.")

(defvar-local bs-mu4e--headers-threads nil
  "Ordered thread plists for the current headers search.")

;; Mu4e calls `mu4e-headers-mode' for every search, which normally
;; kills buffer-local values.  These two values must survive so a
;; rerun of the same query can preserve folding.
(put 'bs-mu4e--headers-fold-state 'permanent-local t)
(put 'bs-mu4e--headers-last-query 'permanent-local t)

(defun bs-mu4e--headers-sanitize-string (string)
  "Return STRING without control characters that break one-line layout."
  (string-trim
   (replace-regexp-in-string
    "[[:cntrl:]\n\r\t]+"
    " "
    (if (stringp string) string ""))))

(defun bs-mu4e--headers-field-width (field fallback)
  "Return configured width for FIELD, or FALLBACK."
  (let ((width (cdr (assq field mu4e-headers-fields))))
    (if (natnump width) width fallback)))

(defun bs-mu4e--headers-truncate (string width)
  "Truncate STRING to WIDTH columns with an ASCII ellipsis."
  (cond
   ((<= width 0) "")
   ((<= (string-width string) width) string)
   (t
    (truncate-string-to-width
     string width 0 nil (and (> width 3) "...")))))

(defun bs-mu4e--headers-fit (string width)
  "Return STRING truncated or space-padded to WIDTH columns."
  (let ((string (bs-mu4e--headers-truncate string width)))
    (concat string
            (make-string (max 0 (- width (string-width string))) ?\s))))

(defun bs-mu4e--headers-space (width &optional face)
  "Return spacing WIDTH character widths wide using optional FACE."
  (let* ((width (max 0.0 width))
         (whole (floor width))
         (fraction (- width whole))
         (space (make-string whole ?\s)))
    (when (> fraction 0.001)
      (setq space
            (concat
             space
             (propertize
              " " 'display `(space :width ,fraction)))))
    (when (and face (not (string-empty-p space)))
      (put-text-property
       0 (length space) 'font-lock-face face space))
    space))

(defun bs-mu4e--headers-preserve-faces (string)
  "Move transient faces in STRING to persistent Font Lock faces."
  (let ((end (length string))
        (position 0))
    (while (< position end)
      (let* ((next (next-single-property-change
                    position 'face string end))
             (face (get-text-property position 'face string)))
        (when face
          (font-lock-append-text-property
           position next 'font-lock-face face string)
          (remove-text-properties
           position next '(face nil) string))
        (setq position next))))
  string)

(defun bs-mu4e--headers-root-p (msg)
  "Return non-nil when MSG starts a thread in Mu4e search results."
  (let* ((meta (mu4e-message-field msg :meta))
         (orphan (plist-get meta :orphan))
         (first-child (plist-get meta :first-child)))
    (or (plist-get meta :root)
        (and orphan first-child))))

(defun bs-mu4e--headers-related-p (msg)
  "Return non-nil when MSG is related rather than a direct match."
  (plist-get (mu4e-message-field msg :meta) :related))

(defun bs-mu4e--headers-unread-p (msg)
  "Return non-nil when MSG is new or unread."
  (let ((flags (mu4e-message-field msg :flags)))
    (or (memq 'new flags)
        (memq 'unread flags))))

(defun bs-mu4e--headers-sent-p (msg)
  "Return non-nil when MSG was sent from a personal address."
  (when-let* ((from (car-safe (mu4e-message-field msg :from)))
              (address (mu4e-contact-email from)))
    (mu4e-personal-address-p address)))

(defun bs-mu4e--headers-correspondent (msg)
  "Return the correspondent display string for MSG.

Received messages show their senders.  Sent messages show at most
the first two recipients followed by the number of remaining
recipients."
  (let* ((sent (bs-mu4e--headers-sent-p msg))
         (contacts (mu4e-message-field msg (if sent :to :from)))
         (names (mapcar #'bs-mu4e-contact-display-name contacts)))
    (if (and sent (> (length names) 2))
        (format "%s +%d"
                (string-join (cl-subseq names 0 2) ", ")
                (- (length names) 2))
      (string-join names ", "))))

(defun bs-mu4e--headers-thread-key (msg)
  "Return a stable-enough thread key for MSG."
  (let ((message-id (mu4e-message-field msg :message-id))
        (docid (mu4e-message-field msg :docid)))
    (if (and (stringp message-id)
             (not (string-empty-p message-id)))
        (concat "message-id:" message-id)
      (format "docid:%s" docid))))

(defun bs-mu4e--headers-tag-string (tags max-width)
  "Format TAGS within MAX-WIDTH without truncating individual tags."
  (if (<= max-width 0)
      ""
    (let* ((tags (mapcar
                  (lambda (tag)
                    (propertize
                     (format "[%s]"
                             (bs-mu4e--headers-sanitize-string tag))
                     'font-lock-face 'bs-mu4e-headers-tag-face))
                  tags))
           (count (length tags)))
      (cl-loop
       for shown from count downto 0
       for omitted = (- count shown)
       for visible = (string-join (cl-subseq tags 0 shown) " ")
       for suffix = (if (> omitted 0)
                        (propertize
                         (format "+%d" omitted)
                         'font-lock-face 'bs-mu4e-headers-tag-face)
                      "")
       for candidate = (string-join
                        (cl-remove-if
                         #'string-empty-p (list visible suffix))
                        " ")
       when (<= (string-width candidate) max-width)
       return candidate))))

(defun bs-mu4e--headers-thread-count-label (thread)
  "Return the message-count label for THREAD.

Show unread and total counts when THREAD contains unread messages,
or only the total otherwise.  Append `+' when the thread is
incomplete."
  (let* ((messages (plist-get thread :messages))
         (total (length messages))
         (unread (bs-mu4e--headers-thread-unread-count thread))
         (count (if (> unread 0)
                    (format "%d/%d" unread total)
                  (number-to-string total))))
    (format "%s%s"
            count
            (if (plist-get thread :complete) "" "+"))))

(defun bs-mu4e--headers-thread-unread-count (thread)
  "Return the number of unread messages in THREAD."
  (cl-count-if
   #'bs-mu4e--headers-unread-p
   (plist-get thread :messages)))

(defun bs-mu4e--headers-thread-count-width ()
  "Return the widest message-count label in the current headers model."
  (max
   bs-mu4e-headers-thread-count-digits
   (cl-loop for thread in bs-mu4e--headers-threads
            maximize (string-width
                      (bs-mu4e--headers-thread-count-label thread))
            into width
            finally return (or width 0))))

(defun bs-mu4e--headers-title-line (thread width count-width)
  "Return the title line for THREAD fitted to WIDTH.

Right-align its message-count label to COUNT-WIDTH columns."
  (let* ((messages (plist-get thread :messages))
         (root (car messages))
         (padding-width
          (max 0.0
               (min 0.5 bs-mu4e-headers-thread-count-padding)))
         (count-face
          (if (> (bs-mu4e--headers-thread-unread-count thread) 0)
              'bs-mu4e-headers-unread-thread-count-face
            'bs-mu4e-headers-thread-count-face))
         (count-padding
          (bs-mu4e--headers-space
           padding-width count-face))
         (count-gap (bs-mu4e--headers-space 1))
         (count-label
          (propertize
           (bs-mu4e--headers-thread-count-label thread)
           'font-lock-face count-face))
         (count (concat
                 (make-string
                  (max 0 (- count-width (string-width count-label)))
                  ?\s)
                 count-padding
                 count-label
                 count-padding))
         (subject (bs-mu4e--headers-sanitize-string
                   (mu4e-message-field root :subject)))
         (tag-limit
          (min
           (floor width 3)
           (max
            0
            (floor
             (- width count-width (* 2 padding-width) 2)))))
         (tags (bs-mu4e--headers-tag-string
                (mu4e-message-field root :tags)
                tag-limit))
         (reserved (+ count-width (* 2 padding-width)
                      (if (string-empty-p tags)
                          1
                        (+ 2 (string-width tags)))))
         (subject (bs-mu4e--headers-truncate
                   subject (max 0 (floor (- width reserved)))))
         (left (concat count count-gap subject))
         (left-width (+ count-width
                        (* 2 padding-width)
                        1
                        (string-width subject)))
         (tag-padding
          (if (string-empty-p tags)
              ""
            (bs-mu4e--headers-space
             (max 1.0
                  (- width left-width (string-width tags)))))))
    (let ((line (concat left tag-padding tags)))
      (font-lock-append-text-property
       0 (length line) 'font-lock-face
       'bs-mu4e-headers-title-face line)
      line)))

(defun bs-mu4e--headers-message-line (msg prefix width)
  "Return a rendered message line for MSG with PREFIX at WIDTH."
  (let* ((flags (mu4e~headers-field-value msg :flags))
         (flags-width (bs-mu4e--headers-field-width
                       :flags (string-width flags)))
         (flags (bs-mu4e--headers-fit flags flags-width))
         (date (concat (mu4e~headers-field-value msg :human-date) " "))
         (correspondent (bs-mu4e--headers-correspondent msg))
         (correspondent-width
          (max 0
               (- width
                  (string-width mu4e--mark-fringe)
                  flags-width
                  (string-width prefix)
                  (string-width date)
                  2)))
         (correspondent (bs-mu4e--headers-truncate
                         correspondent correspondent-width))
         (correspondent-start
          (+ (length mu4e--mark-fringe)
             (length flags)
             (length prefix)
             1))
         (left (concat mu4e--mark-fringe
                       flags
                       " "
                       prefix
                       correspondent))
         (padding (max 1
                       (- width
                          (string-width left)
                          (string-width date))))
         (visible (concat left (make-string padding ?\s) date))
         (visible
          (bs-mu4e--headers-preserve-faces
           (mu4e~headers-apply-flags msg visible)))
         (docid (mu4e-message-field msg :docid)))
    (unless (string-empty-p correspondent)
      (let ((correspondent-end
             (+ correspondent-start (length correspondent))))
        (if (bs-mu4e--headers-unread-p msg)
            (font-lock-prepend-text-property
             correspondent-start correspondent-end
             'font-lock-face
             'bs-mu4e-headers-unread-correspondent-face visible)
          (font-lock-append-text-property
           correspondent-start correspondent-end
           'font-lock-face
           'bs-mu4e-headers-correspondent-face visible))))
    (font-lock-prepend-text-property
     (- (length visible) (length date) 1)
     (length visible)
     'font-lock-face
     'bs-mu4e-headers-timestamp-face visible)
    (propertize
     (concat (mu4e~headers-docid-cookie docid) visible "\n")
     'docid docid
     'msg msg)))

(defun bs-mu4e--headers-fold-info (count)
  "Return a summary line for COUNT folded messages."
  (propertize
   (format "-- %d hidden --\n" count)
   'font-lock-face 'mu4e-related-face))

(defun bs-mu4e--headers-window ()
  "Return a window suitable for sizing the headers buffer."
  (or (and (eq (window-buffer (selected-window)) (current-buffer))
           (selected-window))
      (get-buffer-window (current-buffer) t)))

(defun bs-mu4e--headers-width ()
  "Return the display width for the current headers buffer."
  (if-let* ((window (bs-mu4e--headers-window)))
      (window-body-width window)
    100))

(defun bs-mu4e--headers-query ()
  "Return the current Mu4e query as a plain string."
  (bs-mu4e--headers-sanitize-string
   (if (stringp list-buffers-directory)
       list-buffers-directory
     "")))

(defun bs-mu4e--headers-summary-line ()
  "Return the query summary for the current headers search."
  (propertize
   (format "SEARCH (%d%s): %S\n\n"
           bs-mu4e--headers-match-count
           (if bs-mu4e--headers-search-complete "" "+")
           (bs-mu4e--headers-query))
   'font-lock-face 'mu4e-header-key-face))

(defun bs-mu4e--headers-clear-thread-markers ()
  "Detach all region markers owned by the current thread model."
  (dolist (thread bs-mu4e--headers-threads)
    (when-let* ((marker (plist-get thread :start)))
      (set-marker marker nil))
    (when-let* ((marker (plist-get thread :end)))
      (set-marker marker nil))))

(defun bs-mu4e--headers-insert-summary ()
  "Insert the query summary at point and update its end marker."
  (insert (bs-mu4e--headers-summary-line))
  (unless (markerp bs-mu4e--headers-summary-end)
    (setq bs-mu4e--headers-summary-end (make-marker))
    (set-marker-insertion-type bs-mu4e--headers-summary-end nil))
  (set-marker bs-mu4e--headers-summary-end (point) (current-buffer)))

(defun bs-mu4e--headers-fold-anchor (thread)
  "Return the visible anchor docid when THREAD is folded."
  (let* ((key (plist-get thread :key))
         (anchor (and (hash-table-p bs-mu4e--headers-fold-state)
                      (gethash key bs-mu4e--headers-fold-state)))
         (messages (plist-get thread :messages)))
    (when (and anchor
               (not (cl-find anchor messages
                             :key (lambda (msg)
                                    (mu4e-message-field msg :docid)))))
      (setq anchor (mu4e-message-field (car messages) :docid))
      (puthash key anchor bs-mu4e--headers-fold-state))
    anchor))

(defun bs-mu4e--headers-message-visible-p (msg anchor)
  "Return non-nil when MSG should remain visible for folded ANCHOR."
  (let ((docid (mu4e-message-field msg :docid)))
    (or (null anchor)
        (eq docid anchor)
        (bs-mu4e--headers-unread-p msg)
        (mu4e-mark-docid-marked-p docid))))

(defun bs-mu4e--headers-insert-thread (thread width count-width)
  "Insert THREAD at point for WIDTH and update its region markers.

Right-align its message-count label to COUNT-WIDTH columns."
  (let ((start (point))
        (anchor (bs-mu4e--headers-fold-anchor thread))
        (hidden 0)
        (mu4e~headers-thread-state nil))
    (insert (bs-mu4e--headers-title-line thread width count-width) "\n")
    (dolist (msg (plist-get thread :messages))
      (let ((prefix (if mu4e-search-threads
                        (mu4e~headers-thread-prefix
                         (mu4e-message-field msg :meta))
                      "")))
        (if (bs-mu4e--headers-message-visible-p msg anchor)
            (insert (bs-mu4e--headers-message-line msg prefix width))
          (cl-incf hidden))))
    (when (> hidden 0)
      (insert (bs-mu4e--headers-fold-info hidden)))
    (insert "\n")
    (unless (markerp (plist-get thread :start))
      (plist-put thread :start (make-marker))
      (set-marker-insertion-type (plist-get thread :start) t))
    (unless (markerp (plist-get thread :end))
      (plist-put thread :end (make-marker))
      (set-marker-insertion-type (plist-get thread :end) nil))
    (set-marker (plist-get thread :start) start (current-buffer))
    (set-marker (plist-get thread :end) (point) (current-buffer))))

(defun bs-mu4e--headers-marked-docids (&optional thread)
  "Return marked docids, optionally restricted to THREAD."
  (let (docids)
    (if thread
        (dolist (msg (plist-get thread :messages))
          (let ((docid (mu4e-message-field msg :docid)))
            (when (gethash docid mu4e--mark-map)
              (push docid docids))))
      (maphash (lambda (docid _mark)
                 (push docid docids))
               mu4e--mark-map))
    docids))

(defun bs-mu4e--headers-restore-marks (&optional thread)
  "Restore visible Mu4e marks, optionally only within THREAD."
  (dolist (docid (bs-mu4e--headers-marked-docids thread))
    (mu4e-mark-restore docid)))

(defun bs-mu4e--headers-goto-first-message ()
  "Move point to the first concrete message row."
  (goto-char (point-min))
  (when (search-forward mu4e~headers-docid-pre nil t)
    (beginning-of-line)
    (move-to-column 2)
    (mu4e~headers-docid-at-point)))

(defun bs-mu4e--headers-synchronize-window-points ()
  "Set windows displaying the current headers buffer to point."
  (let ((buffer (current-buffer))
        (position (point)))
    (dolist (window (get-buffer-window-list buffer nil t))
      (set-window-point window position))))

(defun bs-mu4e--headers-restore-selection (docid)
  "Restore point and highlighting to DOCID, or the first message."
  (let ((docid (and docid
                    (mu4e~headers-goto-docid docid)
                    docid)))
    (unless docid
      (setq docid (bs-mu4e--headers-goto-first-message)))
    (when docid
      (beginning-of-line)
      (move-to-column 2)
      (bs-mu4e--headers-synchronize-window-points)
      (mu4e~headers-highlight docid))
    docid))

(defun bs-mu4e--headers-render (&optional preferred-docid)
  "Render the full headers model, preserving PREFERRED-DOCID."
  (when bs-mu4e--headers-initialized
    (let ((docid (or preferred-docid
                     (mu4e~headers-docid-at-point)))
          (width (bs-mu4e--headers-width))
          (count-width (bs-mu4e--headers-thread-count-width))
          (inhibit-read-only t))
      (setq-local font-lock-extra-managed-props
                  (delq 'display font-lock-extra-managed-props))
      (bs-mu4e--headers-clear-thread-markers)
      (remove-overlays)
      (erase-buffer)
      (goto-char (point-min))
      (bs-mu4e--headers-insert-summary)
      (dolist (thread bs-mu4e--headers-threads)
        (bs-mu4e--headers-insert-thread thread width count-width))
      (setq bs-mu4e--headers-render-width width
            header-line-format nil)
      (bs-mu4e--headers-restore-marks)
      (bs-mu4e--headers-restore-selection docid))))

(defun bs-mu4e--headers-rerender-summary ()
  "Rerender only the query summary."
  (when (and (markerp bs-mu4e--headers-summary-end)
             (marker-position bs-mu4e--headers-summary-end))
    (let ((inhibit-read-only t))
      (delete-region (point-min)
                     (marker-position bs-mu4e--headers-summary-end))
      (goto-char (point-min))
      (bs-mu4e--headers-insert-summary))))

(defun bs-mu4e--headers-rerender-thread (thread &optional preferred-docid)
  "Rerender THREAD while preserving PREFERRED-DOCID."
  (let* ((docid (or preferred-docid
                    (mu4e~headers-docid-at-point)))
         (start (marker-position (plist-get thread :start)))
         (end (marker-position (plist-get thread :end)))
         (inhibit-read-only t))
    (if (and start end)
        (progn
          (delete-region start end)
          (goto-char start)
          (bs-mu4e--headers-insert-thread
           thread (or bs-mu4e--headers-render-width
                      (bs-mu4e--headers-width))
           (bs-mu4e--headers-thread-count-width))
          (bs-mu4e--headers-restore-marks thread)
          (bs-mu4e--headers-restore-selection docid))
      (bs-mu4e--headers-render docid))))

(defun bs-mu4e--headers-message-hidden-p (msg)
  "Return non-nil when Mu4e's search hide predicate hides MSG."
  (when (and mu4e-search-hide-enabled
             mu4e-search-hide-predicate
             (funcall mu4e-search-hide-predicate msg))
    (cl-incf mu4e~headers-hidden)
    t))

(defun bs-mu4e--headers-new-thread (msg)
  "Create a thread model starting with MSG."
  (list :key (bs-mu4e--headers-thread-key msg)
        :messages (list msg)
        :complete nil
        :start (make-marker)
        :end (make-marker)))

(defun bs-mu4e--headers-add-message (msg)
  "Add MSG to the current streamed thread model."
  (when (or (not mu4e-search-threads)
            (null bs-mu4e--headers-current-thread)
            (bs-mu4e--headers-root-p msg))
    (when bs-mu4e--headers-current-thread
      (plist-put bs-mu4e--headers-current-thread :complete t))
    (setq bs-mu4e--headers-current-thread
          (bs-mu4e--headers-new-thread msg)
          bs-mu4e--headers-threads
          (nconc bs-mu4e--headers-threads
                 (list bs-mu4e--headers-current-thread))))
  (unless (eq msg
              (car (plist-get bs-mu4e--headers-current-thread :messages)))
    (setf (plist-get bs-mu4e--headers-current-thread :messages)
          (nconc (plist-get bs-mu4e--headers-current-thread :messages)
                 (list msg)))))

(defun bs-mu4e--headers-reset-model ()
  "Reset the headers model for the current Mu4e query."
  (let ((query (bs-mu4e--headers-query)))
    (unless (and (equal query bs-mu4e--headers-last-query)
                 (hash-table-p bs-mu4e--headers-fold-state))
      (setq bs-mu4e--headers-fold-state (make-hash-table :test #'equal)))
    (setq bs-mu4e--headers-last-query query
          bs-mu4e--headers-current-thread nil
          bs-mu4e--headers-initialized t
          bs-mu4e--headers-match-count 0
          bs-mu4e--headers-search-complete nil
          bs-mu4e--headers-summary-end nil
          bs-mu4e--headers-threads nil
          header-line-format nil)
    (bs-mu4e--headers-render)))

(defun bs-mu4e--headers-clear-advice (function &optional text)
  "Call clear FUNCTION for optional TEXT and initialize the custom model."
  (if (not bs-mu4e--headers-enabled)
      (funcall function text)
    (funcall function)
    (when-let* ((buffer (mu4e-get-headers-buffer)))
      (with-current-buffer buffer
        (bs-mu4e--headers-reset-model)))))

(defun bs-mu4e--headers-append-handler (messages)
  "Append streamed Mu4e MESSAGES to the custom headers model."
  (when-let* ((buffer (mu4e-get-headers-buffer)))
    (with-current-buffer buffer
      (unless bs-mu4e--headers-initialized
        (bs-mu4e--headers-reset-model))
      (let ((docid (mu4e~headers-docid-at-point)))
        (dolist (msg messages)
          (unless (bs-mu4e--headers-related-p msg)
            (cl-incf bs-mu4e--headers-match-count))
          (unless (bs-mu4e--headers-message-hidden-p msg)
            (bs-mu4e--headers-add-message msg)))
        (bs-mu4e--headers-render docid)))))

(defun bs-mu4e--headers-complete-current-thread ()
  "Mark the final streamed thread as complete."
  (when bs-mu4e--headers-current-thread
    (plist-put bs-mu4e--headers-current-thread :complete t)))

(defun bs-mu4e--headers-found-handler (count)
  "Finalize the custom headers view after finding COUNT messages."
  (when-let* ((buffer (mu4e-get-headers-buffer)))
    (with-current-buffer buffer
      (bs-mu4e--headers-complete-current-thread)
      (setq bs-mu4e--headers-match-count count
            bs-mu4e--headers-search-complete t)
      (bs-mu4e--headers-render)
      (goto-char (point-min))
      (cond
       ((and (boundp 'mu4e--search-msgid-target)
             mu4e--search-msgid-target)
        (or (mu4e-headers-goto-message-id mu4e--search-msgid-target)
            (bs-mu4e--headers-goto-first-message)))
       (t
        (bs-mu4e--headers-goto-first-message)))
      (when (and (boundp 'mu4e--search-view-target)
                 mu4e--search-view-target
                 (mu4e-message-at-point 'noerror))
        (mu4e-headers-view-message))
      (when (boundp 'mu4e--search-view-target)
        (setq mu4e--search-view-target nil))
      (when (boundp 'mu4e--search-msgid-target)
        (setq mu4e--search-msgid-target nil))
      (when-let* ((docid (mu4e~headers-docid-at-point)))
        (mu4e~headers-highlight docid))
      (setq header-line-format nil)
      (when (fboundp 'mu4e--modeline-update)
        (mu4e--modeline-update))))
  (run-hooks 'mu4e-headers-found-hook))

(defun bs-mu4e--headers-find-message (docid)
  "Return a cons of thread and message matching DOCID."
  (cl-loop
   for thread in bs-mu4e--headers-threads
   for msg = (cl-find docid
                      (plist-get thread :messages)
                      :key (lambda (item)
                             (mu4e-message-field item :docid)))
   when msg return (cons thread msg)))

(defun bs-mu4e--headers-update-view (msg maybe-view)
  "Update a visible message view with MSG when MAYBE-VIEW is non-nil."
  (when (and maybe-view
             (mu4e-get-view-buffers
              (lambda (_buffer)
                (eq (mu4e-message-field msg :docid)
                    (plist-get mu4e--view-message :docid)))))
    (save-excursion
      (mu4e-view msg))))

(defun bs-mu4e--headers-update-handler (msg is-move maybe-view)
  "Update MSG in the custom model.

IS-MOVE removes the message from the displayed search.  MAYBE-VIEW
also refreshes a view buffer showing MSG."
  (when-let* ((buffer (mu4e-get-headers-buffer)))
    (with-current-buffer buffer
      (if-let* ((found (bs-mu4e--headers-find-message
                        (mu4e-message-field msg :docid)))
                (thread (car found))
                (old-msg (cdr found)))
          (let* ((docid (mu4e-message-field msg :docid))
                 (messages (plist-get thread :messages))
                 (was-related (bs-mu4e--headers-related-p old-msg))
                 (markinfo (gethash docid mu4e--mark-map)))
            (when markinfo
              (remhash docid mu4e--mark-map))
            (plist-put msg :meta (mu4e-message-field old-msg :meta))
            (bs-mu4e--headers-update-view msg maybe-view)
            (if is-move
                (progn
                  (setf (plist-get thread :messages)
                        (delq old-msg messages))
                  (unless was-related
                    (setq bs-mu4e--headers-match-count
                          (max 0 (1- bs-mu4e--headers-match-count))))
                  (if (plist-get thread :messages)
                      (bs-mu4e--headers-rerender-thread thread)
                    (let ((inhibit-read-only t))
                      (delete-region
                       (marker-position (plist-get thread :start))
                       (marker-position (plist-get thread :end)))
                      (setq bs-mu4e--headers-threads
                            (delq thread bs-mu4e--headers-threads)))))
              (setf (plist-get thread :messages)
                    (mapcar (lambda (item)
                              (if (eq item old-msg) msg item))
                            messages))
              (when markinfo
                (puthash docid markinfo mu4e--mark-map))
              (bs-mu4e--headers-rerender-thread thread docid))
            (when is-move
              (bs-mu4e--headers-rerender-summary))
            (run-hooks 'mu4e-message-changed-hook))))))

(defun bs-mu4e--headers-remove-handler (docid)
  "Remove DOCID from the custom headers model."
  (when-let* ((buffer (mu4e-get-headers-buffer)))
    (with-current-buffer buffer
      (when-let* ((found (bs-mu4e--headers-find-message docid))
                  (thread (car found))
                  (msg (cdr found)))
        (setf (plist-get thread :messages)
              (delq msg (plist-get thread :messages)))
        (unless (bs-mu4e--headers-related-p msg)
          (setq bs-mu4e--headers-match-count
                (max 0 (1- bs-mu4e--headers-match-count))))
        (remhash docid mu4e--mark-map)
        (if (plist-get thread :messages)
            (bs-mu4e--headers-rerender-thread thread)
          (let ((inhibit-read-only t))
            (delete-region
             (marker-position (plist-get thread :start))
             (marker-position (plist-get thread :end)))
            (setq bs-mu4e--headers-threads
                  (delq thread bs-mu4e--headers-threads))))
        (bs-mu4e--headers-rerender-summary)
        (bs-mu4e--headers-restore-selection nil))))
  (when-let* ((view-buffer (mu4e-get-view-buffer)))
    (when (and (buffer-live-p view-buffer)
               (with-current-buffer view-buffer
                 (eq docid
                     (mu4e-message-field mu4e--view-message :docid))))
      (mapc #'delete-window (get-buffer-window-list view-buffer nil t))
      (kill-buffer view-buffer))))

(defun bs-mu4e--headers-model-active-p ()
  "Return non-nil when the custom headers model is active."
  (and bs-mu4e--headers-enabled
       (when-let* ((buffer (mu4e-get-headers-buffer)))
         (with-current-buffer buffer
           bs-mu4e--headers-initialized))))

(defun bs-mu4e--headers-update-advice
    (function msg is-move maybe-view)
  "Handle MSG with IS-MOVE and MAYBE-VIEW, or call FUNCTION."
  (if (bs-mu4e--headers-model-active-p)
      (bs-mu4e--headers-update-handler msg is-move maybe-view)
    (funcall function msg is-move maybe-view)))

(defun bs-mu4e--headers-remove-advice (function docid)
  "Use the custom remove handler for DOCID or call FUNCTION."
  (if (bs-mu4e--headers-model-active-p)
      (bs-mu4e--headers-remove-handler docid)
    (funcall function docid)))

(defun bs-mu4e--headers-next-advice (function &optional count)
  "Move by COUNT custom message rows, or call FUNCTION."
  (if (bs-mu4e--headers-model-active-p)
      (bs-mu4e--headers-move-in-context
       (prefix-numeric-value (or count 1)))
    (funcall function count)))

(defun bs-mu4e--headers-previous-advice (function &optional count)
  "Move backwards by COUNT custom message rows, or call FUNCTION."
  (if (bs-mu4e--headers-model-active-p)
      (bs-mu4e--headers-move-in-context
       (- (prefix-numeric-value (or count 1))))
    (funcall function count)))

(defun bs-mu4e--headers-next-message-position (backwards)
  "Return the next concrete message position.

Search backwards when BACKWARDS is non-nil."
  (save-excursion
    (beginning-of-line)
    (let ((step (if backwards -1 1))
          position)
      (while (and (null position)
                  (zerop (forward-line step)))
        (when (get-text-property (line-beginning-position) 'msg)
          (setq position (line-beginning-position))))
      position)))

(defun bs-mu4e--headers-move (count)
  "Move COUNT concrete message rows and return the resulting docid."
  (unless (eq major-mode 'mu4e-headers-mode)
    (user-error "This command requires a Mu4e headers buffer"))
  (let* ((backwards (< count 0))
         (remaining (abs count))
         docid)
    (while (and (> remaining 0)
                (let ((position
                       (bs-mu4e--headers-next-message-position backwards)))
                  (when position
                    (goto-char position)
                    t)))
      (setq docid (mu4e~headers-docid-at-point))
      (cl-decf remaining))
    (when docid
      (beginning-of-line)
      (move-to-column 2)
      (bs-mu4e--headers-synchronize-window-points)
      (when (and mu4e-headers-open-after-move
                 (window-live-p mu4e~headers-view-win))
        (mu4e-headers-view-message))
      (mu4e~headers-highlight docid))
    docid))

(defun bs-mu4e--headers-move-in-context (count)
  "Move COUNT message rows from a headers or message view buffer."
  (if (eq major-mode 'mu4e-headers-mode)
      (bs-mu4e--headers-move count)
    (let* ((msg (mu4e-message-at-point 'noerror))
           (buffer (mu4e-get-headers-buffer))
           (docid (and msg (mu4e-message-field msg :docid)))
           (message-id (and msg
                            (mu4e-message-field msg :message-id))))
      (unless (and (buffer-live-p buffer) docid)
        (user-error "Action is not possible"))
      (with-selected-window
          (or (get-buffer-window buffer) (selected-window))
        (with-current-buffer buffer
          (if (or (mu4e~headers-goto-docid docid)
                  (and message-id
                       (mu4e-headers-goto-message-id message-id)))
              (bs-mu4e--headers-move count)
            (user-error "Cannot find message in headers buffer")))))))

;;;###autoload
(defun bs-mu4e-headers-next (&optional count)
  "Move to the COUNTth next concrete message row."
  (interactive "p")
  (bs-mu4e--headers-move-in-context (or count 1)))

;;;###autoload
(defun bs-mu4e-headers-previous (&optional count)
  "Move to the COUNTth previous concrete message row."
  (interactive "p")
  (bs-mu4e--headers-move-in-context (- (or count 1))))

;;;###autoload
(defun bs-mu4e-headers-fold-toggle ()
  "Toggle folding for the thread containing the message at point."
  (interactive)
  (unless bs-mu4e--headers-initialized
    (user-error "The custom Mu4e headers renderer is not active"))
  (let* ((msg (mu4e-message-at-point 'noerror))
         (docid (and msg (mu4e-message-field msg :docid)))
         (found (and docid (bs-mu4e--headers-find-message docid)))
         (thread (car-safe found)))
    (unless thread
      (user-error "No message thread at point"))
    (let ((key (plist-get thread :key)))
      (if (gethash key bs-mu4e--headers-fold-state)
          (remhash key bs-mu4e--headers-fold-state)
        (puthash key docid bs-mu4e--headers-fold-state))
      (bs-mu4e--headers-rerender-thread thread docid))))

(defun bs-mu4e--headers-resize-render (buffer)
  "Rerender visible headers BUFFER after a debounced resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-mu4e--headers-resize-timer nil)
      (when (and bs-mu4e--headers-initialized
                 (get-buffer-window buffer t))
        (let ((width (bs-mu4e--headers-width)))
          (unless (equal width bs-mu4e--headers-render-width)
            (bs-mu4e--headers-render)))))))

(defun bs-mu4e--headers-schedule-resize (buffer)
  "Schedule a debounced resize render for BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (timerp bs-mu4e--headers-resize-timer)
        (cancel-timer bs-mu4e--headers-resize-timer))
      (setq bs-mu4e--headers-resize-timer
            (run-with-idle-timer
             0.2 nil #'bs-mu4e--headers-resize-render buffer)))))

(defun bs-mu4e--headers-window-size-change (frame)
  "Schedule rerenders for visible headers buffers on FRAME."
  (let ((seen (make-hash-table :test #'eq)))
    (dolist (window (window-list frame 'no-minibuffer))
      (let ((buffer (window-buffer window)))
        (when (and (not (gethash buffer seen))
                   (buffer-live-p buffer)
                   (with-current-buffer buffer
                     (and (eq major-mode 'mu4e-headers-mode)
                          bs-mu4e--headers-initialized)))
          (puthash buffer t seen)
          (bs-mu4e--headers-schedule-resize buffer))))))

(defun bs-mu4e--headers-compatible-p ()
  "Return non-nil when the loaded Mu4e API is supported."
  (and (boundp 'mu4e-mu-version)
       (not (version< mu4e-mu-version
                      bs-mu4e--headers-minimum-version))
       (cl-every #'fboundp bs-mu4e--headers-required-functions)
       (cl-every #'boundp bs-mu4e--headers-required-variables)))

(defun bs-mu4e--headers-install-bindings ()
  "Install custom headers bindings while saving their old values."
  (setq bs-mu4e--headers-original-bindings
        (mapcar
         (lambda (binding)
           (cons (car binding)
                 (lookup-key mu4e-headers-mode-map (car binding))))
         bs-mu4e--headers-keybindings))
  (dolist (binding bs-mu4e--headers-keybindings)
    (define-key mu4e-headers-mode-map
                (car binding)
                (cdr binding))))

(defun bs-mu4e--headers-restore-bindings ()
  "Restore bindings replaced by the custom headers renderer."
  (dolist (binding bs-mu4e--headers-original-bindings)
    (define-key mu4e-headers-mode-map
                (car binding)
                (if (integerp (cdr binding)) nil (cdr binding))))
  (setq bs-mu4e--headers-original-bindings nil))

(defun bs-mu4e--headers-install ()
  "Install the custom headers renderer if Mu4e is compatible."
  (cond
   (bs-mu4e--headers-enabled t)
   ((not (bs-mu4e--headers-compatible-p))
    (display-warning
     'bs-mu4e
     (format
      "Mu4e %s headers API is incompatible; using the native renderer"
      (if (boundp 'mu4e-mu-version) mu4e-mu-version "unknown"))
     :warning)
    nil)
   (t
    (setq bs-mu4e--headers-original-handlers
          (mapcar
           (lambda (spec)
             (cons (car spec) (symbol-value (car spec))))
           bs-mu4e--headers-handler-specs)
          bs-mu4e--headers-enabled t)
    (dolist (spec bs-mu4e--headers-handler-specs)
      (set (car spec) (cdr spec)))
    (bs-mu4e-add-around-advice
     'mu4e~headers-field-value #'bs-mu4e-headers-field-value)
    (bs-mu4e-add-around-advice
     'mu4e~headers-clear #'bs-mu4e--headers-clear-advice)
    (bs-mu4e-add-around-advice
     'mu4e~headers-update-handler #'bs-mu4e--headers-update-advice)
    (bs-mu4e-add-around-advice
     'mu4e~headers-remove-handler #'bs-mu4e--headers-remove-advice)
    (bs-mu4e-add-around-advice
     'mu4e-headers-next #'bs-mu4e--headers-next-advice)
    (bs-mu4e-add-around-advice
     'mu4e-headers-prev #'bs-mu4e--headers-previous-advice)
    (bs-mu4e--headers-install-bindings)
    (add-hook 'window-size-change-functions
              #'bs-mu4e--headers-window-size-change)
    t)))

;;;###autoload
(defun bs-mu4e-headers-disable ()
  "Restore Mu4e's native headers renderer.

This is an emergency and debugging command, not a minor mode."
  (interactive)
  (when bs-mu4e--headers-enabled
    (setq bs-mu4e--headers-enabled nil)
    (dolist (spec bs-mu4e--headers-handler-specs)
      (let ((original
             (alist-get (car spec)
                        bs-mu4e--headers-original-handlers)))
        (when (eq (symbol-value (car spec)) (cdr spec))
          (set (car spec) original))))
    (advice-remove 'mu4e~headers-field-value
                   #'bs-mu4e-headers-field-value)
    (advice-remove 'mu4e~headers-clear
                   #'bs-mu4e--headers-clear-advice)
    (advice-remove 'mu4e~headers-update-handler
                   #'bs-mu4e--headers-update-advice)
    (advice-remove 'mu4e~headers-remove-handler
                   #'bs-mu4e--headers-remove-advice)
    (advice-remove 'mu4e-headers-next
                   #'bs-mu4e--headers-next-advice)
    (advice-remove 'mu4e-headers-prev
                   #'bs-mu4e--headers-previous-advice)
    (bs-mu4e--headers-restore-bindings)
    (remove-hook 'window-size-change-functions
                 #'bs-mu4e--headers-window-size-change)
    (setq bs-mu4e--headers-original-handlers nil)
    (when (called-interactively-p 'interactive)
      (when-let* ((buffer (mu4e-get-headers-buffer)))
        (with-current-buffer buffer
          (when (and (eq major-mode 'mu4e-headers-mode)
                     (not (string-empty-p
                           (bs-mu4e--headers-query))))
            (mu4e-search-rerun)))))))

;;;###autoload
(defun bs-mu4e-headers-enable ()
  "Enable the bs-mu4e multi-line headers renderer."
  (interactive)
  (let ((interactivep (called-interactively-p 'interactive)))
    (with-eval-after-load 'mu4e-headers
      (when (bs-mu4e--headers-install)
        (when interactivep
          (when-let* ((buffer (mu4e-get-headers-buffer)))
            (with-current-buffer buffer
              (when (and (eq major-mode 'mu4e-headers-mode)
                         (not (string-empty-p
                               (bs-mu4e--headers-query))))
                (mu4e-search-rerun)))))))))

(provide 'bs-mu4e)
;;; bs-mu4e.el ends here
