;;; bs-elfeed.el --- Elfeed integration  -*- lexical-binding:t -*-

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

;; This package provides personal Elfeed extensions.

;;; Code:

(require 'cl-lib)
(require 'elfeed)
(require 'elfeed-search)
(require 'shr)
(require 'subr-x)
(require 'timer)
(require 'url)

(defvar shr-inhibit-images)
(defvar shr-use-fonts)
(defvar url-http-end-of-headers)
(defvar url-http-response-status)

(defvar elfeed-search-entries)
(defvar elfeed-search-header-function)
(defvar elfeed-search-print-entry-function)
(defvar elfeed-tree--last-update)
(defvar elfeed-tree-filter)
(defvar elfeed-tree-header-function)
(defvar elfeed-tree-update-hook)

(declare-function elfeed--header-button "elfeed")
(declare-function elfeed--header-jobs "elfeed-search")
(declare-function elfeed-db-last-update "elfeed-db")
(declare-function elfeed-db-size "elfeed-db")
(declare-function elfeed-score-scoring-get-score-from-entry
                  "elfeed-score-scoring")
(declare-function elfeed-tree--build-nested "elfeed-tree")
(declare-function elfeed-tree--collect "elfeed-tree")
(declare-function elfeed-tree--stats "elfeed-tree")
(declare-function elfeed-tree-update "elfeed-tree")
(declare-function outline-invisible-p "outline")
(declare-function outline-revert-buffer-restore-visibility "outline")
(declare-function outline-show-all "outline")

(defgroup bs-elfeed nil
  "Personal Elfeed extensions."
  :group 'elfeed)

(defcustom bs-elfeed-context-buffer-name "*Elfeed Context*"
  "Name of the buffer containing the latest Elfeed context."
  :type 'string
  :group 'bs-elfeed)

(defcustom bs-elfeed-context-fetch-threshold 200
  "Minimum feed text length that avoids fetching the entry link."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-context-fetch-timeout 15
  "Seconds to wait while fetching a linked entry for context."
  :type 'number
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-context-hook nil
  "Hook run after preparing an Elfeed context.
The hook runs in the originating Search buffer while the buffer
named by `bs-elfeed-context-buffer-name' contains the selected
entries."
  :type 'hook
  :group 'bs-elfeed)

(defface bs-elfeed-tree-topic-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face used for Elfeed Tree topics."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for the complete Elfeed Tree header line."
  :group 'bs-elfeed)

(defface bs-elfeed-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in Elfeed header lines."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-next-update-face
  '((t :inherit font-lock-keyword-face))
  "Face used for the next-update time in the Elfeed Tree header."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-root-topic-face
  '((t :inherit bs-elfeed-tree-topic-face :height 1.30))
  "Face used for the synthetic Elfeed Tree root topic."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-top-level-topic-face
  '((t :inherit bs-elfeed-tree-topic-face :height 1.15))
  "Face used for top-level Elfeed Tree topics."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-topic-count-face
  '((t :inherit error :weight semi-bold))
  "Face used for nonzero Elfeed Tree topic counts."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-empty-count-face
  '((t :inherit shadow))
  "Face used for empty Elfeed Tree topic counts."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-feed-unread-face
  '((t :inherit error :weight bold))
  "Face used for unread Elfeed Tree feed counts."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-feed-read-face
  '((t :inherit shadow))
  "Face used for read Elfeed Tree feed counts."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-total-face
  '((t :inherit shadow))
  "Face used for Elfeed Tree total counts."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-separator-face
  '((t :inherit shadow))
  "Face used for separators in Elfeed Tree statistics."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-host-face
  '((t :inherit default))
  "Face used for feed host names in Elfeed Tree."
  :group 'bs-elfeed)

(defface bs-elfeed-tree-source-face
  '((t :inherit shadow))
  "Face used for human-readable feed names in Elfeed Tree."
  :group 'bs-elfeed)

(defface bs-elfeed-search-read-title-face
  '((t :inherit shadow :weight normal :slant italic))
  "Face used for read Elfeed Search entry titles."
  :group 'bs-elfeed)

(defface bs-elfeed-search-unread-title-face
  '((t :inherit default :weight bold :slant italic))
  "Face used for unread Elfeed Search entry titles."
  :group 'bs-elfeed)

(defface bs-elfeed-search-unread-face
  '((t :inherit error :weight bold))
  "Face used for the Elfeed Search unread marker."
  :group 'bs-elfeed)

(defface bs-elfeed-search-positive-score-face
  '((t :inherit success :weight semi-bold :inverse-video t))
  "Face used for positive Elfeed Search scores."
  :group 'bs-elfeed)

(defface bs-elfeed-search-negative-score-face
  '((t :inherit error :weight semi-bold :inverse-video t))
  "Face used for negative Elfeed Search scores."
  :group 'bs-elfeed)

(defface bs-elfeed-search-timestamp-face
  '((t :inherit shadow))
  "Face used for Elfeed Search timestamps."
  :group 'bs-elfeed)

(defface bs-elfeed-search-month-face
  '((t :inherit font-lock-keyword-face
       :height 1.10 :underline nil :extend t))
  "Face used for Elfeed Search month separators."
  :group 'bs-elfeed)

(defface bs-elfeed-search-overview-face
  '((t :inherit bs-elfeed-header-label-face))
  "Face used for the Elfeed Search overview label."
  :group 'bs-elfeed)

(defface bs-elfeed-search-filter-face
  '((t :inherit font-lock-keyword-face
       :slant italic :weight bold))
  "Face used for the active Elfeed Search filter."
  :group 'bs-elfeed)

(defface bs-elfeed-search-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for the complete Elfeed Search header line."
  :group 'bs-elfeed)

(defface bs-elfeed-search-overview-unread-face
  '((t :inherit error :weight bold))
  "Face used for the unread count in the Search overview."
  :group 'bs-elfeed)

(defface bs-elfeed-search-overview-shown-face
  '((t :inherit success :weight bold))
  "Face used for the shown count in the Search overview."
  :group 'bs-elfeed)

(defface bs-elfeed-search-overview-total-face
  '((t :inherit shadow))
  "Face used for the total count in the Search overview."
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-root-name "Feeds"
  "Name of the synthetic root in the Elfeed Tree buffer."
  :type 'string
  :group 'bs-elfeed)

(defcustom bs-elfeed-update-interval (* 30 60)
  "Seconds between automatic Elfeed updates."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-tag-names
  '((emacs . "Emacs")
    (kde . "KDE")
    (lisp . "Lisp")
    (lowrisc . "lowRISC")
    (riscv . "RISC-V")
    (sbcl . "SBCL"))
  "Overrides used when turning Elfeed tags into topic names."
  :type '(alist :key-type symbol :value-type string)
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-minimum-count-width 9
  "Minimum width of the feed count column in Elfeed Tree."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-feed-indentation-width 4
  "Columns reserved before feed statistics in Elfeed Tree."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-feed-right-margin-width 1
  "Columns reserved after feed names in Elfeed Tree."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-topic-line-spacing 0.65
  "Relative spacing added around Elfeed Tree topic rows."
  :type 'number
  :group 'bs-elfeed)

(defcustom bs-elfeed-header-bottom-spacing 0.5
  "Relative line height reserved below Elfeed header lines."
  :type 'number
  :group 'bs-elfeed)

(defcustom bs-elfeed-tree-fallback-width 100
  "Width used to render Elfeed Tree when it is not displayed."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-date-format "%m/%d/%Y %I:%M:%S %p"
  "Format used for timestamps in Elfeed Search."
  :type 'string
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-score-limit 999
  "Largest score displayed without compact unit notation."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-line-spacing 0.20
  "Extra line spacing used in Elfeed Search buffers."
  :type 'number
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-month-line-spacing 0.65
  "Relative spacing added above and below Search month separators."
  :type 'number
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-right-margin-width 1
  "Columns reserved after timestamps in Elfeed Search."
  :type 'natnum
  :group 'bs-elfeed)

(defcustom bs-elfeed-search-fallback-width 100
  "Width used to render Elfeed Search when it is not displayed."
  :type 'natnum
  :group 'bs-elfeed)

(defvar bs-elfeed-tree--enabled nil)
(defvar bs-elfeed-tree--original-header-function nil)
(defvar bs-elfeed-search--enabled nil)
(defvar bs-elfeed-search--original-header-function nil)
(defvar bs-elfeed-search--original-print-entry-function nil)
(defvar bs-elfeed--update-timer nil)

(defvar-local bs-elfeed-tree--render-width nil)
(defvar-local bs-elfeed-tree--resize-timer nil)
(defvar-local bs-elfeed-tree--statistics nil)
(defvar-local bs-elfeed-search--saved-line-spacing nil)
(defvar-local bs-elfeed-search--saved-line-spacing-local-p nil)
(defvar-local bs-elfeed-search--line-spacing-saved-p nil)

(cl-defstruct
    (bs-elfeed--request
     (:constructor bs-elfeed--make-request))
  source
  entries
  contents
  pending)

(cl-defstruct
    (bs-elfeed--fetch
     (:constructor bs-elfeed--make-fetch))
  request
  entry
  fallback
  buffer
  timer
  completed)

(defun bs-elfeed--render-html (html)
  "Return HTML rendered as plain text."
  (with-temp-buffer
    (insert html)
    (let ((shr-inhibit-images t)
          (shr-use-fonts nil))
      (shr-render-region (point-min) (point-max)))
    (string-trim (buffer-string))))

(defun bs-elfeed--entry-text (entry)
  "Return the feed-provided text for ENTRY."
  (when-let* ((content
               (elfeed-deref (elfeed-entry-content entry))))
    (if (eq (elfeed-entry-content-type entry) 'html)
        (bs-elfeed--render-html content)
      (string-trim content))))

(defun bs-elfeed--build-context (request)
  "Build and return an Elfeed context buffer from REQUEST."
  (let* ((entries (bs-elfeed--request-entries request))
         (contents (bs-elfeed--request-contents request))
         (source (bs-elfeed--request-source request))
         (filter
          (if (buffer-live-p source)
              (with-current-buffer source elfeed-search-filter)
            "[closed Search buffer]"))
         (count (length entries)))
    (with-current-buffer
        (get-buffer-create bs-elfeed-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert "# Feed Context\n\n"
              (format "Source: Elfeed filter `%s`\n\n" filter)
              (format "Entries: %d\n" count))
      (cl-loop
       for entry in entries
       for index from 1
       for feed = (elfeed-entry-feed entry)
       for content = (gethash entry contents)
       do
       (insert
        (format "\n## Entry %d of %d\n\n" index count)
        (format "Title: %s\n"
                (or (elfeed-entry-title entry) "[untitled]"))
        (format "Feed: %s\n"
                (or (and feed (elfeed-feed-title feed))
                    "[unknown]"))
        (format "Date: %s\n"
                (format-time-string
                 "%F %T %z"
                 (seconds-to-time (elfeed-entry-date entry))))
        (format "URL: %s\n\n"
                (or (elfeed-entry-link entry) "[none]"))
        (if (string-empty-p content)
            "[No article content was available.]"
          content)
        "\n"))
      (set-buffer-modified-p nil)
      (current-buffer))))

(defun bs-elfeed--select-entry-line (entry)
  "Select the Search line displaying ENTRY."
  (let ((origin (point))
        found)
    (goto-char (point-min))
    (while (and (not found) (not (eobp)))
      (if (eq entry
              (get-text-property
               (line-beginning-position) 'elfeed-entry))
          (setq found t)
        (forward-line)))
    (unless found
      (goto-char origin)
      (when (eobp)
        (forward-line -1)))
    (goto-char (line-beginning-position))
    (push-mark (line-end-position) nil t)))

(defun bs-elfeed--finish-request (request)
  "Finish REQUEST and run the context hook."
  (let ((source (bs-elfeed--request-source request))
        (count (length (bs-elfeed--request-entries request))))
    (bs-elfeed--build-context request)
    (if (not (buffer-live-p source))
        (message
         "Prepared %d Elfeed entries, but the Search buffer closed"
         count)
      (pop-to-buffer source)
      (bs-elfeed--select-entry-line
       (car (bs-elfeed--request-entries request)))
      (message "Prepared %d Elfeed entries in %s"
               count bs-elfeed-context-buffer-name)
      (run-hooks 'bs-elfeed-search-context-hook))))

(defun bs-elfeed--complete-entry (request entry content)
  "Record CONTENT for ENTRY and complete REQUEST when ready."
  (puthash entry content (bs-elfeed--request-contents request))
  (cl-decf (bs-elfeed--request-pending request))
  (when (zerop (bs-elfeed--request-pending request))
    (bs-elfeed--finish-request request)))

(defun bs-elfeed--fetch-content (buffer)
  "Return rendered article content from URL response BUFFER."
  (when (and (buffer-live-p buffer)
             (numberp url-http-response-status)
             (<= 200 url-http-response-status)
             (< url-http-response-status 300)
             (integer-or-marker-p url-http-end-of-headers))
    (with-current-buffer buffer
      (delete-region (point-min) url-http-end-of-headers)
      (bs-elfeed--render-html (buffer-string)))))

(defun bs-elfeed--fetch-callback (status fetch)
  "Handle an article fetch described by STATUS and FETCH."
  (unless (bs-elfeed--fetch-completed fetch)
    (setf (bs-elfeed--fetch-completed fetch) t)
    (when (timerp (bs-elfeed--fetch-timer fetch))
      (cancel-timer (bs-elfeed--fetch-timer fetch)))
    (let* ((buffer (current-buffer))
           (fallback (bs-elfeed--fetch-fallback fetch))
           (content
            (condition-case error-data
                (unless (plist-get status :error)
                  (bs-elfeed--fetch-content buffer))
              (error
               (message "Failed to render Elfeed entry %s: %s"
                        (elfeed-entry-title
                         (bs-elfeed--fetch-entry fetch))
                        (error-message-string error-data))
               nil))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (bs-elfeed--complete-entry
       (bs-elfeed--fetch-request fetch)
       (bs-elfeed--fetch-entry fetch)
       (if (> (length (or content ""))
              (length fallback))
           content
         fallback)))))

(defun bs-elfeed--fetch-timeout (fetch)
  "Use the feed text when FETCH exceeds its timeout."
  (unless (bs-elfeed--fetch-completed fetch)
    (setf (bs-elfeed--fetch-completed fetch) t)
    (when-let* ((buffer (bs-elfeed--fetch-buffer fetch)))
      (when (buffer-live-p buffer)
        (when-let* ((process (get-buffer-process buffer)))
          (delete-process process))
        (kill-buffer buffer)))
    (message "Timed out fetching Elfeed entry: %s"
             (elfeed-entry-title
              (bs-elfeed--fetch-entry fetch)))
    (bs-elfeed--complete-entry
     (bs-elfeed--fetch-request fetch)
     (bs-elfeed--fetch-entry fetch)
     (bs-elfeed--fetch-fallback fetch))))

(defun bs-elfeed--start-fetch (request entry fallback)
  "Fetch linked content for ENTRY in REQUEST, retaining FALLBACK."
  (let* ((fetch
          (bs-elfeed--make-fetch
           :request request
           :entry entry
           :fallback fallback))
         (url (elfeed-entry-link entry)))
    (condition-case error-data
        (let ((buffer
               (url-retrieve
                url #'bs-elfeed--fetch-callback
                (list fetch) t t)))
          (setf (bs-elfeed--fetch-buffer fetch) buffer
                (bs-elfeed--fetch-timer fetch)
                (run-at-time
                 bs-elfeed-context-fetch-timeout nil
                 #'bs-elfeed--fetch-timeout fetch)))
      (error
       (message "Failed to fetch Elfeed entry %s: %s"
                (elfeed-entry-title entry)
                (error-message-string error-data))
       (bs-elfeed--complete-entry request entry fallback)))))

(defun bs-elfeed--prepare-entry (request entry)
  "Prepare ENTRY as part of REQUEST."
  (let ((fallback (or (bs-elfeed--entry-text entry) ""))
        (url (elfeed-entry-link entry)))
    (if (or (>= (length fallback)
                bs-elfeed-context-fetch-threshold)
            (not (and url
                      (string-match-p "\\`https?://" url))))
        (bs-elfeed--complete-entry request entry fallback)
      (bs-elfeed--start-fetch request entry fallback))))

;;;###autoload
(defun bs-elfeed-search-prepare-context ()
  "Prepare selected Elfeed entries as context.
Native marks take precedence over the active region and entry at
point, following `elfeed-search-selected'.  Fetch linked articles
asynchronously when their feed content is too short."
  (interactive nil elfeed-search-mode)
  (let ((entries (elfeed-search-selected)))
    (unless entries
      (user-error "No Elfeed entry selected"))
    (let ((request
           (bs-elfeed--make-request
            :source (current-buffer)
            :entries entries
            :contents (make-hash-table :test #'eq)
            :pending (length entries))))
      (message "Preparing context from %d Elfeed entries..."
               (length entries))
      (mapc (lambda (entry)
              (bs-elfeed--prepare-entry request entry))
            entries))))

(defun bs-elfeed--single-line (value fallback)
  "Return VALUE as a trimmed single line, or FALLBACK when empty."
  (let ((value
         (string-trim
          (replace-regexp-in-string
           "[\n\r\t ]+" " " (or value "")))))
    (if (string-empty-p value) fallback value)))

(defun bs-elfeed--truncate (string width)
  "Truncate STRING with an ASCII ellipsis to fit WIDTH columns."
  (cond
   ((<= width 0) "")
   ((<= (string-width string) width) string)
   ((<= width 3) (truncate-string-to-width string width))
   (t
    (concat (truncate-string-to-width string (- width 3)) "..."))))

(defun bs-elfeed--buffer-width (fallback)
  "Return the displayed width of the current buffer, or FALLBACK."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    fallback))

(defun bs-elfeed--header-right-padding (string)
  "Return pixel-aware padding that right-aligns STRING with one margin."
  (propertize
   " " 'display
   `(space
     :align-to
     (- right
        (+ (,(string-pixel-width string)) 1)))))

(defun bs-elfeed--top-spacing-prefix (spacing)
  "Return a zero-width line prefix adding SPACING above a row."
  (propertize
   " " 'display
   `(space
     :width 0
     :height ,(+ 1.0 (max 0 spacing))
     :ascent 100)))

(defun bs-elfeed--update-if-idle ()
  "Start an Elfeed update when no update jobs are active."
  (when (zerop (elfeed-queue-count-total))
    (elfeed-update)))

(defun bs-elfeed--ensure-update-timer ()
  "Start the shared periodic Elfeed update timer if necessary."
  (unless (timerp bs-elfeed--update-timer)
    (let ((interval (max 1 bs-elfeed-update-interval)))
      (setq bs-elfeed--update-timer
            (run-at-time interval interval
                         #'bs-elfeed--update-if-idle))))
  (bs-elfeed--update-if-idle))

(defun bs-elfeed--tree-tag-name (tag)
  "Return the display name for Elfeed TAG."
  (or (alist-get tag bs-elfeed-tree-tag-names)
      (capitalize
       (replace-regexp-in-string
        "[-_]+" " " (format "%s" tag)))))

(defun bs-elfeed--tree-host (feed)
  "Return a normalized host name for FEED."
  (let* ((id (elfeed-feed-id feed))
         (url (ignore-errors (url-generic-parse-url id)))
         (host (and url (url-host url))))
    (replace-regexp-in-string
     "\\`www\\." ""
     (bs-elfeed--single-line host id))))

(defun bs-elfeed--tree-sort-nodes (nodes)
  "Return a display-name-sorted copy of tree NODES."
  (sort (copy-sequence nodes)
        (lambda (left right)
          (string-lessp
           (bs-elfeed--tree-tag-name (car left))
           (bs-elfeed--tree-tag-name (car right))))))

(defun bs-elfeed--tree-sort-leaves (leaves)
  "Return a title-sorted copy of tree LEAVES."
  (sort (copy-sequence leaves)
        (lambda (left right)
          (string-lessp
           (bs-elfeed--single-line (car left) "[untitled]")
           (bs-elfeed--single-line (car right) "[untitled]")))))

(defun bs-elfeed--tree-count-widths (node)
  "Return unread and total count widths below NODE."
  (let ((unread-width 2)
        (total-width 1))
    (cl-labels
        ((visit
           (tree-node)
           (pcase-let
               ((`(,_tag ,_unread ,_read ,_count ,children ,leaves)
                 tree-node))
             (dolist (leaf leaves)
               (pcase-let ((`(,_title ,unread ,read ,_feed ,_tags)
                            leaf))
                 (setq unread-width
                       (max unread-width
                            (string-width
                             (number-to-string unread)))
                       total-width
                       (max total-width
                            (string-width
                             (number-to-string (+ unread read)))))))
             (mapc #'visit children))))
      (visit node))
    (setq total-width
          (+ total-width
             (max 0
                  (- bs-elfeed-tree-minimum-count-width
                     unread-width 1 total-width))))
    (list unread-width total-width)))

(defun bs-elfeed--tree-count (unread read widths)
  "Format a count from UNREAD and READ using WIDTHS."
  (let* ((unread-string (number-to-string unread))
         (total-string (number-to-string (+ unread read)))
         (unread-width (nth 0 widths))
         (total-width (nth 1 widths)))
    (concat
     (propertize
      (format (format "%%%ds" unread-width) unread-string)
      'face (if (> unread 0)
                'bs-elfeed-tree-feed-unread-face
              'bs-elfeed-tree-feed-read-face))
     (propertize "/" 'face 'bs-elfeed-tree-separator-face)
     (propertize total-string 'face 'bs-elfeed-tree-total-face)
     (make-string
      (max 0 (- total-width (string-width total-string))) ?\s))))

(defun bs-elfeed--tree-filter (tags unread)
  "Return the Search filter for TAGS containing UNREAD entries."
  (concat (elfeed-search--tag-filter tags)
          (bs-elfeed--tree-unread-filter unread)))

(defun bs-elfeed--tree-unread-filter (unread)
  "Return an unread filter suffix when UNREAD is nonzero and needed."
  (and (> unread 0)
       (not (member "+unread" (split-string elfeed-tree-filter)))
       " +unread"))

(defun bs-elfeed--tree-heading-display (collapsed)
  "Return a Tree heading prefix.
COLLAPSED controls whether the disclosure marker is shown."
  (if collapsed "▸ " "  "))

(defun bs-elfeed--tree-statistics-string
    (feed-count unread read)
  "Format statistics for FEED-COUNT feeds with UNREAD and READ entries."
  (concat
   (propertize
    (format "%d feeds" feed-count)
    'face 'bs-elfeed-tree-source-face)
   (propertize " · " 'face 'bs-elfeed-tree-separator-face)
   (propertize
    (format "%d unread" unread)
    'face (if (> unread 0)
              'bs-elfeed-tree-topic-count-face
            'bs-elfeed-tree-empty-count-face))
   (propertize " · " 'face 'bs-elfeed-tree-separator-face)
   (propertize
    (format "%d total" (+ unread read))
    'face 'bs-elfeed-tree-total-face)))

(defun bs-elfeed--next-update-text ()
  "Return the time remaining before the next periodic Elfeed update."
  (if (not (timerp bs-elfeed--update-timer))
      "not scheduled"
    (let ((seconds
           (max 0 (- (timer-until bs-elfeed--update-timer nil)))))
      (if (< seconds 60)
          "<1 minutes"
        (format "%d minutes" (ceiling (/ seconds 60.0)))))))

(defun bs-elfeed--tree-next-update-status ()
  "Return a clickable next-update status for the Tree header."
  (elfeed--header-button
   #'elfeed-update
   (concat
    (propertize "NEXT UPDATE" 'face 'bs-elfeed-header-label-face)
    " "
    (propertize (bs-elfeed--next-update-text)
                'face 'bs-elfeed-tree-next-update-face))))

(defun bs-elfeed--tree-header ()
  "Return the native Tree status with right-aligned feed statistics."
  (let* ((status
          (or (elfeed--header-jobs)
              (bs-elfeed--tree-next-update-status)))
         (header
          (if (not bs-elfeed-tree--statistics)
              status
            (pcase-let* ((`(,feed-count ,unread ,read)
                          bs-elfeed-tree--statistics)
                         (statistics
                          (bs-elfeed--tree-statistics-string
                           feed-count unread read))
                         (padding
                          (bs-elfeed--header-right-padding
                           statistics)))
              (concat status padding statistics)))))
    (add-face-text-property
     0 (length header) 'bs-elfeed-tree-header-face t header)
    header))

(defun bs-elfeed--tree-insert-topic
    (name unread level tags root-p)
  "Insert a Tree topic named NAME.
UNREAD is its unread count.  LEVEL is its outline level, TAGS form
its Search filter, and ROOT-P identifies the synthetic root."
  (let* ((start (point))
         (stars (make-string level ?*))
         (label-face
          (cond
           (root-p 'bs-elfeed-tree-root-topic-face)
           ((= level 2) 'bs-elfeed-tree-top-level-topic-face)
           (t 'bs-elfeed-tree-topic-face)))
         (label (propertize name 'face label-face))
         (filter (bs-elfeed--tree-filter tags unread))
         (body
          (if root-p
              label
            (concat
             label
             (propertize " (" 'face 'bs-elfeed-tree-separator-face)
             (propertize
              (number-to-string unread)
              'face (if (> unread 0)
                        'bs-elfeed-tree-topic-count-face
                      'bs-elfeed-tree-empty-count-face))
             (propertize ")" 'face 'bs-elfeed-tree-separator-face)))))
    (put-text-property
     0 (length stars) 'display
     (bs-elfeed--tree-heading-display nil) stars)
    (insert
     (elfeed-add-properties
      (concat stars body)
      'bs-elfeed-tree-heading t
      'elfeed-tree (mapconcat #'symbol-name tags " ")
      'elfeed-filter filter
      'follow-link [elfeed-filter]
      'mouse-face 'highlight)
     ?\n)
    (let ((prefix
           (bs-elfeed--top-spacing-prefix
            (+ bs-elfeed-tree-topic-line-spacing
               (if root-p
                   bs-elfeed-header-bottom-spacing
                 0)))))
      (add-text-properties
       start (1+ start)
       `(bs-elfeed-tree-topic-spacing t
                                      line-prefix ,prefix)))))

(defun bs-elfeed--tree-add-trailing-topic-spacing ()
  "Add lower spacing after each final consecutive Tree topic row."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let* ((position (line-beginning-position))
             (topic
              (get-text-property position
                                 'bs-elfeed-tree-heading))
             (newline (line-end-position))
             (next-topic
              (get-text-property
               (line-beginning-position 2)
               'bs-elfeed-tree-heading)))
        (when (and topic (not next-topic))
          (add-text-properties
           newline (1+ newline)
           `(bs-elfeed-tree-topic-spacing t
                                          line-spacing
                                          ,bs-elfeed-tree-topic-line-spacing)))
        (forward-line 1)))))

(defun bs-elfeed--tree-insert-feed
    (leaf count-widths render-width)
  "Insert feed LEAF.
COUNT-WIDTHS and RENDER-WIDTH control the column layout."
  (pcase-let* ((`(,title ,unread ,read ,feed ,_tags) leaf)
               (indentation
                (make-string
                 bs-elfeed-tree-feed-indentation-width ?\s))
               (count
                (bs-elfeed--tree-count unread read count-widths))
               (host (bs-elfeed--tree-host feed))
               (source (bs-elfeed--single-line title "[untitled]"))
               (prefix-width
                (+ bs-elfeed-tree-feed-indentation-width
                   (nth 0 count-widths)
                   1 (nth 1 count-widths) 2))
               (content-width
                (max 0
                     (- render-width prefix-width
                        bs-elfeed-tree-feed-right-margin-width)))
               (source (bs-elfeed--truncate source content-width))
               (remaining
                (max 0 (- content-width (string-width source))))
               (host-width (max 0 (- remaining 2)))
               (host (bs-elfeed--truncate host host-width))
               (padding-width
                (max 0 (- remaining (string-width host))))
               (line
                (concat
                 indentation count "  "
                 (propertize host 'face 'bs-elfeed-tree-host-face)
                 (make-string padding-width ?\s)
                 (propertize source 'face 'bs-elfeed-tree-source-face)
                 (make-string
                  bs-elfeed-tree-feed-right-margin-width ?\s))))
    (insert
     (elfeed-add-properties
      line
      'elfeed-feed feed
      'elfeed-tree (elfeed-feed-id feed)
      'elfeed-filter
      (concat (elfeed-search--feed-filter feed)
              (bs-elfeed--tree-unread-filter unread))
      'follow-link [elfeed-filter]
      'mouse-face 'highlight)
     ?\n)))

(defun bs-elfeed--tree-insert-node
    (node level tags root-p count-widths render-width)
  "Insert NODE and its descendants at LEVEL.
TAGS contains ancestor tags.  ROOT-P identifies the synthetic
root.  COUNT-WIDTHS and RENDER-WIDTH control feed layout."
  (pcase-let* ((`(,tag ,unread ,_read ,_count ,children ,leaves) node)
               (node-tags (if root-p tags (append tags (list tag))))
               (name (if root-p
                         bs-elfeed-tree-root-name
                       (bs-elfeed--tree-tag-name tag))))
    (bs-elfeed--tree-insert-topic
     name unread level node-tags root-p)
    (dolist (leaf (bs-elfeed--tree-sort-leaves leaves))
      (bs-elfeed--tree-insert-feed
       leaf count-widths render-width))
    (dolist (child (bs-elfeed--tree-sort-nodes children))
      (bs-elfeed--tree-insert-node
       child (1+ level) node-tags nil count-widths render-width))))

(defun bs-elfeed--tree-update-indicators (&rest _)
  "Update visible Elfeed Tree disclosure indicators."
  (when (derived-mode-p 'elfeed-tree-mode)
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
               (bs-elfeed--tree-heading-display collapsed)))))
        (goto-char (min origin (point-max)))))))

(defun bs-elfeed--tree-update-immediately (buffer &optional force)
  "Immediately redraw Elfeed Tree BUFFER using the custom renderer.
When FORCE is nil, redraw only after the database changes."
  (when (and (buffer-live-p buffer)
             (or force
                 (< elfeed-tree--last-update
                    (elfeed-db-last-update))))
    (with-current-buffer buffer
      (elfeed-with-position elfeed-tree
                            (let* ((restore (outline-revert-buffer-restore-visibility))
                                   (inhibit-read-only t)
                                   (feeds (car (elfeed-tree--collect)))
                                   (nested (elfeed-tree--build-nested feeds))
                                   (root
                                    (car
                                     (elfeed-tree--stats
                                      (list
                                       (list bs-elfeed-tree-root-name
                                             (car nested) (cadr nested))))))
                                   (count-widths (bs-elfeed--tree-count-widths root))
                                   (render-width
                                    (bs-elfeed--buffer-width
                                     bs-elfeed-tree-fallback-width)))
                              (setq bs-elfeed-tree--render-width render-width)
                              (setq bs-elfeed-tree--statistics
                                    (list (nth 3 root)
                                          (nth 1 root)
                                          (nth 2 root)))
                              (erase-buffer)
                              (bs-elfeed--tree-insert-node
                               root 1 nil t count-widths render-width)
                              (bs-elfeed--tree-add-trailing-topic-spacing)
                              (when restore
                                (funcall restore))
                              (bs-elfeed--tree-update-indicators)
                              (setq elfeed-tree--last-update (float-time))
                              (run-hooks 'elfeed-tree-update-hook)
                              (set-buffer-modified-p nil)))))
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (force-mode-line-update))))

(defun bs-elfeed--tree-resize-refresh (buffer)
  "Force a redraw of Elfeed Tree BUFFER after a resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-elfeed-tree--resize-timer nil)
      (elfeed-tree-update :force))))

(defun bs-elfeed--tree-window-size-change (_frame)
  "Schedule a Tree redraw when its displayed width changes."
  (when-let* ((buffer (get-buffer "*elfeed-tree*"))
              (window (get-buffer-window buffer t)))
    (with-current-buffer buffer
      (let ((width (window-body-width window)))
        (unless (equal width bs-elfeed-tree--render-width)
          (when (timerp bs-elfeed-tree--resize-timer)
            (cancel-timer bs-elfeed-tree--resize-timer))
          (setq bs-elfeed-tree--resize-timer
                (run-at-time
                 0.2 nil #'bs-elfeed--tree-resize-refresh
                 buffer)))))))

(defun bs-elfeed--tree-configure-buffer ()
  "Configure the current Elfeed Tree buffer for custom rendering."
  (bs-elfeed--ensure-update-timer)
  (setq-local truncate-lines t)
  (add-hook 'post-command-hook
            #'bs-elfeed--tree-update-indicators nil t)
  (outline-show-all)
  (bs-elfeed--tree-update-indicators))

;;;###autoload
(defun bs-elfeed-tree-enable ()
  "Enable the Gnus-inspired Elfeed Tree renderer."
  (interactive)
  (require 'elfeed-tree)
  (unless (eq elfeed-tree-header-function
              #'bs-elfeed--tree-header)
    (unless bs-elfeed-tree--original-header-function
      (setq bs-elfeed-tree--original-header-function
            elfeed-tree-header-function))
    (setq elfeed-tree-header-function
          #'bs-elfeed--tree-header))
  (unless bs-elfeed-tree--enabled
    (setq bs-elfeed-tree--enabled t)
    (advice-add 'elfeed-tree--update-immediately :override
                #'bs-elfeed--tree-update-immediately)
    (add-hook 'elfeed-tree-mode-hook
              #'bs-elfeed--tree-configure-buffer)
    (add-hook 'window-size-change-functions
              #'bs-elfeed--tree-window-size-change)
    (when-let* ((buffer (get-buffer "*elfeed-tree*")))
      (with-current-buffer buffer
        (when (derived-mode-p 'elfeed-tree-mode)
          (elfeed-tree-update :force)
          (bs-elfeed--tree-configure-buffer))))))

;;;###autoload
(defun bs-elfeed-tree-disable ()
  "Disable the Gnus-inspired Elfeed Tree renderer."
  (interactive)
  (when bs-elfeed-tree--enabled
    (setq bs-elfeed-tree--enabled nil)
    (when (eq elfeed-tree-header-function
              #'bs-elfeed--tree-header)
      (setq elfeed-tree-header-function
            bs-elfeed-tree--original-header-function))
    (advice-remove 'elfeed-tree--update-immediately
                   #'bs-elfeed--tree-update-immediately)
    (remove-hook 'elfeed-tree-mode-hook
                 #'bs-elfeed--tree-configure-buffer)
    (remove-hook 'window-size-change-functions
                 #'bs-elfeed--tree-window-size-change)
    (when-let* ((buffer (get-buffer "*elfeed-tree*")))
      (with-current-buffer buffer
        (remove-hook 'post-command-hook
                     #'bs-elfeed--tree-update-indicators t)
        (when (timerp bs-elfeed-tree--resize-timer)
          (cancel-timer bs-elfeed-tree--resize-timer)
          (setq bs-elfeed-tree--resize-timer nil))
        (when (derived-mode-p 'elfeed-tree-mode)
          (elfeed-tree-update :force))))))

(defun bs-elfeed--search-score-width ()
  "Return the fixed width reserved for Elfeed Search scores."
  (string-width
   (format "-%d" bs-elfeed-search-score-limit)))

(defun bs-elfeed--search-compact-score (score)
  "Return SCORE in compact unit notation."
  (let* ((absolute (abs score))
         (units '((1000000000000000.0 . "P")
                  (1000000000000.0 . "T")
                  (1000000000.0 . "G")
                  (1000000.0 . "M")
                  (1000.0 . "k")))
         (unit
          (or (cl-find-if (lambda (item)
                            (>= absolute (car item)))
                          units)
              (car (last units))))
         (scaled (/ (float absolute) (car unit)))
         (sign (if (< score 0) "-" ""))
         (number
          (if (and (>= score 0) (< scaled 10))
              (format "%.1f" scaled)
            (format "%.0f" scaled))))
    (concat sign number (cdr unit))))

(defun bs-elfeed--search-score (entry)
  "Return the numeric score for ENTRY."
  (if (fboundp 'elfeed-score-scoring-get-score-from-entry)
      (elfeed-score-scoring-get-score-from-entry entry)
    0))

(defun bs-elfeed--search-format-score (score)
  "Format SCORE as a fixed-width badge or blank field."
  (let* ((width (bs-elfeed--search-score-width))
         (content
          (cond
           ((zerop score) "")
           ((<= (abs score) bs-elfeed-search-score-limit)
            (number-to-string score))
           (t (bs-elfeed--search-compact-score score))))
         (content (bs-elfeed--truncate content width))
         (padding
          (make-string
           (max 0 (- width (string-width content))) ?\s)))
    (if (string-empty-p content)
        padding
      (concat
       padding
       (propertize
        content 'face
        (if (> score 0)
            'bs-elfeed-search-positive-score-face
          'bs-elfeed-search-negative-score-face))))))

(defun bs-elfeed-search-print-entry (entry)
  "Insert a one-line Gnus-inspired Search rendering for ENTRY."
  (let* ((start (point))
         (unread (memq 'unread (elfeed-entry-tags entry)))
         (marker
          (if unread
              (propertize "•" 'face 'bs-elfeed-search-unread-face)
            " "))
         (score
          (bs-elfeed--search-format-score
           (bs-elfeed--search-score entry)))
         (date
          (format-time-string
           bs-elfeed-search-date-format
           (seconds-to-time (elfeed-entry-date entry))))
         (width
          (bs-elfeed--buffer-width
           bs-elfeed-search-fallback-width))
         (fixed-width
          (+ 1 1 (bs-elfeed--search-score-width) 1
             2 (string-width date)
             bs-elfeed-search-right-margin-width))
         (title-width (max 0 (- width fixed-width)))
         (title
          (bs-elfeed--truncate
           (bs-elfeed--single-line
            (elfeed-entry-title entry) "[untitled]")
           title-width)))
    (insert
     score " " marker " "
     (propertize
      title 'face
      (if unread
          'bs-elfeed-search-unread-title-face
        'bs-elfeed-search-read-title-face))
     (make-string
      (max 2 (- width fixed-width (string-width title) -2)) ?\s)
     (propertize date 'face 'bs-elfeed-search-timestamp-face)
     (make-string bs-elfeed-search-right-margin-width ?\s))
    (when (= start (point-min))
      (add-text-properties
       start (1+ start)
       `(bs-elfeed-header-bottom-spacing t
                                         line-prefix
                                         ,(bs-elfeed--top-spacing-prefix
                                           bs-elfeed-header-bottom-spacing))))))

(defun bs-elfeed--search-header ()
  "Return a Gnus-inspired header for the Elfeed Search buffer."
  (let
      ((header
        (or
         (elfeed--header-jobs)
         (let* ((shown (length elfeed-search-entries))
                (unread
                 (cl-count-if
                  (lambda (entry)
                    (memq 'unread (elfeed-entry-tags entry)))
                  elfeed-search-entries))
                (total (elfeed-db-size))
                (statistics
                 (concat
                  (propertize
                   (format "%d unread" unread)
                   'face 'bs-elfeed-search-overview-unread-face)
                  (propertize " · "
                              'face 'bs-elfeed-tree-separator-face)
                  (propertize
                   (format "%d shown" shown)
                   'face 'bs-elfeed-search-overview-shown-face)
                  (propertize " · "
                              'face 'bs-elfeed-tree-separator-face)
                  (propertize
                   (format "%d total" total)
                   'face 'bs-elfeed-search-overview-total-face)))
                (label
                 (propertize "SEARCH" 'face 'bs-elfeed-search-overview-face))
                (width
                 (bs-elfeed--buffer-width
                  bs-elfeed-search-fallback-width))
                (filter-width
                 (max 0 (- width
                           (string-width "SEARCH  ")
                           (string-width statistics) 1)))
                (filter
                 (propertize
                  (bs-elfeed--truncate elfeed-search-filter filter-width)
                  'face 'bs-elfeed-search-filter-face))
                (padding
                 (bs-elfeed--header-right-padding statistics)))
           (concat label " " filter padding statistics)))))
    (add-face-text-property
     0 (length header) 'bs-elfeed-search-header-face t header)
    header))

(defun bs-elfeed--search-month-string (title first-p)
  "Return a Search month separator for TITLE.
FIRST-P says that this is the first separator in the buffer."
  (let ((top-spacing
         (+ bs-elfeed-search-month-line-spacing
            (if first-p bs-elfeed-header-bottom-spacing 0))))
    (concat
     (bs-elfeed--top-spacing-prefix top-spacing)
     (propertize
      (concat title "\n")
      'face 'bs-elfeed-search-month-face
      'bs-elfeed-search-month-separator t
      'line-spacing bs-elfeed-search-month-line-spacing))))

(defun bs-elfeed--search-add-separators ()
  "Add styled month separators to the current Elfeed Search buffer."
  (let ((last nil)
        (overlay nil)
        (count 0))
    (remove-overlays
     (point-min) (point-max) 'category 'elfeed-search-separator)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when-let* ((entry (get-text-property (point) 'elfeed-entry))
                    (title (elfeed-search--separator-title entry))
                    ((not (equal title last))))
          (cl-incf count)
          (setq overlay (make-overlay (line-beginning-position)
                                      (line-beginning-position)))
          (overlay-put overlay 'category 'elfeed-search-separator)
          (overlay-put overlay 'before-string
                       (bs-elfeed--search-month-string title (null last)))
          (setq last title))
        (forward-line 1)))
    (when (= count 1)
      (delete-overlay overlay))))

(defun bs-elfeed--search-configure-buffer ()
  "Configure the current Elfeed Search buffer for custom rendering."
  (bs-elfeed--ensure-update-timer)
  (unless bs-elfeed-search--line-spacing-saved-p
    (setq bs-elfeed-search--saved-line-spacing-local-p
          (local-variable-p 'line-spacing)
          bs-elfeed-search--saved-line-spacing line-spacing
          bs-elfeed-search--line-spacing-saved-p t))
  (setq-local line-spacing bs-elfeed-search-line-spacing
              truncate-lines t))

(defun bs-elfeed--search-restore-buffer ()
  "Restore Search line spacing saved by the custom renderer."
  (when bs-elfeed-search--line-spacing-saved-p
    (if bs-elfeed-search--saved-line-spacing-local-p
        (setq-local line-spacing
                    bs-elfeed-search--saved-line-spacing)
      (kill-local-variable 'line-spacing))
    (setq bs-elfeed-search--line-spacing-saved-p nil)))

(defun bs-elfeed--search-buffers ()
  "Return all live Elfeed Search buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'elfeed-search-mode)))
   (buffer-list)))

;;;###autoload
(defun bs-elfeed-search-enable ()
  "Enable the Gnus-inspired Elfeed Search renderer."
  (interactive)
  (unless bs-elfeed-search--enabled
    (setq bs-elfeed-search--enabled t
          bs-elfeed-search--original-header-function
          elfeed-search-header-function
          bs-elfeed-search--original-print-entry-function
          elfeed-search-print-entry-function
          elfeed-search-header-function
          #'bs-elfeed--search-header
          elfeed-search-print-entry-function
          #'bs-elfeed-search-print-entry)
    (add-hook 'elfeed-search-mode-hook
              #'bs-elfeed--search-configure-buffer)
    (advice-add 'elfeed-search-add-separators :override
                #'bs-elfeed--search-add-separators)
    (dolist (buffer (bs-elfeed--search-buffers))
      (with-current-buffer buffer
        (bs-elfeed--search-configure-buffer)
        (elfeed-search-update :force)))))

;;;###autoload
(defun bs-elfeed-search-disable ()
  "Disable the Gnus-inspired Elfeed Search renderer."
  (interactive)
  (when bs-elfeed-search--enabled
    (setq bs-elfeed-search--enabled nil)
    (when (eq elfeed-search-header-function
              #'bs-elfeed--search-header)
      (setq elfeed-search-header-function
            bs-elfeed-search--original-header-function))
    (when (eq elfeed-search-print-entry-function
              #'bs-elfeed-search-print-entry)
      (setq elfeed-search-print-entry-function
            bs-elfeed-search--original-print-entry-function))
    (remove-hook 'elfeed-search-mode-hook
                 #'bs-elfeed--search-configure-buffer)
    (advice-remove 'elfeed-search-add-separators
                   #'bs-elfeed--search-add-separators)
    (dolist (buffer (bs-elfeed--search-buffers))
      (with-current-buffer buffer
        (bs-elfeed--search-restore-buffer)
        (elfeed-search-update :force)))))

(provide 'bs-elfeed)
;;; bs-elfeed.el ends here
