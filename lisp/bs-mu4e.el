;;; bs-mu4e.el --- mu4e integration  -*- lexical-binding:t -*-

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

;; This package provides personal mu4e extensions.

;;; Code:

(require 'cl-lib)
(require 'bs-lib)
(require 'bs-notifications)
(require 'mail-parse)
(require 'outline)
(require 'subr-x)

(declare-function message-tab "message" ())
(declare-function bs-contacts-mail-completion-set "bs-contacts"
                  (&optional mu4e-contacts-set))
(declare-function gravatar-retrieve
                  "gravatar" (mail-address callback &optional cbargs))
(declare-function notifications-close-notification
                  "notifications" (id &optional bus))
(declare-function notifications-notify "notifications" (&rest params))
(declare-function mu4e--modeline-update "mu4e-modeline" ())
(declare-function mu4e--main-queue-size "mu4e-main" ())
(declare-function mu4e--main-redraw "mu4e-main" ())
(declare-function mu4e--main-toggle-mail-sending-mode "mu4e-main" ())
(declare-function mu4e--server-move
                  "mu4e-server"
                  (docid-or-msgid &optional maildir flags no-view))
(declare-function mu4e-main-mode "mu4e-main" ())
(declare-function mu4e--compose-complete-handler "mu4e-compose" (str pred action))
(declare-function mu4e-ask-maildir "mu4e-folders" (prompt))
(declare-function mu4e-compose-new "mu4e-compose" (&optional to))
(declare-function mu4e-context-switch "mu4e-context" (&optional force name))
(declare-function mu4e-contact-email "mu4e-contacts")
(declare-function mu4e-contact-name "mu4e-contacts")
(declare-function mu4e-display-manual "mu4e" ())
(declare-function mu4e-get-headers-buffer "mu4e-buffer" (&optional name create))
(declare-function mu4e-get-view-buffer "mu4e-buffer" (&optional headers-buffer create))
(declare-function mu4e-get-view-buffers "mu4e-buffer" (&optional mapfunc))
(declare-function mu4e-headers-goto-message-id "mu4e-headers" (msgid))
(declare-function mu4e-headers-next "mu4e-headers" (&optional n))
(declare-function mu4e-headers-prev "mu4e-headers" (&optional n))
(declare-function mu4e-headers-view-message "mu4e-headers" ())
(declare-function mu4e-mark-at-point "mu4e-mark" (mark target))
(declare-function mu4e-mark-docid-marked-p "mu4e-mark" (docid))
(declare-function mu4e-mark-handle-when-leaving "mu4e-mark" ())
(declare-function mu4e-mark-restore "mu4e-mark" (docid))
(declare-function mu4e-message-field "mu4e-message")
(declare-function mu4e-message-at-point "mu4e-message" (&optional noerror))
(declare-function mu4e-message-readable-path
                  "mu4e-message" (&optional msg))
(declare-function mu4e-search-rerun "mu4e-search" ())
(declare-function mu4e-query-items "mu4e-query-items" (&optional type refresh))
(declare-function mu4e-search
                  "mu4e-search"
                  (&optional expr prompt edit ignore-history msgid show))
(declare-function mu4e-search-maildir "mu4e-search" (maildir &optional edit))
(declare-function mu4e-search-query "mu4e-search" ())
(declare-function mu4e-search-read-query "mu4e-search" (prompt &optional initial))
(declare-function mu4e-update-mail-and-index "mu4e-update" (run-in-background))
(declare-function mu4e-alert-notify-unread-messages
                  "mu4e-alert" (mails))
(declare-function mu4e-alert-set-window-urgency-maybe "mu4e-alert" ())
(declare-function smtpmail-send-queued-mail "smtpmail" ())
(declare-function mu4e--view-html-displayed-p "mu4e-view" ())
(declare-function mu4e--view-render-buffer "mu4e-view" (msg))
(declare-function mu4e-action-view-in-browser
                  "mu4e-view" (msg &optional skip-headers))
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
(declare-function xwidget-at "xwidget" (pos))
(declare-function xwidget-webkit-goto-uri
                  "xwidget-internal" (xwidget uri))
(declare-function xwidget-webkit-new-session "xwidget" (url))
(declare-function xwidget-webkit-scroll-down "xwidget" (&optional arg))
(declare-function xwidget-webkit-scroll-up "xwidget" (&optional arg))

(defvar browse-url-browser-function)
(defvar browse-url-handlers)
(defvar gnus-inhibit-mime-unbuttonizing)
(defvar gnus-unbuttonized-mime-types)
(defvar mail-mode-map)
(defvar message-completion-alist)
(defvar message-mode-map)
(defvar mu4e--mark-fringe)
(defvar mu4e--mark-map)
(defvar mu4e--update-timer)
(defvar mu4e--search-msgid-target)
(defvar mu4e--search-view-target)
(defvar mu4e--contacts-set)
(defvar mu4e--view-message)
(defvar mu4e-compose-context-policy)
(defvar mu4e-context-changed-hook)
(defvar mu4e-drafts-folder)
(defvar mu4e-found-func)
(defvar mu4e-headers-append-func)
(defvar mu4e-headers-date-format)
(defvar mu4e-headers-fields)
(defvar mu4e-headers-mode-map)
(defvar mu4e-headers-open-after-move)
(defvar mu4e-headers-precise-alignment)
(defvar mu4e-headers-time-format)
(defvar mu4e-headers-visible-flags)
(defvar mu4e-index-update-error-continue)
(defvar mu4e-main-buffer-name)
(defvar mu4e-mu-binary)
(defvar mu4e-mu-version)
(defvar mu4e-remove-func)
(defvar mu4e-search-hide-enabled)
(defvar mu4e-search-hide-predicate)
(defvar mu4e-search-threads)
(defvar mu4e-update-func)
(defvar mu4e-use-fancy-chars)
(defvar mu4e-trash-folder)
(defvar smtpmail-queue-mail)
(defvar smtpmail-queue-dir)
(defvar mu4e-view-fields)
(defvar mu4e-view-rendered-hook)
(defvar mu4e~headers-hidden)
(defvar mu4e~headers-docid-pre)
(defvar mu4e~headers-thread-state)
(defvar mu4e~headers-view-win)
(defvar mu4e~highlighted-docid)
(defvar read-eval)
(defvar xwidget-webkit-last-session-buffer)

(defgroup bs-mu4e nil
  "Personal mu4e extensions."
  :group 'mu4e)

(defface bs-mu4e-main-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for the complete Mu4e Main header line."
  :group 'bs-mu4e)

(defface bs-mu4e-main-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in the Mu4e Main header line."
  :group 'bs-mu4e)

(defface bs-mu4e-main-header-value-face
  '((t :inherit font-lock-keyword-face :slant italic))
  "Face used for dynamic values in the Mu4e Main header line."
  :group 'bs-mu4e)

(defface bs-mu4e-main-header-context-face
  '((t :inherit font-lock-keyword-face :slant normal))
  "Face used for the active context in the Mu4e Main header."
  :group 'bs-mu4e)

(defface bs-mu4e-main-header-unread-face
  '((t :inherit error :weight semi-bold :slant normal))
  "Face used for the unread count in the Mu4e Main header."
  :group 'bs-mu4e)

(defface bs-mu4e-main-header-muted-face
  '((t :inherit shadow :weight normal :slant normal))
  "Face used for secondary statistics in the Mu4e Main header."
  :group 'bs-mu4e)

(defface bs-mu4e-main-topic-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face used for Mu4e Main topics."
  :group 'bs-mu4e)

(defface bs-mu4e-main-root-face
  '((t :inherit bs-mu4e-main-topic-face :height 1.30))
  "Face used for the Mu4e Main root topic."
  :group 'bs-mu4e)

(defface bs-mu4e-main-top-level-face
  '((t :inherit bs-mu4e-main-topic-face :height 1.15))
  "Face used for top-level Mu4e Main topics."
  :group 'bs-mu4e)

(defface bs-mu4e-main-topic-count-face
  '((t :inherit error :weight semi-bold))
  "Face used for nonzero Mu4e Main topic counts."
  :group 'bs-mu4e)

(defface bs-mu4e-main-empty-count-face
  '((t :inherit shadow))
  "Face used for empty Mu4e Main topic counts."
  :group 'bs-mu4e)

(defface bs-mu4e-main-unread-count-face
  '((t :inherit error :weight bold))
  "Face used for unread Mu4e Main row counts."
  :group 'bs-mu4e)

(defface bs-mu4e-main-read-count-face
  '((t :inherit shadow))
  "Face used for zero unread Mu4e Main row counts."
  :group 'bs-mu4e)

(defface bs-mu4e-main-total-face
  '((t :inherit shadow))
  "Face used for total Mu4e Main row counts."
  :group 'bs-mu4e)

(defface bs-mu4e-main-separator-face
  '((t :inherit shadow))
  "Face used for Mu4e Main separators."
  :group 'bs-mu4e)

(defface bs-mu4e-main-unread-name-face
  '((t :inherit default :weight bold))
  "Face used for Mu4e Main rows containing unread messages."
  :group 'bs-mu4e)

(defface bs-mu4e-main-read-name-face
  '((t :inherit shadow))
  "Face used for Mu4e Main rows without unread messages."
  :group 'bs-mu4e)

(defface bs-mu4e-main-source-face
  '((t :inherit shadow))
  "Face used for Mu4e Main row metadata."
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-root-name "Mu4e"
  "Name of the synthetic Mu4e Main root topic."
  :type 'string
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-update-retry-interval 120
  "Seconds before retrying a failed Mu4e update."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-topic-line-spacing 0.65
  "Relative spacing added around Mu4e Main topic rows."
  :type 'number
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-header-bottom-spacing 0.5
  "Relative line height reserved below the Mu4e Main header."
  :type 'number
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-row-indentation-width 4
  "Columns reserved before Mu4e Main row statistics."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-minimum-count-width 9
  "Minimum width of the Mu4e Main row count column."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-right-margin-width 1
  "Columns reserved after Mu4e Main row metadata."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-main-fallback-width 100
  "Width used to render Mu4e Main when it is not displayed."
  :type 'natnum
  :group 'bs-mu4e)

(defvar bs-mu4e-context-name "bingshan"
  "Name of the active Mu4e context.")

(defvar bs-mu4e-context-query ""
  "Query restricting searches to the active Mu4e context.")

(defvar bs-mu4e--main-enabled nil
  "Non-nil when the custom Mu4e Main renderer is installed.")

(defvar bs-mu4e--main-update-state 'idle
  "Current Mu4e Main update state.")

(defvar bs-mu4e--main-update-failed-p nil
  "Non-nil when mail retrieval failed during the current update.")

(defvar bs-mu4e--main-retry-timer nil
  "Timer used to retry failed Mu4e updates.")

(defvar bs-mu4e--main-clock-timer nil
  "Timer used to refresh relative times in the Mu4e Main header.")

(defvar-local bs-mu4e--main-render-width nil
  "Width used for the latest Mu4e Main rendering.")

(defvar-local bs-mu4e--main-resize-timer nil
  "Pending Mu4e Main resize refresh timer.")

(defun bs-mu4e--main-buffer-width ()
  "Return the displayed width of the current Mu4e Main buffer."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    bs-mu4e-main-fallback-width))

(defun bs-mu4e--main-query-items ()
  "Return current bookmark query items without signaling errors."
  (condition-case nil
      (mu4e-query-items 'bookmarks)
    (error nil)))

(defun bs-mu4e--main-visible-bookmarks (items)
  "Return visible bookmark ITEMS."
  (seq-filter
   (lambda (item)
     (and (characterp (plist-get item :key))
          (not (plist-get item :bs-hidden))))
   items))

(defun bs-mu4e--main-maildirs (items)
  "Return Maildir query ITEMS sorted by display name."
  (sort
   (seq-filter (lambda (item) (plist-get item :bs-maildir)) items)
   (lambda (left right)
     (string-lessp (plist-get left :name) (plist-get right :name)))))

(defun bs-mu4e--main-summary (items)
  "Return the context summary item from ITEMS."
  (seq-find (lambda (item) (plist-get item :bs-context-summary)) items))

(defun bs-mu4e--main-unread-bookmark (items)
  "Return the unread bookmark from ITEMS."
  (seq-find (lambda (item) (eq (plist-get item :key) ?u)) items))

(defun bs-mu4e--main-count-widths (items)
  "Return aligned unread and total count widths for ITEMS."
  (let ((unread-width 2)
        (total-width 1))
    (dolist (item items)
      (setq unread-width
            (max unread-width
                 (string-width
                  (number-to-string (or (plist-get item :unread) 0))))
            total-width
            (max total-width
                 (string-width
                  (number-to-string (or (plist-get item :count) 0))))))
    (setq total-width
          (+ total-width
             (max 0 (- bs-mu4e-main-minimum-count-width
                       unread-width 1 total-width))))
    (list unread-width total-width)))

(defun bs-mu4e--main-count (item widths)
  "Format ITEM counts using WIDTHS."
  (let* ((unread (or (plist-get item :unread) 0))
         (total (or (plist-get item :count) 0))
         (unread-string (number-to-string unread))
         (total-string (number-to-string total))
         (unread-width (nth 0 widths))
         (total-width (nth 1 widths)))
    (concat
     (propertize
      (format (format "%%%ds" unread-width) unread-string)
      'face (if (> unread 0)
                'bs-mu4e-main-unread-count-face
              'bs-mu4e-main-read-count-face))
     (propertize "/" 'face 'bs-mu4e-main-separator-face)
     (propertize total-string 'face 'bs-mu4e-main-total-face)
     (make-string
      (max 0 (- total-width (string-width total-string))) ?\s))))

(defun bs-mu4e--main-empty-count (widths)
  "Return an empty count column with an aligned separator using WIDTHS."
  (concat
   (make-string (nth 0 widths) ?\s)
   (propertize "/" 'face 'bs-mu4e-main-separator-face)
   (make-string (nth 1 widths) ?\s)))

(defun bs-mu4e--main-heading-display (collapsed)
  "Return a heading prefix according to COLLAPSED."
  (if collapsed "▸ " "  "))

(defun bs-mu4e--main-insert-topic (name count level root-p)
  "Insert topic NAME with COUNT at LEVEL.
ROOT-P identifies the synthetic root."
  (let* ((start (point))
         (stars (make-string level ?*))
         (label-face
          (if root-p 'bs-mu4e-main-root-face
            'bs-mu4e-main-top-level-face))
         (label (propertize name 'face label-face))
         (body
          (if root-p label
            (concat
             label
             (propertize " (" 'face 'bs-mu4e-main-separator-face)
             (if (stringp count)
                 (propertize count 'face 'mu4e-highlight-face)
               (propertize
                (number-to-string count)
                'face (if (> count 0)
                          'bs-mu4e-main-topic-count-face
                        'bs-mu4e-main-empty-count-face)))
             (propertize ")" 'face 'bs-mu4e-main-separator-face)))))
    (put-text-property
     0 (length stars) 'display
     (bs-mu4e--main-heading-display nil) stars)
    (insert
     (propertize
      (concat stars body)
      'bs-mu4e-main-heading name
      'mouse-face 'highlight)
     ?\n)
    (add-text-properties
     start (1+ start)
     `(line-prefix
       ,(bs-top-spacing-prefix
         (+ bs-mu4e-main-topic-line-spacing
            (if root-p bs-mu4e-main-header-bottom-spacing 0)))))))

(defun bs-mu4e--main-row-command (command)
  "Return a no-argument interactive wrapper for COMMAND."
  (lambda ()
    (interactive)
    (call-interactively command)))

(defun bs-mu4e--main-insert-row
    (count shortcut name source command widths render-width &optional action-p)
  "Insert a Mu4e Main row.
COUNT is a query item or nil.  SHORTCUT, NAME, and SOURCE are its
display fields.  COMMAND activates the row.  WIDTHS and
RENDER-WIDTH control layout.  ACTION-P uses the ordinary name face."
  (let* ((count-string
          (if count
              (bs-mu4e--main-count count widths)
            (bs-mu4e--main-empty-count widths)))
         (indentation
          (make-string bs-mu4e-main-row-indentation-width ?\s))
         (shortcut (format "[%s]" shortcut))
         (count-gap-width (if action-p 3 2))
         (prefix-width
          (+ bs-mu4e-main-row-indentation-width
             (nth 0 widths) 1 (nth 1 widths) count-gap-width
             (string-width shortcut) 1))
         (content-width
          (max 0 (- render-width prefix-width
                    bs-mu4e-main-right-margin-width)))
         (source (bs-single-line source ""))
         (source-width (min (string-width source)
                            (max 0 (- content-width 2))))
         (source (bs-truncate-string source source-width))
         (name-width
          (max 0 (- content-width (string-width source)
                    (if (string-empty-p source) 0 2))))
         (name (bs-truncate-string
                (bs-single-line name "[unnamed]")
                name-width))
         (padding
          (make-string
           (max 0 (- content-width (string-width name)
                     (string-width source))) ?\s))
         (name-face
          (cond
           (action-p 'default)
           ((> (or (plist-get count :unread) 0) 0)
            'bs-mu4e-main-unread-name-face)
           (t 'bs-mu4e-main-read-name-face)))
         (line
          (concat
           indentation count-string
           (make-string count-gap-width ?\s)
           (propertize shortcut 'face 'mu4e-highlight-face) " "
           (propertize name 'face name-face)
           padding
           (propertize source 'face 'bs-mu4e-main-source-face)
           (make-string bs-mu4e-main-right-margin-width ?\s))))
    (insert
     (propertize
      line
      'bs-mu4e-main-command (bs-mu4e--main-row-command command)
      'mouse-face 'highlight)
     ?\n)))

(defun bs-mu4e--main-add-trailing-topic-spacing ()
  "Add lower spacing after each final consecutive topic row."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let* ((position (line-beginning-position))
             (topic (get-text-property position 'bs-mu4e-main-heading))
             (newline (line-end-position))
             (next-topic
              (get-text-property
               (line-beginning-position 2) 'bs-mu4e-main-heading)))
        (when (and topic (not next-topic))
          (add-text-properties
           newline (1+ newline)
           `(line-spacing ,bs-mu4e-main-topic-line-spacing)))
        (forward-line 1)))))

(defun bs-mu4e--main-action-items ()
  "Return the Mu4e Main action row specifications."
  (append
   `(("c" "Choose query" ,bs-mu4e-context-name ,#'mu4e-search-query)
     ("C" "Compose"
      ,(symbol-name
        (or (and (boundp 'mu4e-compose-context-policy)
                 mu4e-compose-context-policy)
            'ask))
      ,#'mu4e-compose-new))
   (when (and (boundp 'smtpmail-queue-dir)
              (stringp smtpmail-queue-dir)
              (file-directory-p smtpmail-queue-dir)
              (> (mu4e--main-queue-size) 0))
     `(("f" ,(format "Flush %d queued mails"
                     (mu4e--main-queue-size))
        "global" ,#'smtpmail-send-queued-mail)))
   `(("j" "Jump to maildir" ,bs-mu4e-context-name ,#'mu4e-search-maildir)
     ("s" "Search" "global" ,#'mu4e-search)
     (";" "Switch context" ,bs-mu4e-context-name ,#'mu4e-context-switch)
     ("m" "Toggle mail sending mode"
      ,(if (bound-and-true-p smtpmail-queue-mail) "queued" "direct")
      ,#'mu4e--main-toggle-mail-sending-mode)
     ("U" "Update email and database" "global"
      ,(lambda () (interactive) (mu4e-update-mail-and-index t))))))

(defun bs-mu4e--main-search-query (query)
  "Search for QUERY from a Mu4e Main row."
  (lambda ()
    (interactive)
    (mu4e-search query)))

(defun bs-mu4e--main-insert-actions (widths render-width)
  "Insert Action rows using WIDTHS and RENDER-WIDTH."
  (dolist (action (bs-mu4e--main-action-items))
    (pcase-let ((`(,key ,name ,source ,command) action))
      (bs-mu4e--main-insert-row
       nil key name source command widths render-width t))))

(defun bs-mu4e--main-insert-bookmarks (items widths render-width)
  "Insert bookmark ITEMS using WIDTHS and RENDER-WIDTH."
  (dolist (item items)
    (let ((query (plist-get item :query)))
      (bs-mu4e--main-insert-row
       item
       (format "b%c" (plist-get item :key))
       (plist-get item :name)
       (plist-get item :source)
       (bs-mu4e--main-search-query query)
       widths render-width))))

(defun bs-mu4e--main-insert-maildirs (items widths render-width)
  "Insert Maildir ITEMS using WIDTHS and RENDER-WIDTH."
  (dolist (item items)
    (let ((query (plist-get item :query)))
      (bs-mu4e--main-insert-row
       item
       (format "j%c" (plist-get item :bs-maildir-key))
       (plist-get item :name)
       (plist-get item :source)
       (bs-mu4e--main-search-query query)
       widths render-width))))

(defun bs-mu4e--main-update-indicators (&rest _)
  "Update visible Mu4e Main disclosure indicators."
  (when (derived-mode-p 'mu4e-main-mode)
    (with-silent-modifications
      (let ((inhibit-read-only t)
            (origin (point)))
        (save-restriction
          (widen)
          (goto-char (point-min))
          (while (re-search-forward "^\\(\\*+\\)" nil t)
            (let* ((beginning (match-beginning 1))
                   (end (match-end 1))
                   (next-line (line-beginning-position 2))
                   (collapsed
                    (and (< next-line (point-max))
                         (outline-invisible-p next-line))))
              (put-text-property
               beginning end 'display
               (bs-mu4e--main-heading-display collapsed)))))
        (goto-char (min origin (point-max)))))))

(defun bs-mu4e-main-activate ()
  "Toggle the topic or activate the Mu4e Main row at point."
  (interactive)
  (if-let* ((command
             (get-text-property
              (line-beginning-position) 'bs-mu4e-main-command)))
      (funcall command)
    (if (get-text-property
         (line-beginning-position) 'bs-mu4e-main-heading)
        (progn
          (outline-toggle-children)
          (bs-mu4e--main-update-indicators))
      (user-error "No Mu4e Main action on this row"))))

(defun bs-mu4e-main-toggle-topic ()
  "Toggle the Mu4e Main topic at point."
  (interactive)
  (unless (get-text-property
           (line-beginning-position) 'bs-mu4e-main-heading)
    (user-error "No Mu4e Main topic on this row"))
  (outline-toggle-children)
  (bs-mu4e--main-update-indicators))

(defun bs-mu4e--main-time-text (timer)
  "Return remaining time for TIMER in minutes."
  (if (not (timerp timer))
      "not scheduled"
    (let ((seconds (max 0 (- (timer-until timer nil)))))
      (if (< seconds 60)
          "<1 minutes"
        (format "%d minutes" (ceiling (/ seconds 60.0)))))))

(defun bs-mu4e--main-update-status ()
  "Return the current update status for the header line."
  (pcase bs-mu4e--main-update-state
    ('retrieving
     (propertize "RETRIEVING" 'face 'bs-mu4e-main-header-label-face))
    ('indexing
     (propertize "INDEXING" 'face 'bs-mu4e-main-header-label-face))
    ('retry
     (concat
      (propertize "NEXT RETRY" 'face 'bs-mu4e-main-header-label-face)
      " "
      (propertize
       (bs-mu4e--main-time-text bs-mu4e--main-retry-timer)
       'face 'bs-mu4e-main-header-value-face)))
    (_
     (concat
      (propertize "NEXT UPDATE" 'face 'bs-mu4e-main-header-label-face)
      " "
      (propertize
       (bs-mu4e--main-time-text
        (and (boundp 'mu4e--update-timer) mu4e--update-timer))
       'face 'bs-mu4e-main-header-value-face)))))

(defun bs-mu4e--main-statistics (summary bookmark-count variant)
  "Return right-side statistics for SUMMARY and BOOKMARK-COUNT.
VARIANT is `full', `no-bookmarks', or `compact'."
  (let ((unread (or (plist-get summary :unread) 0))
        (messages (or (plist-get summary :count) 0))
        (separator (propertize " · " 'face 'bs-mu4e-main-separator-face)))
    (concat
     (propertize
      bs-mu4e-context-name 'face 'bs-mu4e-main-header-context-face)
     (unless (eq variant 'compact)
       (concat
        separator
        (when (eq variant 'full)
          (concat
           (propertize
            (format "%d bookmarks" bookmark-count)
            'face 'bs-mu4e-main-header-muted-face)
           separator))
        (propertize
         (number-to-string unread)
         'face 'bs-mu4e-main-header-unread-face)
        (propertize " unread" 'face 'bs-mu4e-main-header-muted-face)
        (when (memq variant '(full no-bookmarks))
          (concat
           separator
           (propertize
            (format "%d total" messages)
            'face 'bs-mu4e-main-header-muted-face)))))
     (when (eq variant 'compact)
       (concat
        separator
        (propertize
         (number-to-string unread)
         'face 'bs-mu4e-main-header-unread-face)
        (propertize " unread" 'face 'bs-mu4e-main-header-muted-face))))))

(defun bs-mu4e--main-header ()
  "Return the Mu4e Main header line."
  (let* ((items (bs-mu4e--main-query-items))
         (bookmarks (bs-mu4e--main-visible-bookmarks items))
         (summary-item (bs-mu4e--main-summary items))
         (unread-item (bs-mu4e--main-unread-bookmark bookmarks))
         (summary
          (if unread-item
              (plist-put
               (copy-sequence summary-item)
               :unread (plist-get unread-item :count))
            summary-item))
         (left (bs-mu4e--main-update-status))
         (width (bs-mu4e--main-buffer-width))
         (full (bs-mu4e--main-statistics summary (length bookmarks) 'full))
         (no-bookmarks
          (bs-mu4e--main-statistics
           summary (length bookmarks) 'no-bookmarks))
         (compact
          (bs-mu4e--main-statistics summary (length bookmarks) 'compact))
         (right
          (cond
           ((<= (+ (string-width left) (string-width full) 2) width) full)
           ((<= (+ (string-width left) (string-width no-bookmarks) 2)
                width)
            no-bookmarks)
           (t compact)))
         (header
          (concat left (bs-right-padding right) right)))
    (add-face-text-property
     0 (length header) 'bs-mu4e-main-header-face t header)
    header))

(defun bs-mu4e--main-redraw ()
  "Redraw the custom Mu4e Main buffer if it exists."
  (when-let* ((buffer (get-buffer mu4e-main-buffer-name))
              ((buffer-live-p buffer)))
    (with-current-buffer buffer
      (let* ((origin-line (line-number-at-pos))
             (origin-column (current-column))
             (restore
              (and (derived-mode-p 'mu4e-main-mode)
                   (outline-revert-buffer-restore-visibility)))
             (inhibit-read-only t)
             (items (bs-mu4e--main-query-items))
             (bookmarks (bs-mu4e--main-visible-bookmarks items))
             (maildirs (bs-mu4e--main-maildirs items))
             (summary (bs-mu4e--main-summary items))
             (unread-item (bs-mu4e--main-unread-bookmark bookmarks))
             (unread (or (plist-get unread-item :count)
                         (plist-get summary :unread) 0))
             (widths (bs-mu4e--main-count-widths
                      (append bookmarks maildirs)))
             (render-width (bs-mu4e--main-buffer-width)))
        (unless (derived-mode-p 'mu4e-main-mode)
          (mu4e-main-mode))
        (setq bs-mu4e--main-render-width render-width)
        (erase-buffer)
        (bs-mu4e--main-insert-topic
         bs-mu4e-main-root-name nil 1 t)
        (bs-mu4e--main-insert-topic "Actions" "h" 2 nil)
        (bs-mu4e--main-insert-actions widths render-width)
        (bs-mu4e--main-insert-topic "Bookmarks" unread 2 nil)
        (bs-mu4e--main-insert-bookmarks bookmarks widths render-width)
        (bs-mu4e--main-insert-topic "Maildirs" unread 2 nil)
        (bs-mu4e--main-insert-maildirs maildirs widths render-width)
        (bs-mu4e--main-add-trailing-topic-spacing)
        (when restore (funcall restore))
        (bs-mu4e--main-update-indicators)
        (goto-char (point-min))
        (forward-line (1- origin-line))
        (move-to-column origin-column)
        (set-buffer-modified-p nil)
        (force-mode-line-update)))))

(defun bs-mu4e--main-force-header-update ()
  "Refresh the Mu4e Main header if its buffer exists."
  (when-let* ((buffer (get-buffer mu4e-main-buffer-name)))
    (with-current-buffer buffer
      (force-mode-line-update t))))

(defun bs-mu4e--main-cancel-retry ()
  "Cancel the pending Mu4e update retry timer."
  (when (timerp bs-mu4e--main-retry-timer)
    (cancel-timer bs-mu4e--main-retry-timer))
  (setq bs-mu4e--main-retry-timer nil))

(defun bs-mu4e--main-retry-update ()
  "Retry a failed Mu4e update in the background."
  (setq bs-mu4e--main-retry-timer nil)
  (mu4e-update-mail-and-index t))

(defun bs-mu4e--main-schedule-retry ()
  "Schedule a background retry after an update failure."
  (bs-mu4e--main-cancel-retry)
  (setq bs-mu4e--main-update-state 'retry
        bs-mu4e--main-retry-timer
        (run-at-time
         (max 1 bs-mu4e-main-update-retry-interval) nil
         #'bs-mu4e--main-retry-update))
  (bs-mu4e--main-force-header-update))

(defun bs-mu4e--main-update-started ()
  "Record the start of Mu4e mail retrieval."
  (bs-mu4e--main-cancel-retry)
  (setq bs-mu4e--main-update-failed-p nil
        bs-mu4e--main-update-state 'retrieving)
  (bs-mu4e--main-force-header-update))

(defun bs-mu4e--main-index-started (&rest _)
  "Record the start of Mu4e indexing."
  (setq bs-mu4e--main-update-state 'indexing)
  (bs-mu4e--main-force-header-update))

(defun bs-mu4e--main-retrieval-finished (process &rest _)
  "Record failure when retrieval PROCESS exits unsuccessfully."
  (setq bs-mu4e--main-update-failed-p
        (or (not (eq (process-status process) 'exit))
            (/= (process-exit-status process) 0))))

(defun bs-mu4e--main-retrieval-cleanup (&rest _)
  "Schedule a retry when failed retrieval does not continue indexing."
  (when (and bs-mu4e--main-update-failed-p
             (not mu4e-index-update-error-continue))
    (bs-mu4e--main-schedule-retry)))

(defun bs-mu4e--main-index-finished ()
  "Record the completion of Mu4e indexing."
  (if bs-mu4e--main-update-failed-p
      (bs-mu4e--main-schedule-retry)
    (bs-mu4e--main-cancel-retry)
    (setq bs-mu4e--main-update-state 'idle)
    (bs-mu4e--main-force-header-update)))

(defun bs-mu4e--main-filtered-maildir-item (maildir)
  "Return the active context query item for MAILDIR."
  (seq-find
   (lambda (item)
     (and (plist-get item :bs-maildir)
          (equal (plist-get item :maildir) maildir)))
   (bs-mu4e--main-query-items)))

(defun bs-mu4e--main-search-maildir (maildir &optional edit)
  "Search MAILDIR within the active context.
With EDIT, offer to edit the generated query first."
  (interactive
   (let ((maildir (mu4e-ask-maildir "Jump to maildir: ")))
     (list maildir current-prefix-arg)))
  (when maildir
    (let* ((item (bs-mu4e--main-filtered-maildir-item maildir))
           (query
            (or (plist-get item :query)
                (format "(%s) AND (maildir:\"%s\")"
                        bs-mu4e-context-query maildir)))
           (query
            (if edit
                (mu4e-search-read-query "Refine query: " query)
              query)))
      (mu4e-mark-handle-when-leaving)
      (mu4e-search query))))

(defun bs-mu4e--main-resize-refresh (buffer)
  "Redraw Mu4e Main BUFFER after a resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-mu4e--main-resize-timer nil)
      (bs-mu4e--main-redraw))))

(defun bs-mu4e--main-window-size-change (_frame)
  "Schedule a redraw when the Mu4e Main window width changes."
  (when-let* ((buffer (get-buffer mu4e-main-buffer-name))
              (window (get-buffer-window buffer t)))
    (with-current-buffer buffer
      (let ((width (window-body-width window)))
        (unless (equal width bs-mu4e--main-render-width)
          (when (timerp bs-mu4e--main-resize-timer)
            (cancel-timer bs-mu4e--main-resize-timer))
          (setq bs-mu4e--main-resize-timer
                (run-at-time
                 0.2 nil #'bs-mu4e--main-resize-refresh buffer)))))))

(defun bs-mu4e--main-configure-buffer ()
  "Configure the current Mu4e Main buffer."
  (setq-local truncate-lines t
              header-line-format '(:eval (bs-mu4e--main-header))
              outline-regexp "\\*+")
  (outline-minor-mode 1)
  (hl-line-mode 1)
  (use-local-map (copy-keymap (current-local-map)))
  (local-set-key (kbd "RET") #'bs-mu4e-main-activate)
  (local-set-key (kbd "TAB") #'bs-mu4e-main-toggle-topic)
  (local-set-key (kbd "<tab>") #'bs-mu4e-main-toggle-topic)
  (local-set-key (kbd "h") #'mu4e-display-manual)
  (add-hook 'post-command-hook
            #'bs-mu4e--main-update-indicators nil t))

;;;###autoload
(defun bs-mu4e-main-enable ()
  "Enable the Gnus-inspired Mu4e Main renderer."
  (interactive)
  (require 'mu4e-main)
  (require 'mu4e-search)
  (require 'mu4e-update)
  (require 'outline)
  (unless bs-mu4e--main-enabled
    (setq bs-mu4e--main-enabled t)
    (advice-add 'mu4e--main-redraw :override #'bs-mu4e--main-redraw)
    (advice-add 'mu4e-search-maildir :override
                #'bs-mu4e--main-search-maildir)
    (advice-add 'mu4e-update-index :before
                #'bs-mu4e--main-index-started)
    (advice-add 'mu4e--update-sentinel-func :before
                #'bs-mu4e--main-retrieval-finished)
    (advice-add 'mu4e--update-sentinel-func :after
                #'bs-mu4e--main-retrieval-cleanup)
    (add-hook 'mu4e-main-mode-hook #'bs-mu4e--main-configure-buffer)
    (add-hook 'mu4e-context-changed-hook #'bs-mu4e--main-redraw)
    (add-hook 'mu4e-update-pre-hook #'bs-mu4e--main-update-started)
    (add-hook 'mu4e-index-updated-hook #'bs-mu4e--main-index-finished)
    (add-hook 'window-size-change-functions
              #'bs-mu4e--main-window-size-change)
    (unless (timerp bs-mu4e--main-clock-timer)
      (setq bs-mu4e--main-clock-timer
            (run-at-time 0 30 #'bs-mu4e--main-force-header-update))))
  (when-let* ((buffer (get-buffer mu4e-main-buffer-name)))
    (with-current-buffer buffer
      (bs-mu4e--main-configure-buffer)
      (bs-mu4e--main-redraw))))

;;;###autoload
(defun bs-mu4e-main-disable ()
  "Restore Mu4e's native Main renderer."
  (interactive)
  (when bs-mu4e--main-enabled
    (setq bs-mu4e--main-enabled nil)
    (advice-remove 'mu4e--main-redraw #'bs-mu4e--main-redraw)
    (advice-remove 'mu4e-search-maildir
                   #'bs-mu4e--main-search-maildir)
    (advice-remove 'mu4e-update-index #'bs-mu4e--main-index-started)
    (advice-remove 'mu4e--update-sentinel-func
                   #'bs-mu4e--main-retrieval-finished)
    (advice-remove 'mu4e--update-sentinel-func
                   #'bs-mu4e--main-retrieval-cleanup)
    (remove-hook 'mu4e-main-mode-hook #'bs-mu4e--main-configure-buffer)
    (remove-hook 'mu4e-context-changed-hook #'bs-mu4e--main-redraw)
    (remove-hook 'mu4e-update-pre-hook #'bs-mu4e--main-update-started)
    (remove-hook 'mu4e-index-updated-hook #'bs-mu4e--main-index-finished)
    (remove-hook 'window-size-change-functions
                 #'bs-mu4e--main-window-size-change)
    (bs-mu4e--main-cancel-retry)
    (when (timerp bs-mu4e--main-clock-timer)
      (cancel-timer bs-mu4e--main-clock-timer))
    (setq bs-mu4e--main-clock-timer nil)
    (when-let* ((buffer (get-buffer mu4e-main-buffer-name)))
      (with-current-buffer buffer
        (mu4e-main-mode)))
    (mu4e--main-redraw)))

(defface bs-mu4e-headers-title-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for thread subjects in Headers buffers."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-correspondent-face
  '((t :inherit mu4e-header-face :slant italic))
  "Face for message correspondents in thread listings."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-unread-correspondent-face
  '((t :inherit default :weight bold :slant italic))
  "Face for correspondents of unread messages."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for the complete Mu4e Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in the Mu4e Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-query-face
  '((t :inherit font-lock-keyword-face :weight bold :slant italic))
  "Face used for the query in the Mu4e Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-context-face
  '((t :inherit font-lock-keyword-face))
  "Face used for the context in the Mu4e Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-unread-face
  '((t :inherit error :weight semibold))
  "Face used for nonzero unread counts in the Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-shown-face
  '((t :inherit success))
  "Face used for shown-message counts in the Headers header line."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-header-muted-face
  '((t :inherit shadow :weight normal :slant normal))
  "Face used for secondary Mu4e Headers statistics."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-month-face
  '((t :inherit font-lock-keyword-face
       :height 1.10 :underline nil :extend t))
  "Face used for root-message month separators in Headers buffers."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-unread-flag-face
  '((t :inherit error :weight bold))
  "Face used for new and unread Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-attention-flag-face
  '((t :inherit warning :weight bold))
  "Face used for flagged and draft Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-activity-flag-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face used for reply and forwarding Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-metadata-flag-face
  '((t :inherit font-lock-keyword-face :weight normal))
  "Face used for attachment and calendar Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-secure-flag-face
  '((t :inherit success :weight normal))
  "Face used for signed and encrypted Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-negative-flag-face
  '((t :inherit error :weight bold))
  "Face used for trashed Mu4e flags."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-quiet-flag-face
  '((t :inherit shadow))
  "Face used for secondary Mu4e flags."
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
       :weight normal :slant normal :strike-through nil))
  "Face for message timestamps."
  :group 'bs-mu4e)

(defface bs-mu4e-headers-fold-indicator-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for folded-reply indicators."
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-fold-indicator ?▸
  "Character displayed at the left edge of a message with folded replies."
  :type 'character
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-thread-count-digits 4
  "Minimum decimal digits reserved for thread message counts."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-thread-count-padding 0.5
  "Colored padding beside thread message counts, in character widths."
  :type 'number
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-month-format "%Y %b"
  "Format used for root-message month separators in Headers buffers."
  :type 'string
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-month-line-spacing 0.65
  "Relative spacing added above and below Headers month separators."
  :type 'number
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-header-bottom-spacing 0.5
  "Relative line height reserved below the Mu4e Headers header."
  :type 'number
  :group 'bs-mu4e)

(defcustom bs-mu4e-context-buffer-name "*Mu4e Thread Context*"
  "Name of the buffer containing the latest Mu4e context."
  :type 'string
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-display-thread-context nil
  "Whether to display the generated thread context buffer.
When nil, keep the buffer named by `bs-mu4e-context-buffer-name'
hidden and select the current Headers row.  When non-nil, display
that buffer and select all of its text."
  :type 'boolean
  :group 'bs-mu4e)

(defcustom bs-mu4e-headers-thread-context-hook nil
  "Hook run after preparing a Mu4e context.
The hook runs in the originating Headers or Main buffer while the
buffer named by `bs-mu4e-context-buffer-name' contains the selected
subthread or today's messages."
  :type 'hook
  :group 'bs-mu4e)

(defcustom bs-mu4e-ignored-contact-local-part-regexp
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
  "Regexp matching compact local parts ignored by contact completion.

The local part is lower-cased, truncated before a plus tag, and
then stripped of dots, dashes, and underscores before matching.
This intentionally focuses on automated and non-reply senders,
not every role-based mailbox such as support or info."
  :type 'regexp
  :group 'bs-mu4e)

(defcustom bs-mu4e-ignored-contact-display-name-regexp
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
  "Regexp matching display names ignored by contact completion."
  :type 'regexp
  :group 'bs-mu4e)

(defcustom bs-mu4e-ignored-contact-email-regexps nil
  "Regexps matching complete emails ignored by contact completion.

Each regexp is matched against a lower-cased bare email address.
The first matching regexp is reported by
`bs-mu4e-contact-ignore-reasons'."
  :type '(repeat regexp)
  :group 'bs-mu4e)

(defcustom bs-mu4e-notifications-app-icon 'mail-unread
  "Fallback application icon used for Mu4e notifications.

A symbol names an icon from the desktop icon theme.  A string is
interpreted as an image file.  Nil requests no application icon."
  :type '(choice (const :tag "No application icon" nil)
                 (symbol :tag "Desktop icon name")
                 (file :tag "Image file"))
  :group 'bs-mu4e)

(defcustom bs-mu4e-notifications-avatar-cache-directory
  (locate-user-emacs-file "cache/mu4e/notification-avatars/")
  "Directory containing persistent Mu4e notification avatars."
  :type 'directory
  :group 'bs-mu4e)

(defcustom bs-mu4e-notifications-avatar-cache-expiry
  (* 90 24 60 60)
  "Seconds before a cached Mu4e notification avatar expires."
  :type 'natnum
  :group 'bs-mu4e)

(defcustom bs-mu4e-notifications-timeout nil
  "Milliseconds before a Mu4e notification closes automatically.
Nil uses the notification server default.  Zero means never close
automatically."
  :type '(choice (const :tag "Server default" nil)
                 (integer :tag "Milliseconds"))
  :group 'bs-mu4e)

(defcustom bs-mu4e-notifications-read-display-function
  #'bs-call-in-new-frame
  "Function used to display Mu4e notification Read actions.
The function receives the action function followed by its arguments.
Use `bs-call-in-current-frame' or `bs-call-in-new-frame' for the
standard behaviors."
  :type 'function
  :group 'bs-mu4e)

(defvar bs-mu4e--notifications-avatar-generation 0
  "Generation identifying relevant asynchronous avatar callbacks.")

(defvar bs-mu4e--notifications-avatar-waiters
  (make-hash-table :test #'equal)
  "Messages waiting for each normalized sender avatar address.")

(defvar bs-mu4e--notifications-enabled nil
  "Non-nil when Mu4e Alert delivery is handled by bs-mu4e.")

(defvar bs-mu4e--notifications-client
  (bs-notifications-create-client
   :source 'mu4e
   :key-function #'bs-mu4e--notifications-key
   :delivery-function #'bs-mu4e--notifications-deliver
   :error-function #'bs-mu4e--notifications-report-error)
  "Mu4e client of the shared desktop notification queue.")

(defvar bs-mu4e--notifications-id-to-message-id nil
  "Alist mapping desktop notification identifiers to message IDs.")

(defvar bs-mu4e--view-xwidget-enabled nil
  "Non-nil when displayed Mu4e HTML opens automatically in Xwidget.")

(defvar bs-mu4e--view-xwidget-buffer nil
  "Dedicated Xwidget buffer used to render Mu4e HTML.")

(defvar bs-mu4e--view-xwidget-opening-source nil
  "Mu4e View buffer currently opening HTML in Xwidget.")

(defvar-local bs-mu4e--view-xwidget-local-map nil
  "Mu4e keymap installed in the current dedicated Xwidget buffer.")

(defvar-local bs-mu4e--view-xwidget-original-local-map nil
  "Original local keymap of the current dedicated Xwidget buffer.")

(defvar-local bs-mu4e--view-xwidget-source nil
  "Mu4e View buffer rendered by the current dedicated Xwidget buffer.")

(defvar-local bs-mu4e--view-xwidget-return-buffer nil
  "Xwidget renderer to restore after a bridged View command.")

(defvar-local bs-mu4e--view-xwidget-return-docid nil
  "Message docid for the pending return to an Xwidget renderer.")

(defvar bs-mu4e--view-xwidget-navigation-window nil
  "Window to reuse for a View reached from the Xwidget renderer.")

(defvar bs-mu4e--view-xwidget-navigation-docid nil
  "Expected docid for the pending View navigation.")

(defvar bs-mu4e--view-xwidget-navigation-timer nil
  "Timer that expires pending Xwidget View navigation state.")

(defconst bs-mu4e--view-xwidget-navigation-commands
  '(mu4e-headers-next
    mu4e-headers-prev
    mu4e-view-headers-next-thread
    mu4e-view-headers-next-unread
    mu4e-view-headers-prev-thread
    mu4e-view-headers-prev-unread)
  "View commands that can replace the message shown by the renderer.")

(defvar bs-mu4e--view-xwidget-renderer-map
  (let ((map (make-sparse-keymap)))
    (dolist (key '("SPC" "RET" "C-v" "<next>"))
      (define-key map (kbd key) #'xwidget-webkit-scroll-up))
    (dolist (key '("S-SPC" "<backspace>" "M-v" "<prior>"))
      (define-key map (kbd key) #'xwidget-webkit-scroll-down))
    map)
  "Page-scrolling bindings used by the dedicated Xwidget renderer.")

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

(defun bs-mu4e-contact-ignore-reasons (address)
  "Return an alist explaining why ADDRESS is hidden from completion.

Possible keys are `email-regexp', `local-part', and `display-name'.
The associated value is respectively the matching complete-email
regexp, compact local part, or normalized display name.  Return nil
when ADDRESS is not ignored."
  (let* ((parsed (and (stringp address)
                      (mail-header-parse-address-lax address)))
         (email (if (consp parsed) (car parsed) parsed))
         (email (and (stringp email)
                     (downcase (string-trim email))))
         (name (and (consp parsed)
                    (bs-mu4e-trim-contact-name (cdr parsed))))
         (name (and name (downcase name)))
         (local-part (bs-mu4e-email-compact-local-part email))
         (email-regexp
          (and email
               (cl-find-if
                (lambda (regexp)
                  (string-match-p regexp email))
                bs-mu4e-ignored-contact-email-regexps))))
    (delq
     nil
     (list
      (and email-regexp (cons 'email-regexp email-regexp))
      (and local-part
           (string-match-p
            bs-mu4e-ignored-contact-local-part-regexp
            local-part)
           (cons 'local-part local-part))
      (and name
           (string-match-p
            bs-mu4e-ignored-contact-display-name-regexp
            name)
           (cons 'display-name name))))))

(defun bs-mu4e-ignored-mail-address-p (address)
  "Return non-nil when ADDRESS looks like an automated sender."
  (and (bs-mu4e-contact-ignore-reasons address) t))

(defun bs-mu4e-completion-candidate (candidate)
  "Return normalized CANDIDATE, or nil when it should be hidden."
  (when (stringp candidate)
    (let ((candidate (bs-mu4e-clean-mail-address candidate)))
      (unless (bs-mu4e-ignored-mail-address-p candidate)
        candidate))))

(defun bs-mu4e--clean-mu4e-contact-completion-set ()
  "Return a cleaned copy of `mu4e--contacts-set'."
  (when (and (boundp 'mu4e--contacts-set)
             (hash-table-p mu4e--contacts-set))
    (let ((contacts (make-hash-table
                     :test 'equal
                     :size (hash-table-count mu4e--contacts-set))))
      (maphash
       (lambda (candidate _value)
         (when-let* ((candidate
                      (bs-mu4e-completion-candidate candidate)))
           (puthash candidate t contacts)))
       mu4e--contacts-set)
      contacts)))

(defun bs-mu4e-mu4e-contact-completion-set ()
  "Return khard and mu4e contacts merged for mail completion.

If the khard backend is unavailable or fails, report the problem and
return cleaned mu4e history candidates instead."
  (unless (fboundp 'bs-contacts-mail-completion-set)
    (require 'bs-contacts nil t))
  (if (not (fboundp 'bs-contacts-mail-completion-set))
      (bs-mu4e--clean-mu4e-contact-completion-set)
    (condition-case error-data
        (bs-contacts-mail-completion-set mu4e--contacts-set)
      (error
       (message "Khard contacts unavailable; using mu4e history: %s"
                (error-message-string error-data))
       (bs-mu4e--clean-mu4e-contact-completion-set)))))

(defun bs-mu4e-mu4e-compose-complete-handler (function str pred action)
  "Call Mu4e completion FUNCTION with STR, PRED, and ACTION.

Use cleaned contact candidates for the duration of the call."
  (let ((mu4e--contacts-set
         (or (bs-mu4e-mu4e-contact-completion-set)
             mu4e--contacts-set)))
    (funcall function str pred action)))

(defun bs-mu4e-add-around-advice (symbol function)
  "Add FUNCTION as around advice to SYMBOL unless already present."
  (unless (advice-member-p function symbol)
    (advice-add symbol :around function)))

;;;###autoload
(defun bs-mu4e-compose-completion-enable ()
  "Make mu4e compose contact completion use bs-mu4e candidates."
  (interactive)
  (with-eval-after-load 'mu4e-compose
    (bs-mu4e-add-around-advice
     'mu4e--compose-complete-handler
     #'bs-mu4e-mu4e-compose-complete-handler)))

(defun bs-mu4e--notifications-avatar-address (mail)
  "Return MAIL's normalized sender address for avatar lookup."
  (when-let* ((contact (car (plist-get mail :from)))
              (address (mu4e-contact-email contact))
              ((stringp address))
              (address (downcase (string-trim address)))
              ((not (string-empty-p address))))
    address))

(defun bs-mu4e--notifications-write-avatar (file image)
  "Atomically write IMAGE data to avatar cache FILE.
Return FILE on success, or nil when IMAGE has no embedded data."
  (when-let* ((data (and (consp image)
                         (plist-get (cdr image) :data))))
    (bs-notifications-write-cache-data file data ".avatar-")))

(defun bs-mu4e--notifications-forget (id)
  "Forget the message associated with notification ID."
  (setq bs-mu4e--notifications-id-to-message-id
        (assq-delete-all id
                         bs-mu4e--notifications-id-to-message-id)))

(defun bs-mu4e--notifications-read (message-id)
  "Open the message identified by MESSAGE-ID through a Mu4e search.
Preserve the current Headers query in Mu4e's search history."
  (require 'mu4e-search)
  (funcall
   bs-mu4e-notifications-read-display-function
   #'mu4e-search
   (concat "msgid:" message-id)
   nil nil nil message-id t))

(defun bs-mu4e--notifications-mark-read (message-id)
  "Mark the message identified by MESSAGE-ID as read."
  (require 'mu4e-server)
  (mu4e--server-move message-id nil "+S-u-N"))

(defun bs-mu4e--notifications-action (id key)
  "Apply action KEY to the Mu4e message associated with notification ID."
  (when-let* ((message-id
               (alist-get id
                          bs-mu4e--notifications-id-to-message-id)))
    (unwind-protect
        (pcase key
          ((or "default" "read")
           (bs-mu4e--notifications-read message-id))
          ("mark-read"
           (bs-mu4e--notifications-mark-read message-id)))
      (bs-mu4e--notifications-forget id))))

(defun bs-mu4e--notifications-close (id _reason)
  "Forget the Mu4e message associated with closed notification ID.
REASON is ignored."
  (bs-mu4e--notifications-forget id))

(defun bs-mu4e--notifications-title (mail)
  "Return the sender title for MAIL."
  (let ((contacts (plist-get mail :from)))
    (if contacts
        (bs-mu4e-contact-display-names contacts)
      "?")))

(defun bs-mu4e--notifications-subject (mail)
  "Return the notification subject for MAIL."
  (let ((subject (plist-get mail :subject)))
    (if (and (stringp subject) (not (string-empty-p subject)))
        subject
      "(No subject)")))

(defun bs-mu4e--notifications-key (record)
  "Return the notification queue key for Mu4e RECORD."
  (plist-get (car record) :message-id))

(defun bs-mu4e--notifications-deliver (record)
  "Deliver Mu4e notification RECORD if it remains eligible."
  (pcase-let ((`(,mail ,avatar-file) record))
    (when (and bs-mu4e--notifications-enabled
               (stringp (plist-get mail :message-id)))
      (when-let* ((id
                   (notifications-notify
                    :title (bs-mu4e--notifications-title mail)
                    :body (bs-mu4e--notifications-subject mail)
                    :actions '("read" "Read"
                               "mark-read" "Mark As Read"
                               "default" "Read")
                    :on-action #'bs-mu4e--notifications-action
                    :on-close #'bs-mu4e--notifications-close
                    :app-icon bs-mu4e-notifications-app-icon
                    :image-path avatar-file
                    :app-name "mu4e"
                    :category "email.arrived"
                    :timeout bs-mu4e-notifications-timeout)))
        (setq bs-mu4e--notifications-id-to-message-id
              (cons (cons id (plist-get mail :message-id))
                    (assq-delete-all
                     id bs-mu4e--notifications-id-to-message-id)))))))

(defun bs-mu4e--notifications-report-error (record error-data)
  "Report ERROR-DATA encountered while notifying about Mu4e RECORD."
  (message "Failed to notify about Mu4e message %s: %s"
           (bs-mu4e--notifications-subject (car record))
           (error-message-string error-data)))

(defun bs-mu4e--notifications-send (mail avatar-file)
  "Queue MAIL with AVATAR-FILE for serial desktop notification delivery."
  (when (and bs-mu4e--notifications-enabled
             (stringp (plist-get mail :message-id)))
    (bs-notifications-enqueue
     bs-mu4e--notifications-client
     (list mail avatar-file))))

(defun bs-mu4e--notifications-avatar-retrieved
    (image address file generation)
  "Deliver messages waiting for an avatar retrieval.
IMAGE is the retrieved image or `error'.  ADDRESS and FILE identify
the cache entry.  GENERATION rejects callbacks from a disabled
notification adapter."
  (when (= generation bs-mu4e--notifications-avatar-generation)
    (let ((mails (gethash address
                          bs-mu4e--notifications-avatar-waiters)))
      (remhash address bs-mu4e--notifications-avatar-waiters)
      (when (and bs-mu4e--notifications-enabled mails)
        (let ((avatar-file
               (and (not (eq image 'error))
                    (condition-case nil
                        (bs-mu4e--notifications-write-avatar file image)
                      (error nil)))))
          (dolist (mail (nreverse mails))
            (bs-mu4e--notifications-send mail avatar-file)))))))

(defun bs-mu4e--notifications-prepare (mail)
  "Deliver MAIL after resolving its cached or remote sender avatar."
  (if-let* ((address (bs-mu4e--notifications-avatar-address mail))
            (file
             (bs-notifications-cache-file
              bs-mu4e-notifications-avatar-cache-directory address)))
      (cond
       ((bs-notifications-cache-current-p
         file bs-mu4e-notifications-avatar-cache-expiry)
        (bs-mu4e--notifications-send mail file))
       ((gethash address bs-mu4e--notifications-avatar-waiters)
        (push mail
              (gethash address
                       bs-mu4e--notifications-avatar-waiters)))
       (t
        (puthash address (list mail)
                 bs-mu4e--notifications-avatar-waiters)
        (condition-case nil
            (gravatar-retrieve
             address
             #'bs-mu4e--notifications-avatar-retrieved
             (list address file
                   bs-mu4e--notifications-avatar-generation))
          (error
           (bs-mu4e--notifications-avatar-retrieved
            'error address file
            bs-mu4e--notifications-avatar-generation)))))
    (bs-mu4e--notifications-send mail nil)))

(defun bs-mu4e-notifications-notify-unread-messages (mails)
  "Deliver one actionable desktop notification for every message in MAILS."
  (when bs-mu4e--notifications-enabled
    (dolist (mail mails)
      (bs-mu4e--notifications-prepare mail))
    (when mails
      (mu4e-alert-set-window-urgency-maybe))))

;;;###autoload
(defun bs-mu4e-notifications-disable ()
  "Restore `mu4e-alert' desktop notification delivery."
  (interactive)
  (when bs-mu4e--notifications-enabled
    (setq bs-mu4e--notifications-enabled nil)
    (cl-incf bs-mu4e--notifications-avatar-generation)
    (advice-remove
     'mu4e-alert-notify-unread-messages
     #'bs-mu4e-notifications-notify-unread-messages)
    (clrhash bs-mu4e--notifications-avatar-waiters)
    (bs-notifications-clear-client bs-mu4e--notifications-client)
    (dolist (entry bs-mu4e--notifications-id-to-message-id)
      (ignore-errors
        (notifications-close-notification (car entry))))
    (setq bs-mu4e--notifications-id-to-message-id nil)))

;;;###autoload
(defun bs-mu4e-notifications-enable ()
  "Deliver actionable per-message Mu4e notifications through `mu4e-alert'."
  (interactive)
  (require 'gravatar)
  (require 'mu4e-alert)
  (require 'notifications)
  (unless bs-mu4e--notifications-enabled
    (setq bs-mu4e--notifications-enabled t)
    (advice-add
     'mu4e-alert-notify-unread-messages
     :override #'bs-mu4e-notifications-notify-unread-messages)))

(defun bs-mu4e--view-xwidget-available-p ()
  "Return non-nil when this Emacs can display WebKit Xwidgets."
  (featurep 'xwidget-internal))

(defun bs-mu4e--view-xwidget-keymap-value (value)
  "Return the keymap represented by VALUE, or nil."
  (cond
   ((keymapp value) value)
   ((and (symbolp value)
         (boundp value)
         (keymapp (symbol-value value)))
    (symbol-value value))))

(defun bs-mu4e--view-xwidget-keymap (source)
  "Return active Mu4e View keymaps from SOURCE as one keymap."
  (with-current-buffer source
    (make-composed-keymap
     (append
      (list bs-mu4e--view-xwidget-renderer-map)
      (cl-loop
       for (mode . value) in minor-mode-map-alist
       for keymap = (bs-mu4e--view-xwidget-keymap-value value)
       when (and (symbolp mode)
                 (string-prefix-p "mu4e-" (symbol-name mode))
                 (boundp mode)
                 (symbol-value mode)
                 keymap)
       collect keymap)
      (list (current-local-map)
            (with-current-buffer bs-mu4e--view-xwidget-buffer
              bs-mu4e--view-xwidget-original-local-map))))))

(defun bs-mu4e--view-xwidget-clear-navigation ()
  "Clear pending Xwidget View navigation state."
  (when (timerp bs-mu4e--view-xwidget-navigation-timer)
    (cancel-timer bs-mu4e--view-xwidget-navigation-timer))
  (setq bs-mu4e--view-xwidget-navigation-window nil
        bs-mu4e--view-xwidget-navigation-docid nil
        bs-mu4e--view-xwidget-navigation-timer nil))

(defun bs-mu4e--view-xwidget-restore-renderer ()
  "Restore the Xwidget renderer after a bridged View command."
  (remove-hook 'post-command-hook
               #'bs-mu4e--view-xwidget-restore-renderer t)
  (let ((source (current-buffer))
        (renderer bs-mu4e--view-xwidget-return-buffer)
        (docid bs-mu4e--view-xwidget-return-docid))
    (setq bs-mu4e--view-xwidget-return-buffer nil
          bs-mu4e--view-xwidget-return-docid nil)
    (when (window-live-p bs-mu4e--view-xwidget-navigation-window)
      (let ((target-docid
             (when-let* ((headers (mu4e-get-headers-buffer)))
               (with-current-buffer headers
                 (mu4e~headers-docid-at-point)))))
        (if (and target-docid (not (equal target-docid docid)))
            (setq bs-mu4e--view-xwidget-navigation-docid target-docid
                  bs-mu4e--view-xwidget-navigation-timer
                  (run-at-time
                   5 nil #'bs-mu4e--view-xwidget-clear-navigation))
          (bs-mu4e--view-xwidget-clear-navigation))))
    (when (and (buffer-live-p renderer)
               (eq (window-buffer (selected-window)) source)
               (derived-mode-p 'mu4e-view-mode)
               (mu4e--view-html-displayed-p)
               (equal docid
                      (mu4e-message-field mu4e--view-message :docid))
               (with-current-buffer renderer
                 (eq bs-mu4e--view-xwidget-source source)))
      (switch-to-buffer renderer))))

(defun bs-mu4e--view-xwidget-display-buffer
    (function buffer-or-name &optional select)
  "Reuse the pending renderer window when FUNCTION displays a View.

BUFFER-OR-NAME and SELECT are the arguments of `mu4e-display-buffer'."
  (let ((buffer (get-buffer buffer-or-name))
        (window bs-mu4e--view-xwidget-navigation-window))
    (if (and (buffer-live-p buffer)
             (window-live-p window)
             (not (window-dedicated-p window))
             (with-current-buffer buffer
               (and (derived-mode-p 'mu4e-view-mode)
                    (or (null bs-mu4e--view-xwidget-navigation-docid)
                        (equal
                         bs-mu4e--view-xwidget-navigation-docid
                         (mu4e-message-field mu4e--view-message :docid))))))
        (progn
          (bs-mu4e--view-xwidget-clear-navigation)
          (set-window-buffer window buffer)
          (when select
            (select-window window))
          window)
      (funcall function buffer-or-name select))))

(defun bs-mu4e--view-xwidget-detach ()
  "Restore the current Xwidget buffer's native command map."
  (bs-mu4e--view-xwidget-clear-navigation)
  (when (buffer-live-p bs-mu4e--view-xwidget-source)
    (with-current-buffer bs-mu4e--view-xwidget-source
      (remove-hook 'post-command-hook
                   #'bs-mu4e--view-xwidget-restore-renderer t)
      (setq bs-mu4e--view-xwidget-return-buffer nil
            bs-mu4e--view-xwidget-return-docid nil)))
  (remove-hook 'pre-command-hook
               #'bs-mu4e--view-xwidget-redirect-command t)
  (when bs-mu4e--view-xwidget-original-local-map
    (use-local-map bs-mu4e--view-xwidget-original-local-map))
  (setq bs-mu4e--view-xwidget-local-map nil
        bs-mu4e--view-xwidget-original-local-map nil
        bs-mu4e--view-xwidget-source nil))

(defun bs-mu4e--view-xwidget-redirect-command ()
  "Run a bridged Mu4e command in its associated View buffer."
  (if (not (buffer-live-p bs-mu4e--view-xwidget-source))
      (progn
        (bs-mu4e--view-xwidget-detach)
        (user-error "The associated Mu4e View buffer is no longer live"))
    (let* ((keys (this-command-keys-vector))
           (local-command
            (lookup-key bs-mu4e--view-xwidget-local-map keys))
           (source-command
            (with-current-buffer bs-mu4e--view-xwidget-source
              (key-binding keys t))))
      (when (and (commandp local-command)
                 (eq this-command source-command))
        (unless (eq this-command 'mu4e-context-switch)
          (let ((renderer (current-buffer))
                (source bs-mu4e--view-xwidget-source))
            (with-current-buffer bs-mu4e--view-xwidget-source
              (setq bs-mu4e--view-xwidget-return-buffer renderer
                    bs-mu4e--view-xwidget-return-docid
                    (mu4e-message-field mu4e--view-message :docid))
              (add-hook 'post-command-hook
                        #'bs-mu4e--view-xwidget-restore-renderer nil t))
            (if (memq this-command
                      bs-mu4e--view-xwidget-navigation-commands)
                (progn
                  (bs-mu4e--view-xwidget-clear-navigation)
                  (setq bs-mu4e--view-xwidget-navigation-window
                        (selected-window))
                  (set-buffer source))
              (switch-to-buffer source))))))))

(defun bs-mu4e--view-xwidget-attach (buffer source)
  "Use BUFFER only to render HTML for Mu4e View buffer SOURCE."
  (with-current-buffer buffer
    (unless bs-mu4e--view-xwidget-original-local-map
      (setq bs-mu4e--view-xwidget-original-local-map
            (current-local-map)))
    (setq bs-mu4e--view-xwidget-source source
          bs-mu4e--view-xwidget-local-map
          (bs-mu4e--view-xwidget-keymap source))
    (use-local-map bs-mu4e--view-xwidget-local-map)
    (add-hook 'pre-command-hook
              #'bs-mu4e--view-xwidget-redirect-command nil t)))

(defun bs-mu4e--view-xwidget-browse-url (url &optional _new-window)
  "Render URL in the dedicated Mu4e Xwidget buffer."
  (require 'xwidget)
  (let ((last-session
         (and (not (eq xwidget-webkit-last-session-buffer
                       bs-mu4e--view-xwidget-buffer))
              xwidget-webkit-last-session-buffer))
        (buffer
         (and (buffer-live-p bs-mu4e--view-xwidget-buffer)
              bs-mu4e--view-xwidget-buffer)))
    (unwind-protect
        (let ((xwidget
               (and buffer
                    (with-current-buffer buffer
                      (xwidget-at (point-min))))))
          (if xwidget
              (progn
                (switch-to-buffer buffer)
                (xwidget-webkit-goto-uri xwidget url))
            (when buffer
              (with-current-buffer buffer
                (bs-mu4e--view-xwidget-detach)))
            (setq xwidget-webkit-last-session-buffer nil)
            (xwidget-webkit-new-session url)
            (setq buffer (current-buffer)
                  bs-mu4e--view-xwidget-buffer buffer))
          (when (buffer-live-p bs-mu4e--view-xwidget-opening-source)
            (bs-mu4e--view-xwidget-attach
             buffer bs-mu4e--view-xwidget-opening-source))
          buffer)
      (setq xwidget-webkit-last-session-buffer last-session))))

(defun bs-mu4e--view-open-html-in-xwidget ()
  "Open the displayed Mu4e HTML alternative in an Xwidget."
  (when (and bs-mu4e--view-xwidget-enabled
             (derived-mode-p 'mu4e-view-mode)
             (bs-mu4e--view-xwidget-available-p)
             (mu4e--view-html-displayed-p)
             mu4e--view-message)
    (condition-case error-data
        (let ((bs-mu4e--view-xwidget-opening-source
               (current-buffer))
              (browse-url-handlers nil)
              (browse-url-browser-function
               #'bs-mu4e--view-xwidget-browse-url))
          (mu4e-action-view-in-browser mu4e--view-message))
      (error
       (display-warning
        'bs-mu4e
        (format "Unable to open Mu4e HTML in Xwidget: %s"
                (error-message-string error-data))
        :warning)))))

(defun bs-mu4e--view-after-toggle-html (&rest _arguments)
  "Open Xwidget after a Mu4e View command switches to HTML."
  (bs-mu4e--view-open-html-in-xwidget))

(defun bs-mu4e--view-xwidget-install ()
  "Install automatic Xwidget display for Mu4e HTML views."
  (remove-hook 'mu4e-view-rendered-hook
               #'bs-mu4e--view-open-html-in-xwidget)
  (add-hook 'mu4e-view-rendered-hook
            #'bs-mu4e--view-open-html-in-xwidget t)
  (bs-mu4e-add-around-advice
   'mu4e-display-buffer #'bs-mu4e--view-xwidget-display-buffer)
  (unless (advice-member-p
           #'bs-mu4e--view-after-toggle-html
           'mu4e-view-toggle-html)
    (advice-add 'mu4e-view-toggle-html
                :after #'bs-mu4e--view-after-toggle-html)))

;;;###autoload
(defun bs-mu4e-view-xwidget-disable ()
  "Stop opening displayed Mu4e HTML automatically in Xwidget."
  (interactive)
  (setq bs-mu4e--view-xwidget-enabled nil)
  (when (buffer-live-p bs-mu4e--view-xwidget-buffer)
    (with-current-buffer bs-mu4e--view-xwidget-buffer
      (bs-mu4e--view-xwidget-detach)))
  (when (featurep 'mu4e-view)
    (remove-hook 'mu4e-view-rendered-hook
                 #'bs-mu4e--view-open-html-in-xwidget)
    (advice-remove 'mu4e-display-buffer
                   #'bs-mu4e--view-xwidget-display-buffer)
    (advice-remove 'mu4e-view-toggle-html
                   #'bs-mu4e--view-after-toggle-html)))

;;;###autoload
(defun bs-mu4e-view-xwidget-enable ()
  "Open displayed Mu4e HTML automatically when Xwidget is available."
  (interactive)
  (setq bs-mu4e--view-xwidget-enabled t)
  (with-eval-after-load 'mu4e-view
    (when bs-mu4e--view-xwidget-enabled
      (bs-mu4e--view-xwidget-install))))

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

(defconst bs-mu4e--headers-root-prefix "*  "
  "Prefix displayed for the root message of a thread.")

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
  "Hash table mapping folded anchor docids to non-nil values.")

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

(defvar-local bs-mu4e--headers-threads nil
  "Ordered thread plists for the current headers search.")

;; Mu4e calls `mu4e-headers-mode' for every search, which normally
;; kills buffer-local values.  These two values must survive so a
;; rerun of the same query can preserve folding.
(put 'bs-mu4e--headers-fold-state 'permanent-local t)
(put 'bs-mu4e--headers-last-query 'permanent-local t)

(defun bs-mu4e--headers-field-width (field fallback)
  "Return configured width for FIELD, or FALLBACK."
  (let ((width (cdr (assq field mu4e-headers-fields))))
    (if (natnump width) width fallback)))

(defun bs-mu4e--headers-fit (string width)
  "Return STRING truncated or space-padded to WIDTH columns."
  (let ((string (bs-truncate-string string width)))
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

(defun bs-mu4e--headers-correspondent (msg)
  "Return the sender display string for MSG."
  (bs-mu4e-contact-display-names
   (mu4e-message-field msg :from)))

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
                             (bs-sanitize-single-line tag))
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

(defun bs-mu4e--headers-thread-count-padding-width ()
  "Return the display width of one thread-count padding edge."
  (max 0.0
       (min 0.5 bs-mu4e-headers-thread-count-padding)))

(defun bs-mu4e--headers-thread-content-column (count-width)
  "Return the shared thread-content column for COUNT-WIDTH."
  (ceiling
   (max (+ (string-width mu4e--mark-fringe)
           (bs-mu4e--headers-field-width :flags 0))
        (+ count-width
           (* 2 (bs-mu4e--headers-thread-count-padding-width))
           1))))

(defun bs-mu4e--headers-title-line
    (thread width count-width content-column)
  "Return the title line for THREAD fitted to WIDTH.

Right-align its message-count label to COUNT-WIDTH columns and align
its subject to CONTENT-COLUMN."
  (let* ((messages (plist-get thread :messages))
         (root (car messages))
         (padding-width (bs-mu4e--headers-thread-count-padding-width))
         (count-face
          (if (> (bs-mu4e--headers-thread-unread-count thread) 0)
              'bs-mu4e-headers-unread-thread-count-face
            'bs-mu4e-headers-thread-count-face))
         (count-padding
          (bs-mu4e--headers-space
           padding-width count-face))
         (count-gap
          (propertize
           " " 'display `(space :align-to ,content-column)))
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
         (subject (bs-sanitize-single-line
                   (mu4e-message-field root :subject)))
         (tag-limit
          (min
           (floor width 3)
           (max
            0
            (floor (- width content-column 1)))))
         (tags (bs-mu4e--headers-tag-string
                (mu4e-message-field root :tags)
                tag-limit))
         (reserved (+ content-column
                      (if (string-empty-p tags)
                          0
                        (1+ (string-width tags)))))
         (subject (bs-truncate-string
                   subject (max 0 (floor (- width reserved)))))
         (left (concat count count-gap subject))
         (left-width (+ content-column (string-width subject)))
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

(defun bs-mu4e--headers-flag-face (flag)
  "Return the semantic face for Mu4e FLAG."
  (pcase flag
    ((or 'new 'unread) 'bs-mu4e-headers-unread-flag-face)
    ((or 'flagged 'draft) 'bs-mu4e-headers-attention-flag-face)
    ((or 'passed 'replied) 'bs-mu4e-headers-activity-flag-face)
    ((or 'attach 'calendar) 'bs-mu4e-headers-metadata-flag-face)
    ((or 'encrypted 'signed) 'bs-mu4e-headers-secure-flag-face)
    ('trashed 'bs-mu4e-headers-negative-flag-face)
    (_ 'bs-mu4e-headers-quiet-flag-face)))

(defun bs-mu4e--headers-flags (msg width)
  "Return individually highlighted flags for MSG fitted to WIDTH."
  (let ((flags (mu4e-message-field msg :flags)))
    (bs-mu4e--headers-fit
     (mapconcat
      (lambda (flag)
        (if (memq flag mu4e-headers-visible-flags)
            (propertize
             (mu4e~headers-flags-str (list flag))
             'font-lock-face (bs-mu4e--headers-flag-face flag))
          ""))
      flags "")
     width)))

(defun bs-mu4e--headers-message-line
    (msg prefix width content-column)
  "Return a rendered message line for MSG with PREFIX at WIDTH.

Align PREFIX to CONTENT-COLUMN without changing the flags field."
  (let* ((native-flags (mu4e~headers-field-value msg :flags))
         (flags-width (bs-mu4e--headers-field-width
                       :flags (string-width native-flags)))
         (flags (bs-mu4e--headers-flags msg flags-width))
         (prefix-padding
          (bs-mu4e--headers-space
           (max 0
                (- content-column
                   (string-width mu4e--mark-fringe)
                   flags-width))))
         (date (concat (mu4e~headers-field-value msg :human-date) " "))
         (correspondent (bs-mu4e--headers-correspondent msg))
         (correspondent-width
          (max 0
               (- width
                  content-column
                  (string-width prefix)
                  (string-width date)
                  1)))
         (correspondent (bs-truncate-string
                         correspondent correspondent-width))
         (correspondent-start
          (+ (length mu4e--mark-fringe)
             (length flags)
             (length prefix-padding)
             (length prefix)))
         (left (concat mu4e--mark-fringe
                       flags
                       prefix-padding
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
  (bs-sanitize-single-line
   (if (stringp list-buffers-directory)
       list-buffers-directory
     "")))

(defun bs-mu4e--headers-message-count ()
  "Return the number of messages in the current Headers model."
  (cl-loop for thread in bs-mu4e--headers-threads
           sum (length (plist-get thread :messages))))

(defun bs-mu4e--headers-unread-count ()
  "Return the number of unread messages in the Headers model."
  (cl-loop for thread in bs-mu4e--headers-threads
           sum (bs-mu4e--headers-thread-unread-count thread)))

(defun bs-mu4e--headers-context-total (fallback)
  "Return the active context total, or FALLBACK when unavailable."
  (or (when-let* ((summary
                   (bs-mu4e--main-summary
                    (bs-mu4e--main-query-items))))
        (plist-get summary :count))
      fallback))

(defun bs-mu4e--headers-statistics ()
  "Return right-side statistics for the Headers header line."
  (let* ((shown (bs-mu4e--headers-message-count))
         (unread (bs-mu4e--headers-unread-count))
         (total (bs-mu4e--headers-context-total shown))
         (separator
          (propertize " · " 'face 'bs-mu4e-headers-header-muted-face)))
    (concat
     (propertize
      (bs-sanitize-single-line bs-mu4e-context-name)
      'face 'bs-mu4e-headers-header-context-face)
     separator
     (propertize
      (number-to-string unread)
      'face (if (> unread 0)
                'bs-mu4e-headers-header-unread-face
              'bs-mu4e-headers-header-muted-face))
     (propertize " unread" 'face 'bs-mu4e-headers-header-muted-face)
     separator
     (propertize
      (number-to-string shown) 'face 'bs-mu4e-headers-header-shown-face)
     (propertize " shown" 'face 'bs-mu4e-headers-header-muted-face)
     separator
     (propertize
      (format "%d total" total)
      'face 'bs-mu4e-headers-header-muted-face))))

(defun bs-mu4e--headers-header ()
  "Return the Headers query with right-aligned statistics."
  (let* ((width (bs-mu4e--headers-width))
         (statistics (bs-mu4e--headers-statistics))
         (identity
          (concat
           (propertize "SEARCH " 'face 'bs-mu4e-headers-header-label-face)
           (propertize
            (bs-mu4e--headers-query)
            'face 'bs-mu4e-headers-header-query-face)))
         (identity
          (bs-truncate-string
           identity
           (max 0 (- width (string-width statistics) 2))))
         (header
          (concat
           identity
           (bs-right-padding statistics)
           statistics)))
    (add-face-text-property
     0 (length header) 'bs-mu4e-headers-header-face t header)
    header))

(defun bs-mu4e--headers-thread-month (thread)
  "Return the root message month key and title for THREAD."
  (let ((date
         (mu4e-message-field
          (car (plist-get thread :messages)) :date)))
    (condition-case nil
        (if (equal date '(0 0 0))
            '("undated" . "Undated")
          (cons (format-time-string "%Y-%m" date)
                (format-time-string bs-mu4e-headers-month-format date)))
      (error '("undated" . "Undated")))))

(defun bs-mu4e--headers-thread-date (thread)
  "Return THREAD's root-message date, or nil when it is invalid."
  (condition-case nil
      (let ((date
             (mu4e-message-field
              (car (plist-get thread :messages)) :date)))
        (unless (equal date '(0 0 0))
          date))
    (error nil)))

(defun bs-mu4e--headers-thread-newer-p (left right)
  "Return non-nil when LEFT's root message is newer than RIGHT's."
  (let ((left-date (bs-mu4e--headers-thread-date left))
        (right-date (bs-mu4e--headers-thread-date right)))
    (cond
     ((null left-date) nil)
     ((null right-date) t)
     (t (time-less-p right-date left-date)))))

(defun bs-mu4e--headers-sort-threads ()
  "Stably sort the headers model by descending root-message date."
  (setq bs-mu4e--headers-threads
        (cl-stable-sort bs-mu4e--headers-threads
                        #'bs-mu4e--headers-thread-newer-p)))

(defun bs-mu4e--headers-month-line (title first-p)
  "Return a month separator for TITLE.
FIRST-P says that this is the first month in the Headers buffer."
  (let* ((top-spacing
          (+ bs-mu4e-headers-month-line-spacing
             (if first-p bs-mu4e-headers-header-bottom-spacing 0)))
         (line (concat "  " title "\n"))
         (newline (1- (length line))))
    (add-text-properties
     0 (length line) '(face bs-mu4e-headers-month-face) line)
    (add-text-properties
     0 1
     `(line-prefix ,(bs-top-spacing-prefix top-spacing))
     line)
    (add-text-properties
     newline (length line)
     `(line-spacing ,bs-mu4e-headers-month-line-spacing)
     line)
    line))

(defun bs-mu4e--headers-clear-thread-markers ()
  "Detach all region markers owned by the current thread model."
  (dolist (thread bs-mu4e--headers-threads)
    (when-let* ((marker (plist-get thread :start)))
      (set-marker marker nil))
    (when-let* ((marker (plist-get thread :end)))
      (set-marker marker nil))))

(defun bs-mu4e--headers-message-level (msg)
  "Return the thread nesting level of MSG."
  (let ((level (plist-get (mu4e-message-field msg :meta) :level)))
    (if (natnump level) level 0)))

(defun bs-mu4e--headers-descendants (msg thread)
  "Return descendants of MSG within THREAD."
  (when-let* ((tail (memq msg (plist-get thread :messages))))
    (let ((level (bs-mu4e--headers-message-level (car tail))))
      (cl-loop for child in (cdr tail)
               while (> (bs-mu4e--headers-message-level child) level)
               collect child))))

(defun bs-mu4e--headers-important-message-p (msg)
  "Return non-nil when MSG should remain visible while folded."
  (let ((docid (mu4e-message-field msg :docid)))
    (or (bs-mu4e--headers-unread-p msg)
        (mu4e-mark-docid-marked-p docid))))

(defun bs-mu4e--headers-folded-message-p (msg)
  "Return non-nil when MSG has folded replies."
  (and (hash-table-p bs-mu4e--headers-fold-state)
       (gethash (mu4e-message-field msg :docid)
                bs-mu4e--headers-fold-state)))

(defun bs-mu4e--headers-folded-descendant-docids (thread)
  "Return docids hidden by saved folds in THREAD."
  (let ((hidden (make-hash-table :test #'eql)))
    (dolist (msg (plist-get thread :messages))
      (when (bs-mu4e--headers-folded-message-p msg)
        (dolist (child (bs-mu4e--headers-descendants msg thread))
          (unless (bs-mu4e--headers-important-message-p child)
            (puthash (mu4e-message-field child :docid) t hidden)))))
    hidden))

(defun bs-mu4e--headers-add-fold-indicator (position docid)
  "Display a fold indicator at message POSITION for DOCID."
  (save-excursion
    (goto-char position)
    (when-let* ((visible-position
                 (next-single-property-change
                  position 'invisible nil (line-end-position))))
      (when (eq (char-after visible-position) ?\s)
        (let ((overlay
               (make-overlay visible-position
                             (1+ visible-position) nil t nil)))
          (overlay-put
           overlay 'display
           (propertize
            (char-to-string bs-mu4e-headers-fold-indicator)
            'face 'bs-mu4e-headers-fold-indicator-face))
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'bs-mu4e-fold-overlay t)
          (overlay-put overlay 'bs-mu4e-fold-indicator t)
          (overlay-put overlay 'bs-mu4e-fold-anchor docid))))))

(defun bs-mu4e--headers-insert-thread (thread width count-width)
  "Insert THREAD at point for WIDTH and update its region markers.

Right-align its message-count label to COUNT-WIDTH columns."
  (let* ((messages (plist-get thread :messages))
         (root (car messages))
         (start (point))
         (hidden (bs-mu4e--headers-folded-descendant-docids thread))
         (content-column
          (bs-mu4e--headers-thread-content-column count-width))
         (mu4e~headers-thread-state nil))
    (insert (bs-mu4e--headers-title-line
             thread width count-width content-column)
            "\n")
    (dolist (msg messages)
      (let* ((native-prefix
              (if mu4e-search-threads
                  (mu4e~headers-thread-prefix
                   (mu4e-message-field msg :meta))
                ""))
             (prefix (if (and mu4e-search-threads (eq msg root))
                         bs-mu4e--headers-root-prefix
                       native-prefix))
             (docid (mu4e-message-field msg :docid)))
        (unless (gethash docid hidden)
          (let ((position (point)))
            (insert (bs-mu4e--headers-message-line
                     msg prefix width content-column))
            (when (bs-mu4e--headers-folded-message-p msg)
              (bs-mu4e--headers-add-fold-indicator position docid))))))
    (insert "\n")
    (unless (markerp (plist-get thread :start))
      (plist-put thread :start (make-marker)))
    (unless (markerp (plist-get thread :end))
      (plist-put thread :end (make-marker)))
    (set-marker-insertion-type (plist-get thread :start) t)
    (set-marker-insertion-type (plist-get thread :end) nil)
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
    (bs-mu4e--headers-sort-threads)
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
      (let ((previous-month nil)
            (first-month-p t))
        (dolist (thread bs-mu4e--headers-threads)
          (pcase-let ((`(,month . ,title)
                       (bs-mu4e--headers-thread-month thread)))
            (unless (equal month previous-month)
              (insert (bs-mu4e--headers-month-line title first-month-p))
              (setq previous-month month
                    first-month-p nil)))
          (bs-mu4e--headers-insert-thread thread width count-width)))
      (setq bs-mu4e--headers-render-width width
            header-line-format '(:eval (bs-mu4e--headers-header)))
      (bs-mu4e--headers-restore-marks)
      (bs-mu4e--headers-restore-selection docid)
      (force-mode-line-update))))

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
          bs-mu4e--headers-threads nil
          header-line-format '(:eval (bs-mu4e--headers-header)))
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
      (setq header-line-format '(:eval (bs-mu4e--headers-header)))
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
                  (unless (plist-get thread :messages)
                    (setq bs-mu4e--headers-threads
                          (delq thread bs-mu4e--headers-threads)))
                  (bs-mu4e--headers-render))
              (setf (plist-get thread :messages)
                    (mapcar (lambda (item)
                              (if (eq item old-msg) msg item))
                            messages))
              (when markinfo
                (puthash docid markinfo mu4e--mark-map))
              (bs-mu4e--headers-rerender-thread thread docid))
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
        (unless (plist-get thread :messages)
          (setq bs-mu4e--headers-threads
                (delq thread bs-mu4e--headers-threads)))
        (bs-mu4e--headers-render))))
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
  "Toggle folding of replies to the message at point."
  (interactive)
  (unless bs-mu4e--headers-initialized
    (user-error "The custom Mu4e headers renderer is not active"))
  (let* ((msg (mu4e-message-at-point 'noerror))
         (docid (and msg (mu4e-message-field msg :docid)))
         (found (and docid (bs-mu4e--headers-find-message docid)))
         (thread (car-safe found))
         (anchor (cdr-safe found))
         (descendants (and thread
                           anchor
                           (bs-mu4e--headers-descendants anchor thread))))
    (unless thread
      (user-error "No message thread at point"))
    (unless descendants
      (user-error "The current message has no replies"))
    (if (gethash docid bs-mu4e--headers-fold-state)
        (remhash docid bs-mu4e--headers-fold-state)
      (puthash docid t bs-mu4e--headers-fold-state))
    (bs-mu4e--headers-rerender-thread thread docid)))

(defun bs-mu4e--headers-render-message (msg)
  "Return human-readable rendered text for MSG."
  (require 'mu4e-view)
  (with-temp-buffer
    (insert-file-contents-literally
     (mu4e-message-readable-path msg) nil nil nil t)
    (let ((gnus-inhibit-mime-unbuttonizing nil)
          (gnus-unbuttonized-mime-types '(".*/.*"))
          (mu4e-view-fields '(:from :to :cc :subject :date)))
      (mu4e--view-render-buffer msg)
      (bs--decode-raw-utf-8
       (string-trim-right
        (buffer-substring-no-properties
         (point-min) (point-max)))))))

(defun bs-mu4e--today-query ()
  "Return a query for today's messages in the active Mu4e context."
  (let ((folders
         (delete-dups
          (delq nil
                (mapcar
                 (lambda (folder)
                   (and (stringp folder)
                        (not (string-empty-p folder))
                        folder))
                 (list
                  (and (boundp 'mu4e-drafts-folder)
                       mu4e-drafts-folder)
                  (and (boundp 'mu4e-trash-folder)
                       mu4e-trash-folder)))))))
    (concat
     (unless (string-empty-p bs-mu4e-context-query)
       (format "(%s) AND " bs-mu4e-context-query))
     "(date:today..now)"
     (when folders
       (format " AND NOT (%s)"
               (mapconcat
                (lambda (folder)
                  (format "maildir:%S" folder))
                folders " OR "))))))

(defun bs-mu4e--read-sexp-message (line)
  "Read one Mu S-expression message from LINE."
  (let* ((read-eval nil)
         (message (car (read-from-string line))))
    (unless (listp message)
      (error "Invalid Mu message output: %s" line))
    message))

(defun bs-mu4e--today-messages (query)
  "Return Mu4e messages matching today's QUERY in chronological order."
  (let* ((binary
          (or (and (boundp 'mu4e-mu-binary) mu4e-mu-binary)
              "mu"))
         (messages
          (mapcar
           #'bs-mu4e--read-sexp-message
           (process-lines binary "find" "--format=sexp"
                          "--skip-dups" "--sortfield=date" query))))
    (sort messages
          (lambda (left right)
            (time-less-p
             (or (mu4e-message-field left :date) 0)
             (or (mu4e-message-field right :date) 0))))))

(defun bs-mu4e--context-thread-key (message)
  "Return a stable thread key for Mu4e MESSAGE."
  (or (car (mu4e-message-field message :references))
      (mu4e-message-field message :message-id)
      (downcase
       (bs-message-base-subject
        (mu4e-message-field message :subject)))
      (mu4e-message-field message :path)))

(defun bs-mu4e--messages-by-thread (messages)
  "Group chronological MESSAGES by thread in first-message order."
  (bs-group-by messages #'bs-mu4e--context-thread-key))

(defun bs-mu4e--context-contact (contact)
  "Return a readable string for Mu4e CONTACT."
  (let ((name (and (listp contact) (plist-get contact :name)))
        (email (and (listp contact) (plist-get contact :email))))
    (cond
     ((and name email) (format "%s <%s>" name email))
     (email email)
     (name name)
     (t (format "%s" contact)))))

(defun bs-mu4e--context-contacts (contacts)
  "Return a readable string for Mu4e CONTACTS."
  (if contacts
      (mapconcat #'bs-mu4e--context-contact contacts ", ")
    "[none]"))

(defun bs-mu4e--context-message-fallback (message error-data)
  "Return metadata for MESSAGE whose body failed with ERROR-DATA."
  (format
   (concat "From: %s\nTo: %s\nSubject: %s\nDate: %s\n"
           "Message-ID: %s\n\n"
           "[Message body was not available locally: %s]")
   (bs-mu4e--context-contacts
    (mu4e-message-field message :from))
   (bs-mu4e--context-contacts
    (mu4e-message-field message :to))
   (or (mu4e-message-field message :subject) "[no subject]")
   (if-let* ((date (mu4e-message-field message :date)))
       (format-time-string "%F %T %z" date)
     "[unknown]")
   (or (mu4e-message-field message :message-id) "[none]")
   (error-message-string error-data)))

(defun bs-mu4e--render-context-message (message)
  "Render MESSAGE, retaining metadata when its local body is unavailable."
  (condition-case error-data
      (bs-mu4e--headers-render-message message)
    (error
     (bs-mu4e--context-message-fallback message error-data))))

(defun bs-mu4e--build-today-context (messages query)
  "Build and return a Mu4e context for today's MESSAGES from QUERY."
  (let ((threads (bs-mu4e--messages-by-thread messages)))
    (with-current-buffer
        (get-buffer-create bs-mu4e-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert "# Today's Mail Context\n\n"
              (format "Source: Mu4e context `%s`\n\n"
                      bs-mu4e-context-name)
              (format "Query: `%s`\n\n" query)
              (format "Threads: %d\n" (length threads))
              (format "Messages: %d\n" (length messages)))
      (cl-loop
       for thread in threads
       for thread-index from 1
       do
       (insert
        (format "\n## Thread %d of %d: %s\n"
                thread-index (length threads)
                (bs-message-base-subject
                 (mu4e-message-field (car thread) :subject))))
       (cl-loop
        for message in thread
        for message-index from 1
        do
        (insert
         (format "\n### Message %d of %d\n\n"
                 message-index (length thread))
         (bs-mu4e--render-context-message message)
         "\n")))
      (set-buffer-modified-p nil)
      (current-buffer))))

(defun bs-mu4e--headers-build-thread-context (messages query)
  "Build a thread context for MESSAGES from Mu4e QUERY."
  (let ((texts (mapcar #'bs-mu4e--headers-render-message messages))
        (count (length messages)))
    (with-current-buffer
        (get-buffer-create bs-mu4e-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert "# Thread Context\n\n"
              (format "Source: Mu4e query `%s`\n\n" query)
              (format "Messages: %d\n" count))
      (cl-loop for text in texts
               for index from 1
               do (insert (format "\n## Message %d of %d\n\n"
                                  index count)
                          text "\n"))
      (set-buffer-modified-p nil)
      (current-buffer))))

;;;###autoload
(defun bs-mu4e-headers-mark-subthread ()
  "Prepare the message at point and its replies as thread context.
Render every message before replacing the buffer named by
`bs-mu4e-context-buffer-name'.  Keep that buffer hidden by
default, select the current Headers row, and run
`bs-mu4e-headers-thread-context-hook'."
  (interactive)
  (unless (and (derived-mode-p 'mu4e-headers-mode)
               bs-mu4e--headers-initialized)
    (user-error "The custom Mu4e Headers renderer is not active"))
  (unless bs-mu4e--headers-search-complete
    (user-error "The current Mu4e search is not complete"))
  (let* ((msg (mu4e-message-at-point 'noerror))
         (docid (and msg (mu4e-message-field msg :docid)))
         (found (and docid (bs-mu4e--headers-find-message docid)))
         (thread (car-safe found))
         (anchor (cdr-safe found))
         (messages
          (and anchor
               (cons anchor
                     (bs-mu4e--headers-descendants
                      anchor thread))))
         (query (bs-mu4e--headers-query)))
    (unless anchor
      (user-error "No Mu4e message thread at point"))
    (let ((context
           (bs-mu4e--headers-build-thread-context
            messages query)))
      (mu4e~headers-goto-docid docid)
      (run-hooks 'bs-mu4e-headers-thread-context-hook)
      (if bs-mu4e-headers-display-thread-context
          (progn
            (pop-to-buffer context)
            (goto-char (point-min))
            (push-mark (point-max) nil t))
        (mu4e~headers-goto-docid docid t)
        (move-to-column 2)
        (push-mark (line-end-position) nil t)
        (message "Prepared %d Mu4e messages in %s"
                 (length messages)
                 bs-mu4e-context-buffer-name)))))

;;;###autoload
(defun bs-mu4e-prepare-today-context ()
  "Prepare today's local messages from a Mu4e Main or Headers buffer.
Include received and sent mail while excluding the context's draft
and trash folders.  Group messages by thread and order each thread
chronologically without updating mail or the Mu database."
  (interactive)
  (unless (derived-mode-p 'mu4e-main-mode 'mu4e-headers-mode)
    (user-error "This command requires a Mu4e Main or Headers buffer"))
  (let* ((query (bs-mu4e--today-query))
         (messages (bs-mu4e--today-messages query)))
    (unless messages
      (user-error "No Mu4e messages from today in context %s"
                  bs-mu4e-context-name))
    (bs-mu4e--build-today-context messages query)
    (run-hooks 'bs-mu4e-headers-thread-context-hook)
    (message "Prepared %d Mu4e messages from today in %s"
             (length messages) bs-mu4e-context-buffer-name)))

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
