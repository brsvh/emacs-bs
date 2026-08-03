;;; bs-gnus.el --- Gnus integration  -*- lexical-binding:t -*-

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

;; This package provides personal Gnus extensions.

;;; Code:

(require 'cl-lib)
(require 'bs-lib)
(require 'gnus)
(require 'mail-parse)
(require 'subr-x)

(declare-function mail-header-date "nnheader" (header))
(declare-function mail-header-from "nnheader" (header))
(declare-function mail-header-id "nnheader" (header))
(declare-function mail-header-number "nnheader" (header))
(declare-function mail-header-references "nnheader" (header))
(declare-function mail-header-subject "nnheader" (header))
(declare-function gnus-data-compute-positions "gnus-sum" ())
(declare-function gnus-data-header "gnus-sum" (data))
(declare-function gnus-data-level "gnus-sum" (data))
(declare-function gnus-data-mark "gnus-sum" (data))
(declare-function gnus-data-number "gnus-sum" (data))
(declare-function gnus-data-pos "gnus-sum" (data))
(declare-function gnus-highlight-selected-summary "gnus-sum" ())
(declare-function gnus-summary-article-number "gnus-sum" ())
(declare-function gnus-summary-select-article
                  "gnus-sum"
                  (&optional all-headers force pseudo article))
(declare-function gnus-summary-goto-subject
                  "gnus-sum" (article &optional force silent))
(declare-function gnus-summary-insert-old-articles
                  "gnus-sum" (&optional all))
(declare-function gnus-summary-insert-new-articles "gnus-sum" ())
(declare-function gnus-summary-prepare "gnus-sum" ())
(declare-function gnus-summary-recenter "gnus-sum" ())
(declare-function gnus-split-references "gnus-sum" (references))
(declare-function gnus-group-list-groups
                  "gnus-group"
                  (&optional level unread lowest update-level))
(declare-function gnus-topic-fold "gnus-topic" (&optional insert topic))
(declare-function gnus-topic-goto-topic "gnus-topic" (topic))
(declare-function gnus-topic-indent "gnus-topic" ())
(declare-function gnus-topic-unindent "gnus-topic" ())
(declare-function gnus-topic-update-topic-line
                  "gnus-topic" (topic-name &optional reads))
(declare-function gnus-update-format-specifications
                  "gnus-spec"
                  (&optional force type1 type2 type3 type4))
(declare-function gnus-update-summary-mark-positions "gnus-sum" ())
(declare-function gnus-article-read-summary-keys
                  "gnus-art"
                  (&optional arg key not-restore-window))
(declare-function gnus-article-prepare-display "gnus-art" ())
(declare-function hl-line-highlight "hl-line" ())
(declare-function hl-line-move "hl-line" (overlay))
(declare-function gnus-agent-fetch-articles
                  "gnus-agent" (group articles))
(declare-function gnus-agent-method-p "gnus" (method-or-server))
(declare-function gnus-agent-request-article
                  "gnus-agent" (article group))
(declare-function gnus-sorted-ndifference "gnus-range" (list1 list2))
(declare-function gnus-summary-update-download-mark
                  "gnus-sum" (article))
(declare-function nntp-list-active-group
                  "nntp" (group &optional server))

(defvar gnus-current-article)
(defvar gnus-agent)
(defvar gnus-agent-cache)
(defvar gnus-article-buffer)
(defvar gnus-article-internal-prepare-hook)
(defvar gnus-command-method)
(defvar gnus-dormant-mark)
(defvar gnus-auto-extend-newsgroup)
(defvar gnus-newsgroup-cached)
(defvar gnus-newsgroup-ancient)
(defvar gnus-newsgroup-data)
(defvar gnus-newsgroup-dependencies)
(defvar gnus-newsgroup-forwarded)
(defvar gnus-newsgroup-limit)
(defvar gnus-newsgroup-limits)
(defvar gnus-newsgroup-name)
(defvar gnus-newsgroup-prepared)
(defvar gnus-newsgroup-processable)
(defvar gnus-newsgroup-replied)
(defvar gnus-newsgroup-saved)
(defvar gnus-newsgroup-sparse)
(defvar gnus-newsgroup-undownloaded)
(defvar gnus-newsgroup-unseen)
(defvar gnus-group-list-mode)
(defvar gnus-summary-line-format)
(defvar gnus-summary-buffer)
(defvar gnus-ticked-mark)
(defvar gnus-topic-alist)
(defvar gnus-topic-indent-level)
(defvar gnus-topic-mode)
(defvar gnus-tmp-thread-tree-header-string)
(defvar gnus-tmp-internal-hook)
(defvar gnus-tmp-unread)
(defvar gnus-unread-mark)
(defvar hl-line-mode)
(defvar hl-line-overlay)
(defvar nntp-server-buffer)

(defgroup bs-gnus nil
  "Personal Gnus extensions."
  :group 'gnus)

(defface bs-gnus-summary-title-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for thread subjects."
  :group 'bs-gnus)

(defface bs-gnus-summary-correspondent-face
  '((t :inherit gnus-summary-normal-read :slant italic))
  "Face for article correspondents in Summary buffers."
  :group 'bs-gnus)

(defface bs-gnus-summary-unread-correspondent-face
  '((t :inherit default :weight bold :slant italic))
  "Face for correspondents of unread articles."
  :group 'bs-gnus)

(defface bs-gnus-summary-label-face
  '((t :inherit gnus-summary-normal-read :weight regular :underline nil))
  "Parent face for labels in Summary buffers."
  :group 'bs-gnus)

(defface bs-gnus-summary-thread-count-face
  '((t :inherit (font-lock-keyword-face bs-gnus-summary-label-face)
       :weight semibold :inverse-video t))
  "Face for thread article-count labels."
  :group 'bs-gnus)

(defface bs-gnus-summary-unread-thread-count-face
  '((t :inherit (error bs-gnus-summary-label-face)
       :weight semibold :inverse-video t))
  "Face for thread counts containing unread articles."
  :group 'bs-gnus)

(defface bs-gnus-summary-timestamp-face
  '((t :inherit (shadow bs-gnus-summary-label-face)
       :weight normal :slant normal :strike-through nil))
  "Face for article timestamps."
  :group 'bs-gnus)

(defface bs-gnus-summary-context-face
  '((t :inherit shadow :weight normal))
  "Face for old articles displayed only to connect a thread."
  :group 'bs-gnus)

(defface bs-gnus-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for complete Gnus header lines."
  :group 'bs-gnus)

(defface bs-gnus-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in Gnus header lines."
  :group 'bs-gnus)

(defface bs-gnus-summary-group-face
  '((t :inherit header-line :weight bold))
  "Face for sources in a Summary header line."
  :group 'bs-gnus)

(defface bs-gnus-summary-group-name-face
  '((t :inherit font-lock-keyword-face
       :weight bold :slant italic))
  "Face for the group name in a Summary header line."
  :group 'bs-gnus)

(defface bs-gnus-summary-group-unread-face
  '((t :inherit error :weight semibold))
  "Face for nonzero unread counts on Summary overview lines."
  :group 'bs-gnus)

(defface bs-gnus-summary-group-empty-unread-face
  '((t :inherit shadow))
  "Face for zero unread counts on Summary overview lines."
  :group 'bs-gnus)

(defface bs-gnus-summary-group-loaded-face
  '((t :inherit success))
  "Face for loaded article counts on Summary overview lines."
  :group 'bs-gnus)

(defface bs-gnus-summary-fold-indicator-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for folded-reply indicators."
  :group 'bs-gnus)

(defface bs-gnus-group-unread-face
  '((t :inherit error :weight bold))
  "Face for nonzero unread counts in Group buffers."
  :group 'bs-gnus)

(defface bs-gnus-group-read-face
  '((t :inherit shadow))
  "Face for zero unread counts in Group buffers."
  :group 'bs-gnus)

(defface bs-gnus-group-total-face
  '((t :inherit shadow))
  "Face for total article counts in Group buffers."
  :group 'bs-gnus)

(defface bs-gnus-group-separator-face
  '((t :inherit shadow))
  "Face for separators in Group buffer article counts."
  :group 'bs-gnus)

(defface bs-gnus-group-name-face
  '((t :inherit default))
  "Face for group names regardless of their unread state."
  :group 'bs-gnus)

(defface bs-gnus-group-source-face
  '((t :inherit shadow))
  "Face for right-aligned source labels in Group buffers."
  :group 'bs-gnus)

(defface bs-gnus-group-topic-face
  '((t :inherit bs-gnus-summary-title-face))
  "Face for topic names in Group buffers."
  :group 'bs-gnus)

(defface bs-gnus-group-root-topic-face
  '((t :height 1.30))
  "Relative size applied to the root Topic row."
  :group 'bs-gnus)

(defface bs-gnus-group-top-level-topic-face
  '((t :height 1.15))
  "Relative size applied to top-level Topic rows."
  :group 'bs-gnus)

(defface bs-gnus-group-topic-count-face
  '((t :inherit error :weight semibold :inverse-video nil))
  "Face for nonzero topic unread counts."
  :group 'bs-gnus)

(defface bs-gnus-group-topic-empty-count-face
  '((t :inherit shadow))
  "Face for zero topic unread counts."
  :group 'bs-gnus)

(defcustom bs-gnus-summary-date-format "%m/%d/%Y %I:%M:%S %p"
  "Format used for article dates in Summary buffers."
  :type 'string
  :group 'bs-gnus)

(defcustom bs-gnus-summary-fold-indicator ?▸
  "Character displayed at the left edge of an article with folded replies."
  :type 'character
  :group 'bs-gnus)

(defcustom bs-gnus-summary-thread-count-digits 4
  "Minimum columns reserved for complete thread article-count labels.
The width includes separators and a trailing context marker."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-summary-thread-count-padding 0.5
  "Colored padding beside thread article counts, in character widths."
  :type 'number
  :group 'bs-gnus)

(defcustom bs-gnus-summary-fallback-width 100
  "Width used when a Summary buffer has no live window."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-summary-auto-extend-count 100
  "Number of older articles inserted when Summary movement reaches its end.
A value of zero disables batch insertion without changing
`gnus-auto-extend-newsgroup'."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-summary-follow-visible-article nil
  "Whether Summary navigation follows point in a visible Article buffer."
  :type 'boolean
  :group 'bs-gnus)

(defcustom bs-gnus-context-buffer-name "*Gnus Thread Context*"
  "Name of the buffer containing the latest Gnus context."
  :type 'string
  :group 'bs-gnus)

(defcustom bs-gnus-summary-display-thread-context nil
  "Whether to display the generated thread context buffer.
When nil, keep the buffer named by `bs-gnus-context-buffer-name'
hidden and select the current Summary row.  When non-nil, display
that buffer and select all of its text."
  :type 'boolean
  :group 'bs-gnus)

(defcustom bs-gnus-summary-thread-context-hook nil
  "Hook run after preparing a Gnus thread context.
The hook runs in the originating Summary buffer while the buffer
named by `bs-gnus-context-buffer-name' contains the selected
subthread."
  :type 'hook
  :group 'bs-gnus)

(defcustom bs-gnus-group-count-width 9
  "Minimum total columns reserved for a Group buffer article count."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-group-source-names nil
  "Alist mapping NNTP server addresses to Group buffer source labels.
Each element has the form (ADDRESS . NAME).  NNTP servers absent
from the alist use the label `Usenet'."
  :type '(alist :key-type string :value-type string)
  :group 'bs-gnus)

(defcustom bs-gnus-group-fallback-width 100
  "Width used when a Group buffer has no live window."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-group-topic-spacing-height 0.65
  "Relative spacing added around Topic rows."
  :type 'number
  :group 'bs-gnus)

(defcustom bs-gnus-header-bottom-spacing 0.5
  "Relative line height reserved below Gnus header lines."
  :type 'number
  :group 'bs-gnus)

(defconst bs-gnus--summary-line-format "    %U%R%O%z%*  %ub\n"
  "Gnus Summary format used by the custom renderer.")

(defconst bs-gnus--summary-prefix-width 10
  "Columns reserved before the thread-tree prefix.")

(defconst bs-gnus--summary-setting-symbols
  '(gnus-summary-line-format
    header-line-format)
  "Buffer-local settings replaced by the custom renderer.")

(defvar bs-gnus--summary-enabled nil
  "Non-nil when the custom Summary renderer is installed.")

(defvar bs-gnus--summary-navigation-from-article nil
  "Non-nil while an Article buffer delegates a Summary command.")

(defvar bs-gnus--summary-original-user-format-function nil
  "Saved definition of `gnus-user-format-function-b'.")

(defvar-local bs-gnus--summary-decoration-timer nil
  "Idle timer used to debounce Summary decoration.")

(defvar-local bs-gnus--summary-context-prefixes nil
  "Omitted thread-prefix headers keyed by the retained root article.")

(defvar-local bs-gnus--summary-fold-state nil
  "Hash table containing article numbers whose replies are folded.")

(defvar-local bs-gnus--summary-original-settings nil
  "Settings replaced in the current Summary buffer.")

(defvar-local bs-gnus--summary-render-width nil
  "Width used for the latest Summary render.")

(defvar-local bs-gnus--summary-rendered nil
  "Non-nil when the current Summary buffer is decorated.")

(defvar-local bs-gnus--summary-resize-timer nil
  "Idle timer used to debounce Summary resize rendering.")

(defvar bs-gnus--group-enabled nil
  "Non-nil when the custom Group renderer is installed.")

(defvar-local bs-gnus--group-decoration-timer nil
  "Idle timer used to debounce Group buffer decoration.")

(defvar-local bs-gnus--group-render-width nil
  "Width used for the latest Group buffer render.")

(defvar-local bs-gnus--group-original-header-line-format nil
  "Header line format saved before enabling the Group renderer.")

(defvar-local bs-gnus--group-header-line-saved-p nil
  "Non-nil after saving the Group buffer's header line format.")

(defvar-local bs-gnus--group-resize-timer nil
  "Idle timer used to debounce Group buffer resize rendering.")

(defvar bs-gnus--group-posting-status-cache
  (make-hash-table :test #'equal)
  "NNTP posting statuses cached by full Gnus group name.")

(put 'bs-gnus--summary-fold-state 'permanent-local t)

;;;###autoload
(defun bs-gnus-group-posting-status (group &optional refresh)
  "Return the NNTP posting status for GROUP.
The result is one of the characters `?y', `?m', or `?n', as
reported by `LIST ACTIVE'.  GROUP is a full Gnus group name.
Reuse a status cached during this Emacs session unless REFRESH is
non-nil."
  (or (and (not refresh)
           (gethash group bs-gnus--group-posting-status-cache))
      (let* ((method (gnus-find-method-for-group group))
             (backend (car method))
             (server (cadr method))
             (real-group (gnus-group-real-name group)))
        (unless (eq backend 'nntp)
          (user-error "%s is not an NNTP group" group))
        (require 'nntp)
        (unless (nntp-list-active-group real-group server)
          (user-error "Cannot query the posting status of %s" group))
        (with-current-buffer nntp-server-buffer
          (goto-char (point-min))
          (unless (re-search-forward
                   (concat
                    "^" (regexp-quote real-group)
                    "[\t ]+[0-9]+[\t ]+[0-9]+[\t ]+"
                    "\\([ymn]\\)[\t ]*\r?$")
                   nil t)
            (user-error "Unknown posting status for %s" group))
          (let ((status (string-to-char (match-string 1))))
            (puthash group status
                     bs-gnus--group-posting-status-cache)
            status)))))

(defun bs-gnus--group-window ()
  "Return a window suitable for sizing the current Group buffer."
  (or (and (eq (window-buffer (selected-window)) (current-buffer))
           (selected-window))
      (get-buffer-window (current-buffer) t)))

(defun bs-gnus--group-width ()
  "Return the display width for the current Group buffer."
  (if-let* ((window (bs-gnus--group-window)))
      (window-body-width window)
    bs-gnus-group-fallback-width))

(defun bs-gnus--group-truncate (string width)
  "Truncate STRING to WIDTH columns with an ASCII ellipsis."
  (cond
   ((<= width 0) "")
   ((<= (string-width string) width) string)
   (t
    (truncate-string-to-width
     string width 0 nil (and (> width 3) "...")))))

(defun bs-gnus--group-right-padding (string)
  "Return padding that right-aligns STRING with a two-column margin."
  (propertize
   " "
   'display
   `(space
     :align-to
     (- right
        (+ (,(string-pixel-width string)) 2)))))

(defun bs-gnus--header-right-padding (string)
  "Return pixel-aware padding that right-aligns header STRING."
  (propertize
   " " 'display
   `(space
     :align-to
     (- right
        (+ (,(string-pixel-width string)) 1)))))

(defun bs-gnus--top-spacing-prefix (spacing)
  "Return a zero-width line prefix adding SPACING above a row."
  (propertize
   " " 'display
   `(space
     :width 0
     :height ,(+ 1.0 (max 0 spacing))
     :ascent 100)))

(defun bs-gnus--group-source (group)
  "Return the concise source label for GROUP."
  (let* ((method (gnus-find-method-for-group group))
         (address
          (or (cadr (assq 'nntp-address (cddr method)))
              (nth 1 method)))
         (name
          (and address
               (cdr
                (assoc-string
                 address bs-gnus-group-source-names t)))))
    (cond
     (name name)
     ((eq (car method) 'nntp)
      "Usenet")
     (t "Local"))))

(defun bs-gnus--group-display-name (group)
  "Return the display name for GROUP."
  (gnus-group-real-name group))

(defun bs-gnus--group-total (group)
  "Return the estimated number of articles available in GROUP."
  (if-let* ((active (gnus-active group)))
      (1+ (- (cdr active) (car active)))
    0))

(defun bs-gnus--group-max-indentation-width ()
  "Return the widest group indentation represented in the Topic tree."
  (let ((width 0))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((indentation
               (get-text-property
                (line-beginning-position)
                'gnus-indentation))
              (level
               (get-text-property
                (line-beginning-position)
                'gnus-topic-level)))
          (setq width
                (max width
                     (if (stringp indentation)
                         (string-width indentation)
                       0)
                     (if (numberp level)
                         (* level gnus-topic-indent-level)
                       0))))
        (forward-line 1)))
    width))

(defun bs-gnus--group-count-widths ()
  "Return unread, total, and indentation widths for Group counts."
  (let ((unread-width 2)
        (total-width 1))
    (dolist (group (bs-gnus--group-groups))
      (let* ((entry (gnus-group-entry group))
             (unread (and entry (car entry))))
        (setq unread-width
              (max unread-width
                   (string-width
                    (if (numberp unread)
                        (number-to-string (max 0 unread))
                      "*")))
              total-width
              (max total-width
                   (string-width
                    (number-to-string
                     (bs-gnus--group-total group)))))))
    (setq total-width
          (+ total-width
             (max 0
                  (- bs-gnus-group-count-width
                     unread-width 1 total-width))))
    (list
     unread-width
     total-width
     (bs-gnus--group-max-indentation-width))))

(defun bs-gnus--group-format-row
    (group unread indentation width count-widths)
  "Format GROUP with UNREAD articles and INDENTATION for WIDTH.
COUNT-WIDTHS contains the unread, total, and indentation widths."
  (let* ((unread-width
          (+ (nth 0 count-widths)
             (max
              0
              (- (nth 2 count-widths)
                 (string-width indentation)))))
         (total-width (nth 1 count-widths))
         (unread-number (and (numberp unread) (max 0 unread)))
         (unread-string
          (format
           (format "%%%ds" unread-width)
           (if unread-number (number-to-string unread-number) "*")))
         (total-string
          (number-to-string (bs-gnus--group-total group)))
         (unread-face
          (if (and unread-number (> unread-number 0))
              'bs-gnus-group-unread-face
            'bs-gnus-group-read-face))
         (count
          (concat
           (propertize unread-string 'face unread-face)
           (propertize "/" 'face 'bs-gnus-group-separator-face)
           (propertize total-string 'face 'bs-gnus-group-total-face)
           (make-string
            (max 0 (- total-width (string-width total-string)))
            ?\s)))
         (prefix (concat indentation count "  "))
         (source
          (propertize
           (bs-gnus--group-source group)
           'face 'bs-gnus-group-source-face))
         (name-width
          (max 0
               (- width
                  (string-width prefix)
                  (string-width source)
                  4)))
         (name
          (propertize
           (bs-gnus--group-truncate
            (bs-gnus--group-display-name group)
            name-width)
           'face 'bs-gnus-group-name-face))
         (padding
          (bs-gnus--group-right-padding source)))
    (concat prefix name padding source)))

(defun bs-gnus--group-topic-level-face (level)
  "Return the relative-size face for a Topic at LEVEL."
  (cond
   ((zerop level) 'bs-gnus-group-root-topic-face)
   ((= level 1) 'bs-gnus-group-top-level-topic-face)))

(defun bs-gnus--group-root-statistics (unread)
  "Return root Topic statistics containing UNREAD articles."
  (let* ((groups (bs-gnus--group-groups))
         (total
          (cl-loop
           for group in groups
           sum (bs-gnus--group-total group)))
         (unread (if (numberp unread) (max 0 unread) 0))
         (unread-face
          (if (> unread 0)
              'bs-gnus-group-topic-count-face
            'bs-gnus-group-topic-empty-count-face)))
    (concat
     (propertize
      (format "%d subscribed · " (length groups))
      'face 'bs-gnus-group-source-face)
     (propertize
      (number-to-string unread)
      'face unread-face)
     (propertize
      " unread · "
      'face 'bs-gnus-group-source-face)
     (propertize
      (number-to-string total)
      'face 'bs-gnus-group-total-face)
     (propertize
      " total"
      'face 'bs-gnus-group-source-face))))

(defun bs-gnus--group-root-unread ()
  "Return the unread count stored on the root Group Topic."
  (save-excursion
    (goto-char (point-min))
    (catch 'unread
      (while (not (eobp))
        (when (zerop
               (or (get-text-property
                    (line-beginning-position) 'gnus-topic-level)
                   -1))
          (throw
           'unread
           (or (get-text-property
                (line-beginning-position) 'gnus-topic-unread)
               0)))
        (forward-line 1))
      0)))

(defun bs-gnus--group-header ()
  "Return right-aligned statistics for the Group header."
  (let* ((statistics
          (bs-gnus--group-root-statistics
           (bs-gnus--group-root-unread)))
         (header
          (concat
           (bs-gnus--header-right-padding statistics)
           statistics)))
    (add-face-text-property
     0 (length header) 'bs-gnus-header-face t header)
    header))

(defun bs-gnus--group-format-topic
    (topic level unread visible width)
  "Format TOPIC at LEVEL with UNREAD articles for WIDTH.

VISIBLE says whether the topic is expanded."
  (let* ((prefix
          (if visible
              "  "
            (propertize
             "▸ " 'face 'bs-gnus-group-topic-face)))
         (count-string
          (number-to-string (if (numberp unread) unread 0)))
         (count
          (let ((face
                 (if (and (numberp unread) (> unread 0))
                     'bs-gnus-group-topic-count-face
                   'bs-gnus-group-topic-empty-count-face)))
            (propertize count-string 'face face)))
         (statistics
          (if (zerop level)
              ""
            (concat
             (propertize
              " (" 'face 'bs-gnus-group-separator-face)
             count
             (propertize
              ")" 'face 'bs-gnus-group-separator-face))))
         (title-width
          (max 0
               (- width
                  (string-width prefix)
                  (string-width statistics))))
         (title
          (propertize
           (bs-gnus--group-truncate topic title-width)
           'face 'bs-gnus-group-topic-face))
         (line (concat prefix title statistics)))
    (when-let* ((face
                 (bs-gnus--group-topic-level-face level)))
      (add-face-text-property
       (length prefix)
       (length line)
       face t line))
    line))

(defun bs-gnus--group-preserved-properties ()
  "Return operational properties on the current Group buffer line."
  (let ((properties
         (text-properties-at (line-beginning-position)))
        preserved)
    (while properties
      (let ((property (pop properties))
            (value (pop properties)))
        (unless (memq property '(display face font-lock-face))
          (setq preserved
                (nconc preserved (list property value))))))
    preserved))

(defun bs-gnus--group-replace-line (string)
  "Replace the current Group buffer line with STRING."
  (let ((beginning (line-beginning-position))
        (end (line-end-position))
        (properties (bs-gnus--group-preserved-properties)))
    (delete-region beginning end)
    (insert string)
    (add-text-properties beginning (point) properties)))

(defun bs-gnus--group-groups ()
  "Return groups assigned to topics without duplicates."
  (let (groups)
    (dolist (topic gnus-topic-alist)
      (dolist (group (cdr topic))
        (when (stringp group)
          (cl-pushnew group groups :test #'equal))))
    groups))

(defun bs-gnus--group-add-topic-spacing (position trailing)
  "Add spacing around the Topic row at POSITION.
TRAILING says to add spacing below the row as well."
  (save-excursion
    (goto-char position)
    (let* ((newline (line-end-position))
           (level
            (get-text-property position 'gnus-topic-level))
           (spacing
            (+ bs-gnus-group-topic-spacing-height
               (if (and (numberp level) (zerop level))
                   bs-gnus-header-bottom-spacing
                 0)))
           (prefix
            (bs-gnus--top-spacing-prefix spacing)))
      (when (< position (point-max))
        (add-text-properties
         position (1+ position)
         `(bs-gnus-group-topic-spacing t
                                       line-prefix ,prefix)))
      (when trailing
        (add-text-properties
         newline (1+ newline)
         `(bs-gnus-group-topic-spacing t
                                       line-spacing
                                       ,bs-gnus-group-topic-spacing-height))))))

(defun bs-gnus--group-remove-topic-spacing ()
  "Remove partial-line spacing added around Topics."
  (let ((limit (point-max))
        (position (point-min)))
    (while (setq position
                 (text-property-any
                  position limit
                  'bs-gnus-group-topic-spacing t))
      (let ((end
             (next-single-property-change
              position
              'bs-gnus-group-topic-spacing
              nil limit)))
        (remove-text-properties
         position end
         '(bs-gnus-group-topic-spacing nil
                                       line-prefix nil
                                       line-height nil
                                       line-spacing nil))
        (setq position end)))))

(defun bs-gnus--group-remove-decorations ()
  "Remove custom overview and separator lines from the Group buffer."
  (let ((inhibit-read-only t))
    (bs-gnus--group-remove-topic-spacing)
    (goto-char (point-min))
    (while (not (eobp))
      (if (get-text-property
           (line-beginning-position)
           'bs-gnus-group-decoration)
          (delete-region
           (line-beginning-position)
           (line-beginning-position 2))
        (forward-line 1)))))

(defun bs-gnus--group-topic-rows ()
  "Return Topic row positions paired with trailing-spacing flags."
  (let (rows)
    (goto-char (point-min))
    (while (not (eobp))
      (when (get-text-property
             (line-beginning-position) 'gnus-topic)
        (let* ((position (line-beginning-position))
               (next-line (line-beginning-position 2))
               (next-topic
                (get-text-property next-line 'gnus-topic)))
          (push (cons position (not next-topic)) rows)))
      (forward-line 1))
    (nreverse rows)))

(defun bs-gnus--group-decorate ()
  "Decorate the current native Gnus Group buffer."
  (when (and bs-gnus--group-enabled
             (derived-mode-p 'gnus-group-mode)
             (bound-and-true-p gnus-topic-mode))
    (let ((topic
           (get-text-property
            (line-beginning-position) 'gnus-topic))
          (column (current-column))
          (width (bs-gnus--group-width))
          (count-widths (bs-gnus--group-count-widths))
          (inhibit-read-only t))
      (save-excursion
        (bs-gnus--group-remove-decorations)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((group
                 (get-text-property
                  (line-beginning-position) 'gnus-group))
                (topic
                 (get-text-property
                  (line-beginning-position) 'gnus-topic)))
            (cond
             (topic
              (let ((level
                     (get-text-property
                      (line-beginning-position)
                      'gnus-topic-level))
                    (unread
                     (get-text-property
                      (line-beginning-position)
                      'gnus-topic-unread))
                    (visible
                     (get-text-property
                      (line-beginning-position)
                      'gnus-topic-visible)))
                (bs-gnus--group-replace-line
                 (bs-gnus--group-format-topic
                  topic level unread visible width))))
             (group
              (bs-gnus--group-replace-line
               (bs-gnus--group-format-row
                group
                (get-text-property
                 (line-beginning-position) 'gnus-unread)
                (or (get-text-property
                     (line-beginning-position)
                     'gnus-indentation)
                    "")
                width
                count-widths)))))
          (forward-line 1))
        (dolist (row (bs-gnus--group-topic-rows))
          (bs-gnus--group-add-topic-spacing
           (car row) (cdr row))))
      (setq bs-gnus--group-render-width width)
      (force-mode-line-update)
      (when (and topic (gnus-topic-goto-topic topic))
        (move-to-column column)))))

(defun bs-gnus--group-after-topic-change (&rest _arguments)
  "Redecorate a Group buffer after its topic structure changes."
  (when (derived-mode-p 'gnus-group-mode)
    (bs-gnus--group-decorate)))

(defun bs-gnus--group-around-topic-fold (function &rest arguments)
  "Call FUNCTION with ARGUMENTS while preserving point on its Topic."
  (let ((topic
         (and (derived-mode-p 'gnus-group-mode)
              (get-text-property
               (line-beginning-position) 'gnus-topic)))
        (column (current-column)))
    (prog1
        (apply function arguments)
      (when (derived-mode-p 'gnus-group-mode)
        (when (timerp bs-gnus--group-decoration-timer)
          (cancel-timer bs-gnus--group-decoration-timer)
          (setq bs-gnus--group-decoration-timer nil))
        (bs-gnus--group-decorate)
        (when (and topic (gnus-topic-goto-topic topic))
          (move-to-column column))))))

(defun bs-gnus--group-run-decoration (buffer)
  "Decorate Group BUFFER after a debounced native update."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-gnus--group-decoration-timer nil)
      (bs-gnus--group-decorate))))

(defun bs-gnus--group-schedule-decoration (&rest _arguments)
  "Schedule decoration after a native Group or Topic line update."
  (when (derived-mode-p 'gnus-group-mode)
    (when (timerp bs-gnus--group-decoration-timer)
      (cancel-timer bs-gnus--group-decoration-timer))
    (setq bs-gnus--group-decoration-timer
          (run-with-idle-timer
           0.05 nil
           #'bs-gnus--group-run-decoration
           (current-buffer)))))

(defun bs-gnus--group-rerender (buffer)
  "Rerender visible Group BUFFER after a debounced resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-gnus--group-resize-timer nil)
      (when (and bs-gnus--group-enabled
                 (get-buffer-window buffer t)
                 (not (equal
                       (bs-gnus--group-width)
                       bs-gnus--group-render-width)))
        (bs-gnus--group-decorate)))))

(defun bs-gnus--group-schedule-resize (buffer)
  "Schedule a debounced resize render for Group BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (timerp bs-gnus--group-resize-timer)
        (cancel-timer bs-gnus--group-resize-timer))
      (setq bs-gnus--group-resize-timer
            (run-with-idle-timer
             0.2 nil #'bs-gnus--group-rerender buffer)))))

(defun bs-gnus--group-window-size-change (frame)
  "Schedule rerenders for visible Group buffers on FRAME."
  (let ((seen (make-hash-table :test #'eq)))
    (dolist (window (window-list frame 'no-minibuffer))
      (let ((buffer (window-buffer window)))
        (when (and (not (gethash buffer seen))
                   (buffer-live-p buffer)
                   (with-current-buffer buffer
                     (and (derived-mode-p 'gnus-group-mode)
                          bs-gnus--group-enabled)))
          (puthash buffer t seen)
          (bs-gnus--group-schedule-resize buffer))))))

(defun bs-gnus--group-cancel-timers ()
  "Cancel timers owned by the current Group buffer."
  (when (timerp bs-gnus--group-decoration-timer)
    (cancel-timer bs-gnus--group-decoration-timer))
  (when (timerp bs-gnus--group-resize-timer)
    (cancel-timer bs-gnus--group-resize-timer))
  (setq bs-gnus--group-decoration-timer nil
        bs-gnus--group-resize-timer nil))

(defun bs-gnus--group-configure-buffer ()
  "Configure the current Gnus Group buffer."
  (unless bs-gnus--group-header-line-saved-p
    (setq bs-gnus--group-original-header-line-format header-line-format
          bs-gnus--group-header-line-saved-p t))
  (setq-local header-line-format
              '(:eval (bs-gnus--group-header)))
  (add-hook 'kill-buffer-hook
            #'bs-gnus--group-cancel-timers nil t))

(defun bs-gnus--group-buffers ()
  "Return live Gnus Group buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-group-mode)))
   (buffer-list)))

;;;###autoload
(defun bs-gnus-group-topic-toggle ()
  "Toggle the topic at point without changing its hierarchy."
  (interactive)
  (unless (derived-mode-p 'gnus-group-mode)
    (user-error "This command requires a Gnus Group buffer"))
  (unless (get-text-property
           (line-beginning-position) 'gnus-topic)
    (user-error "No topic at point"))
  (gnus-topic-fold))

(defun bs-gnus--group-install ()
  "Install the custom Gnus Group renderer."
  (unless bs-gnus--group-enabled
    (setq bs-gnus--group-enabled t)
    (add-hook 'gnus-group-mode-hook
              #'bs-gnus--group-configure-buffer)
    (add-hook 'gnus-group-prepare-hook
              #'bs-gnus--group-decorate)
    (add-hook 'gnus-group-update-hook
              #'bs-gnus--group-schedule-decoration)
    (add-hook 'window-size-change-functions
              #'bs-gnus--group-window-size-change)
    (advice-remove 'gnus-topic-fold
                   #'bs-gnus--group-after-topic-change)
    (advice-add 'gnus-topic-fold
                :around #'bs-gnus--group-around-topic-fold)
    (advice-add 'gnus-topic-indent
                :after #'bs-gnus--group-after-topic-change)
    (advice-add 'gnus-topic-unindent
                :after #'bs-gnus--group-after-topic-change)
    (advice-add 'gnus-topic-update-topic-line
                :after #'bs-gnus--group-schedule-decoration)
    (dolist (buffer (bs-gnus--group-buffers))
      (with-current-buffer buffer
        (bs-gnus--group-configure-buffer)
        (bs-gnus--group-decorate))))
  t)

;;;###autoload
(defun bs-gnus-group-disable ()
  "Restore Gnus's native Group renderer.

This is an emergency and debugging command, not a minor mode."
  (interactive)
  (when bs-gnus--group-enabled
    (setq bs-gnus--group-enabled nil)
    (remove-hook 'gnus-group-mode-hook
                 #'bs-gnus--group-configure-buffer)
    (remove-hook 'gnus-group-prepare-hook
                 #'bs-gnus--group-decorate)
    (remove-hook 'gnus-group-update-hook
                 #'bs-gnus--group-schedule-decoration)
    (remove-hook 'window-size-change-functions
                 #'bs-gnus--group-window-size-change)
    (advice-remove 'gnus-topic-fold
                   #'bs-gnus--group-around-topic-fold)
    (advice-remove 'gnus-topic-fold
                   #'bs-gnus--group-after-topic-change)
    (advice-remove 'gnus-topic-indent
                   #'bs-gnus--group-after-topic-change)
    (advice-remove 'gnus-topic-unindent
                   #'bs-gnus--group-after-topic-change)
    (advice-remove 'gnus-topic-update-topic-line
                   #'bs-gnus--group-schedule-decoration)
    (dolist (buffer (bs-gnus--group-buffers))
      (with-current-buffer buffer
        (bs-gnus--group-cancel-timers)
        (bs-gnus--group-remove-decorations)
        (setq-local header-line-format
                    bs-gnus--group-original-header-line-format)
        (setq bs-gnus--group-original-header-line-format nil
              bs-gnus--group-header-line-saved-p nil)
        (gnus-group-list-groups
         (car gnus-group-list-mode)
         (cdr gnus-group-list-mode))))))

;;;###autoload
(defun bs-gnus-group-enable ()
  "Enable the bs-gnus Group renderer."
  (interactive)
  (with-eval-after-load 'gnus-topic
    (bs-gnus--group-install)))

(defun bs-gnus--summary-sanitize-string (string)
  "Return STRING without control characters that break one-line layout."
  (string-trim
   (replace-regexp-in-string
    "[[:cntrl:]\n\r\t]+"
    " "
    (if (stringp string) string ""))))

(defun bs-gnus--summary-truncate (string width)
  "Truncate STRING to WIDTH columns with an ASCII ellipsis."
  (cond
   ((<= width 0) "")
   ((<= (string-width string) width) string)
   (t
    (truncate-string-to-width
     string width 0 nil (and (> width 3) "...")))))

(defun bs-gnus--summary-space (width &optional face)
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
      (put-text-property 0 (length space) 'face face space))
    space))

(defun bs-gnus--summary-window ()
  "Return a window suitable for sizing the current Summary buffer."
  (or (and (eq (window-buffer (selected-window)) (current-buffer))
           (selected-window))
      (get-buffer-window (current-buffer) t)))

(defun bs-gnus--summary-width ()
  "Return the display width for the current Summary buffer."
  (if-let* ((window (bs-gnus--summary-window)))
      (window-body-width window)
    bs-gnus-summary-fallback-width))

(defun bs-gnus--summary-contact-name (address)
  "Return a compact display name for ADDRESS."
  (let* ((parsed
          (and (stringp address)
               (mail-header-parse-address-lax address)))
         (email (if (consp parsed) (car parsed) parsed))
         (name (and (consp parsed) (cdr parsed)))
         (name
          (and (stringp name)
               (string-trim
                (replace-regexp-in-string
                 "[\n\r][ \t]+" " " name)))))
    (when (and name
               (> (length name) 1)
               (string-prefix-p "\"" name)
               (string-suffix-p "\"" name))
      (setq name (string-trim (substring name 1 -1))))
    (bs-gnus--summary-sanitize-string
     (or (and name (not (string-empty-p name)) name)
         (and (stringp email) email)
         address
         "?"))))

(defun bs-gnus--summary-date (header)
  "Return the formatted date from HEADER."
  (let ((date (mail-header-date header)))
    (condition-case nil
        (format-time-string
         bs-gnus-summary-date-format
         (date-to-time date))
      (error
       (bs-gnus--summary-sanitize-string date)))))

(defun bs-gnus--summary-unread-data-p (data)
  "Return non-nil when DATA represents an unread article."
  (= (gnus-data-mark data) gnus-unread-mark))

(defun bs-gnus--summary-context-article-p (article)
  "Return non-nil when ARTICLE exists only as thread context."
  (or (memq article gnus-newsgroup-ancient)
      (memq article gnus-newsgroup-sparse)))

(defun bs-gnus--summary-context-data-p (data)
  "Return non-nil when DATA exists only to connect visible articles."
  (bs-gnus--summary-context-article-p (gnus-data-number data)))

(defun bs-gnus--summary-limit-with-context (articles)
  "Return ARTICLES together with their available context ancestors."
  (if (not (hash-table-p gnus-newsgroup-dependencies))
      articles
    (let ((headers (make-hash-table :test #'eql))
          (ids (make-hash-table :test #'equal))
          (included (make-hash-table :test #'eql))
          pending result)
      (maphash
       (lambda (_id dependencies)
         (when-let* ((header (car dependencies)))
           (let ((number (mail-header-number header))
                 (id (mail-header-id header)))
             (puthash number header headers)
             (when id
               (puthash id number ids)))))
       gnus-newsgroup-dependencies)
      (dolist (article articles)
        (unless (gethash article included)
          (puthash article t included)
          (push article pending)
          (push article result)))
      (while pending
        (when-let* ((header (gethash (pop pending) headers))
                    (references (mail-header-references header)))
          (dolist (id (gnus-split-references references))
            (when-let* ((article (gethash id ids))
                        ((bs-gnus--summary-context-article-p article))
                        ((not (gethash article included))))
              (puthash article t included)
              (push article pending)
              (push article result)))))
      (sort result #'<))))

(defun bs-gnus--summary-limit-advice (function articles &optional pop)
  "Keep thread context when FUNCTION applies an article limit.
ARTICLES and POP have the meaning documented by `gnus-summary-limit'."
  (when (and bs-gnus--summary-enabled
             (derived-mode-p 'gnus-summary-mode))
    (if pop
        (when gnus-newsgroup-limits
          (setcar
           gnus-newsgroup-limits
           (bs-gnus--summary-limit-with-context
            (car gnus-newsgroup-limits))))
      (setq articles
            (bs-gnus--summary-limit-with-context articles))))
  (funcall function articles pop))

(defun bs-gnus--summary-thread-subtree-path (thread target)
  "Return the headers leading from THREAD to TARGET.
The return value begins with a non-nil sentinel, followed by the
headers preceding TARGET.  Return nil when TARGET is not a subtree
of THREAD."
  (cond
   ((eq thread target)
    (list t))
   ((consp thread)
    (cl-loop
     for child in (cdr thread)
     for path = (bs-gnus--summary-thread-subtree-path child target)
     when path
     return (cons t (cons (car thread) (cdr path)))))))

(defun bs-gnus--summary-cut-threads-advice (function threads)
  "Call FUNCTION on THREADS and remember omitted context roots."
  (if (and bs-gnus--summary-enabled
           (derived-mode-p 'gnus-summary-mode))
      (let* ((originals (copy-sequence threads))
             (cut-threads (funcall function threads)))
        (setq bs-gnus--summary-context-prefixes
              (make-hash-table :test #'eql))
        (dolist (thread cut-threads)
          (when (mail-header-p (car-safe thread))
            (when-let*
                ((path
                  (cl-loop
                   for original in originals
                   for candidate =
                   (bs-gnus--summary-thread-subtree-path
                    original thread)
                   when candidate return candidate))
                 (headers
                  (cl-remove-if-not #'mail-header-p (cdr path))))
              (puthash
               (mail-header-number (car thread))
               headers
               bs-gnus--summary-context-prefixes))))
        cut-threads)
    (funcall function threads)))

(defun bs-gnus--summary-important-data-p (data)
  "Return non-nil when DATA should remain visible in a folded thread."
  (let ((number (gnus-data-number data))
        (mark (gnus-data-mark data)))
    (or (= mark gnus-unread-mark)
        (= mark gnus-ticked-mark)
        (= mark gnus-dormant-mark)
        (memq number gnus-newsgroup-processable))))

(defun bs-gnus--summary-threads ()
  "Return `gnus-newsgroup-data' split into top-level threads."
  (let (current threads)
    (dolist (data gnus-newsgroup-data)
      (when (and current (zerop (gnus-data-level data)))
        (push (nreverse current) threads)
        (setq current nil))
      (push data current))
    (when current
      (push (nreverse current) threads))
    (nreverse threads)))

(defun bs-gnus--summary-thread-unread-count (thread)
  "Return the number of unread articles in THREAD."
  (cl-count-if
   (lambda (data)
     (and (not (bs-gnus--summary-context-data-p data))
          (bs-gnus--summary-unread-data-p data)))
   thread))

(defun bs-gnus--summary-thread-count-label (thread &optional face)
  "Return the article-count label for THREAD."
  (let* ((context
          (cl-count-if #'bs-gnus--summary-context-data-p thread))
         (omitted
          (length
           (and (hash-table-p bs-gnus--summary-context-prefixes)
                (gethash
                 (gnus-data-number (car thread))
                 bs-gnus--summary-context-prefixes))))
         (total (- (length thread) context))
         (unread (bs-gnus--summary-thread-unread-count thread))
         (label
          (if (> unread 0)
              (format "%d/%d" unread total)
            (number-to-string total)))
         (label
          (concat label (and (> (+ context omitted) 0) "+"))))
    (if face
        (propertize label 'face face)
      label)))

(defun bs-gnus--summary-thread-count-width (threads)
  "Return the widest article-count label in THREADS."
  (max
   bs-gnus-summary-thread-count-digits
   (cl-loop for thread in threads
            maximize
            (string-width
             (bs-gnus--summary-thread-count-label thread))
            into width
            finally return (or width 0))))

(defun bs-gnus--summary-thread-title (thread width count-width)
  "Return a title for THREAD fitted to WIDTH.

Right-align its article count to COUNT-WIDTH columns."
  (let* ((header (gnus-data-header (car thread)))
         (unread (bs-gnus--summary-thread-unread-count thread))
         (padding-width
          (max 0.0
               (min 0.5 bs-gnus-summary-thread-count-padding)))
         (count-face
          (if (> unread 0)
              'bs-gnus-summary-unread-thread-count-face
            'bs-gnus-summary-thread-count-face))
         (label
          (bs-gnus--summary-thread-count-label thread count-face))
         (count
          (concat
           (make-string
            (max 0 (- count-width (string-width label)))
            ?\s)
           (bs-gnus--summary-space padding-width count-face)
           label
           (bs-gnus--summary-space padding-width count-face)))
         (reserved (+ count-width (* 2 padding-width) 1))
         (subject
          (bs-gnus--summary-truncate
           (bs-gnus--summary-sanitize-string
            (mail-header-subject header))
           (max 0 (floor (- width reserved)))))
         (line (concat count " " subject)))
    (font-lock-append-text-property
     0 (length line)
     'font-lock-face 'bs-gnus-summary-title-face line)
    line))

(defun bs-gnus--summary-header ()
  "Return the Summary identity with right-aligned statistics."
  (if (not gnus-newsgroup-name)
      ""
    (let* ((width (bs-gnus--summary-width))
           (loaded (length gnus-newsgroup-data))
           (total (bs-gnus--group-total gnus-newsgroup-name))
           (unread
            (cl-count-if
             #'bs-gnus--summary-unread-data-p
             gnus-newsgroup-data))
           (unread-string (number-to-string unread))
           (statistics
            (concat
             (propertize
              unread-string
              'face
              (if (> unread 0)
                  'bs-gnus-summary-group-unread-face
                'bs-gnus-summary-group-empty-unread-face))
             " unread · "
             (propertize
              (number-to-string loaded)
              'face 'bs-gnus-summary-group-loaded-face)
             " loaded · "
             (number-to-string total)
             " total"))
           (identity
            (concat
             (propertize
              "GROUP " 'face 'bs-gnus-header-label-face)
             (propertize
              (bs-gnus--group-display-name gnus-newsgroup-name)
              'face 'bs-gnus-summary-group-name-face)
             (propertize
              (format
               " (%s)"
               (bs-gnus--group-source gnus-newsgroup-name))
              'face 'bs-gnus-summary-group-face)))
           (identity
            (bs-gnus--summary-truncate
             identity
             (max 0 (- width (string-width statistics) 2))))
           (header
            (concat
             identity
             (bs-gnus--header-right-padding statistics)
             statistics)))
      (add-face-text-property
       0 (length header) 'bs-gnus-header-face t header)
      header)))

(defun bs-gnus--summary-decoration-line (string article kind)
  "Return a decoration line containing STRING for ARTICLE and KIND."
  (propertize
   (concat string "\n")
   'bs-gnus-decoration kind
   'gnus-intangible article
   'rear-nonsticky t))

(defun bs-gnus--summary-context-line (header width)
  "Return an unselectable context line for HEADER fitted to WIDTH."
  (let* ((prefix
          (concat
           (make-string bs-gnus--summary-prefix-width ?\s)
           "… "))
         (date (bs-gnus--summary-date header))
         (name
          (bs-gnus--summary-contact-name
           (mail-header-from header)))
         (available
          (max
           0
           (- width
              (string-width prefix)
              (string-width date)
              1)))
         (name (bs-gnus--summary-truncate name available))
         (padding
          (make-string
           (max 1 (- available (string-width name)))
           ?\s)))
    (propertize
     (concat prefix name padding date)
     'face 'bs-gnus-summary-context-face)))

(defun bs-gnus--summary-thread-context-lines (thread width)
  "Return omitted context lines for THREAD fitted to WIDTH."
  (when (hash-table-p bs-gnus--summary-context-prefixes)
    (when-let*
        ((headers
          (gethash
           (gnus-data-number (car thread))
           bs-gnus--summary-context-prefixes)))
      (mapconcat
       (lambda (header)
         (bs-gnus--summary-context-line header width))
       headers "\n"))))

(defun bs-gnus--summary-remove-fold-overlays ()
  "Remove fold overlays owned by the custom Summary renderer."
  (remove-overlays
   (point-min) (point-max) 'bs-gnus-fold-overlay t))

(defun bs-gnus--summary-remove-context-overlays ()
  "Remove context overlays owned by the custom Summary renderer."
  (remove-overlays
   (point-min) (point-max) 'bs-gnus-context-overlay t))

(defun bs-gnus--summary-remove-mark-alignment ()
  "Remove display spacing used to align Summary mark columns."
  (let ((limit (point-max))
        (position (point-min)))
    (while (setq position
                 (text-property-any
                  position limit 'bs-gnus-mark-alignment t))
      (let ((end
             (next-single-property-change
              position 'bs-gnus-mark-alignment nil limit)))
        (remove-text-properties
         position end
         '(bs-gnus-mark-alignment nil display nil))
        (setq position end)))))

(defun bs-gnus--summary-align-mark-columns ()
  "Right-align article marks with thread count labels."
  (bs-gnus--summary-remove-mark-alignment)
  (dolist (data gnus-newsgroup-data)
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((start (line-beginning-position))
            (end (line-end-position)))
        (when (and (< (+ start 8) end)
                   (eq (char-after (+ start 3)) ?\s)
                   (eq (char-after (+ start 8)) ?\s))
          (add-text-properties
           (+ start 3) (+ start 4)
           '(bs-gnus-mark-alignment t
                                    display (space :width 1.5)))
          (add-text-properties
           (+ start 8) (+ start 9)
           '(bs-gnus-mark-alignment t
                                    display (space :width 0.5))))))))

(defun bs-gnus--summary-remove-decorations ()
  "Remove custom title and separator lines from the current buffer."
  (bs-gnus--summary-remove-fold-overlays)
  (bs-gnus--summary-remove-context-overlays)
  (bs-gnus--summary-remove-mark-alignment)
  (let ((inhibit-read-only t))
    (goto-char (point-min))
    (while (not (eobp))
      (if (get-text-property (point) 'bs-gnus-decoration)
          (delete-region
           (line-beginning-position)
           (line-beginning-position 2))
        (forward-line 1)))))

(defun bs-gnus--summary-thread-for-article (article)
  "Return the thread containing ARTICLE."
  (cl-find-if
   (lambda (thread)
     (cl-find article thread :key #'gnus-data-number))
   (bs-gnus--summary-threads)))

(defun bs-gnus--summary-descendants (article thread)
  "Return descendants of ARTICLE within THREAD."
  (when-let* ((tail
               (cl-member article thread :key #'gnus-data-number)))
    (let ((level (gnus-data-level (car tail))))
      (cl-loop for data in (cdr tail)
               while (> (gnus-data-level data) level)
               collect data))))

(defun bs-gnus--summary-add-fold-indicator (article thread)
  "Display a fold indicator on ARTICLE within THREAD."
  (when-let* ((data
               (cl-find article thread :key #'gnus-data-number)))
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((position (line-beginning-position)))
        (when (eq (char-after position) ?\s)
          (let ((overlay
                 (make-overlay position (1+ position) nil t nil)))
            (overlay-put
             overlay 'display
             (propertize
              (char-to-string bs-gnus-summary-fold-indicator)
              'face 'bs-gnus-summary-fold-indicator-face))
            (overlay-put overlay 'evaporate t)
            (overlay-put overlay 'bs-gnus-fold-overlay t)
            (overlay-put overlay 'bs-gnus-fold-indicator t)
            (overlay-put overlay 'bs-gnus-fold-anchor article)))))))

(defun bs-gnus--summary-apply-fold (article thread)
  "Hide unimportant descendants of ARTICLE within THREAD."
  (bs-gnus--summary-add-fold-indicator article thread)
  (dolist (data (bs-gnus--summary-descendants article thread))
    (unless (bs-gnus--summary-important-data-p data)
      (save-excursion
        (goto-char (gnus-data-pos data))
        (let ((overlay
               (make-overlay
                (line-beginning-position)
                (line-beginning-position 2)
                nil t nil)))
          (overlay-put overlay 'invisible 'bs-gnus-fold)
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'bs-gnus-fold-overlay t)
          (overlay-put overlay 'bs-gnus-fold-anchor article))))))

(defun bs-gnus--summary-apply-folds (threads)
  "Apply saved folds to THREADS."
  (bs-gnus--summary-remove-fold-overlays)
  (dolist (thread threads)
    (dolist (data thread)
      (let ((article (gnus-data-number data)))
        (when (gethash article bs-gnus--summary-fold-state)
          (bs-gnus--summary-apply-fold article thread))))))

(defun bs-gnus--summary-apply-context-faces ()
  "Visually weaken articles displayed only as thread context."
  (bs-gnus--summary-remove-context-overlays)
  (dolist (data gnus-newsgroup-data)
    (when (bs-gnus--summary-context-data-p data)
      (save-excursion
        (goto-char (gnus-data-pos data))
        (let ((overlay
               (make-overlay
                (line-beginning-position)
                (line-end-position)
                nil t nil)))
          (overlay-put overlay 'face 'bs-gnus-summary-context-face)
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'bs-gnus-context-overlay t))))))

(defun bs-gnus--summary-refresh-hl-line ()
  "Move the current Summary buffer's Hl-Line overlay to point."
  (when (bound-and-true-p hl-line-mode)
    (if (overlayp hl-line-overlay)
        (hl-line-move hl-line-overlay)
      (when-let* ((window
                   (get-buffer-window (current-buffer) t)))
        (with-selected-window window
          (hl-line-highlight))))))

(defun bs-gnus--summary-restore-selection (article)
  "Restore point to ARTICLE when it remains available."
  (when (and article
             (gnus-summary-goto-subject article nil t))
    (bs-gnus--summary-position-point)
    (let ((position (point)))
      (dolist (window (get-buffer-window-list (current-buffer) nil t))
        (set-window-point window position))))
  (when gnus-current-article
    (save-excursion
      (when (gnus-summary-goto-subject
             gnus-current-article nil t)
        (gnus-highlight-selected-summary))))
  (bs-gnus--summary-refresh-hl-line))

(defun bs-gnus--summary-selection-article ()
  "Return the Summary article whose point should survive a render."
  (let ((point-article
         (get-text-property (point) 'gnus-number)))
    (if (eq (window-buffer (selected-window)) (current-buffer))
        (or point-article gnus-current-article)
      (or gnus-current-article point-article))))

(defun bs-gnus--summary-add-header-spacing ()
  "Add spacing between the Summary header and its first row."
  (when (< (point-min) (point-max))
    (add-text-properties
     (point-min) (1+ (point-min))
     `(bs-gnus-header-bottom-spacing t
                                     line-prefix
                                     ,(bs-gnus--top-spacing-prefix
                                       bs-gnus-header-bottom-spacing)))))

(defun bs-gnus--summary-decorate ()
  "Decorate the current native Gnus Summary buffer."
  (when (and bs-gnus--summary-enabled
             bs-gnus--summary-original-settings
             (derived-mode-p 'gnus-summary-mode))
    (let ((article (bs-gnus--summary-selection-article))
          (threads (bs-gnus--summary-threads))
          (width (bs-gnus--summary-width))
          (inhibit-read-only t))
      (setq bs-gnus--summary-rendered nil)
      (save-excursion
        (bs-gnus--summary-remove-decorations)
        (bs-gnus--summary-apply-correspondent-faces)
        (gnus-data-compute-positions)
        (bs-gnus--summary-align-mark-columns)
        (let ((count-width
               (bs-gnus--summary-thread-count-width threads)))
          (dolist (thread (reverse threads))
            (let ((root (car thread))
                  (last (car (last thread))))
              (goto-char (gnus-data-pos last))
              (forward-line 1)
              (unless (eobp)
                (insert
                 (bs-gnus--summary-decoration-line
                  "" (gnus-data-number root) 'separator)))
              (goto-char (gnus-data-pos root))
              (beginning-of-line)
              (insert
               (bs-gnus--summary-decoration-line
                (bs-gnus--summary-thread-title
                 thread width count-width)
                (gnus-data-number root)
                'thread-title))
              (when-let*
                  ((context
                    (bs-gnus--summary-thread-context-lines
                     thread width)))
                (insert
                 (bs-gnus--summary-decoration-line
                  context
                  (gnus-data-number root)
                  'thread-context))))))
        (bs-gnus--summary-add-header-spacing)
        (gnus-data-compute-positions)
        (bs-gnus--summary-apply-context-faces)
        (bs-gnus--summary-apply-folds threads))
      (setq bs-gnus--summary-render-width width
            bs-gnus--summary-rendered t
            header-line-format '(:eval (bs-gnus--summary-header)))
      (bs-gnus--summary-restore-selection article)
      (force-mode-line-update))))

(defun bs-gnus--summary-reset-render-state ()
  "Reset transient render state before Gnus builds a Summary."
  (setq bs-gnus--summary-rendered nil)
  (bs-gnus--summary-remove-fold-overlays)
  (bs-gnus--summary-remove-context-overlays))

(defun bs-gnus--summary-run-decoration (buffer)
  "Decorate Summary BUFFER after a debounced update."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-gnus--summary-decoration-timer nil)
      (when bs-gnus--summary-rendered
        (bs-gnus--summary-decorate)))))

(defun bs-gnus--summary-schedule-decoration ()
  "Schedule decoration after a native Summary line update."
  (when bs-gnus--summary-rendered
    (when (timerp bs-gnus--summary-decoration-timer)
      (cancel-timer bs-gnus--summary-decoration-timer))
    (setq bs-gnus--summary-decoration-timer
          (run-with-idle-timer
           0.05 nil
           #'bs-gnus--summary-run-decoration
           (current-buffer)))))

(defun bs-gnus--summary-rerender (buffer)
  "Rerender visible Summary BUFFER after a debounced resize."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq bs-gnus--summary-resize-timer nil)
      (when (and bs-gnus--summary-original-settings
                 gnus-newsgroup-prepared
                 (get-buffer-window buffer t))
        (let ((width (bs-gnus--summary-width))
              (article (bs-gnus--summary-selection-article)))
          (unless (equal width bs-gnus--summary-render-width)
            (gnus-summary-prepare)
            (bs-gnus--summary-restore-selection article)))))))

(defun bs-gnus--summary-schedule-resize (buffer)
  "Schedule a debounced resize render for Summary BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (timerp bs-gnus--summary-resize-timer)
        (cancel-timer bs-gnus--summary-resize-timer))
      (setq bs-gnus--summary-resize-timer
            (run-with-idle-timer
             0.2 nil #'bs-gnus--summary-rerender buffer)))))

(defun bs-gnus--summary-window-size-change (frame)
  "Schedule rerenders for visible Summary buffers on FRAME."
  (let ((seen (make-hash-table :test #'eq)))
    (dolist (window (window-list frame 'no-minibuffer))
      (let ((buffer (window-buffer window)))
        (when (and (not (gethash buffer seen))
                   (buffer-live-p buffer)
                   (with-current-buffer buffer
                     (and (derived-mode-p 'gnus-summary-mode)
                          bs-gnus--summary-original-settings)))
          (puthash buffer t seen)
          (bs-gnus--summary-schedule-resize buffer))))))

(defun bs-gnus--summary-cancel-timers ()
  "Cancel timers owned by the current Summary buffer."
  (when (timerp bs-gnus--summary-decoration-timer)
    (cancel-timer bs-gnus--summary-decoration-timer))
  (when (timerp bs-gnus--summary-resize-timer)
    (cancel-timer bs-gnus--summary-resize-timer))
  (setq bs-gnus--summary-decoration-timer nil
        bs-gnus--summary-resize-timer nil))

(defun bs-gnus--summary-apply-correspondent-faces ()
  "Restore correspondent faces after Gnus applies article-line faces."
  (let ((position (point-min)))
    (while (setq position
                 (text-property-not-all
                  position (point-max)
                  'bs-gnus-correspondent-face nil))
      (let* ((article
              (get-text-property position 'gnus-number))
             (data (and article (gnus-data-find article)))
             (face
              (if data
                  (if (= (gnus-data-mark data) gnus-unread-mark)
                      'bs-gnus-summary-unread-correspondent-face
                    'bs-gnus-summary-correspondent-face)
                (get-text-property
                 position 'bs-gnus-correspondent-face)))
             (end
              (next-single-property-change
               position 'bs-gnus-correspondent-face
               nil (point-max)))
             (current (get-text-property position 'face))
             (faces
              (cond
               ((null current) nil)
               ((and (listp current)
                     (not (keywordp (car current))))
                current)
               (t (list current))))
             (faces
              (cl-remove-if
               (lambda (candidate)
                 (memq candidate
                       '(bs-gnus-summary-correspondent-face
                         bs-gnus-summary-unread-correspondent-face)))
               faces)))
        (put-text-property
         position end 'bs-gnus-correspondent-face face)
        (put-text-property position end 'face (cons face faces))
        (setq position end)))))

(defun bs-gnus-summary-format-message (header)
  "Return the responsive correspondent and date fields for HEADER."
  (let* ((prefix
          (if (stringp gnus-tmp-thread-tree-header-string)
              gnus-tmp-thread-tree-header-string
            ""))
         (date (bs-gnus--summary-date header))
         (name (bs-gnus--summary-contact-name
                (mail-header-from header)))
         (available
          (max
           0
           (- (bs-gnus--summary-width)
              bs-gnus--summary-prefix-width
              (string-width prefix)
              (string-width date)
              1)))
         (name (bs-gnus--summary-truncate name available))
         (padding
          (make-string
           (max
            1
            (- available (string-width name)))
           ?\s))
         (name
          (propertize
           name 'bs-gnus-correspondent-face
           (if (= gnus-tmp-unread gnus-unread-mark)
               'bs-gnus-summary-unread-correspondent-face
             'bs-gnus-summary-correspondent-face)))
         (date
          (propertize date 'face 'bs-gnus-summary-timestamp-face)))
    (concat prefix name padding date)))

(defun bs-gnus--summary-update-format ()
  "Recompile the current Summary format and mark positions."
  (gnus-update-format-specifications
   t 'summary 'summary-mode 'summary-dummy)
  (gnus-update-summary-mark-positions))

(defun bs-gnus--summary-save-settings ()
  "Save settings replaced in the current Summary buffer."
  (unless bs-gnus--summary-original-settings
    (setq bs-gnus--summary-original-settings
          (mapcar
           (lambda (symbol)
             (cons symbol (symbol-value symbol)))
           bs-gnus--summary-setting-symbols))))

(defun bs-gnus--summary-configure-buffer ()
  "Configure the current Gnus Summary buffer."
  (bs-gnus--summary-save-settings)
  (unless (hash-table-p bs-gnus--summary-fold-state)
    (setq bs-gnus--summary-fold-state
          (make-hash-table :test #'eql)))
  (setq-local gnus-summary-line-format bs-gnus--summary-line-format)
  (setq-local header-line-format
              '(:eval (bs-gnus--summary-header)))
  (add-to-invisibility-spec 'bs-gnus-fold)
  (add-hook 'kill-buffer-hook
            #'bs-gnus--summary-cancel-timers nil t))

(defun bs-gnus--summary-restore-buffer ()
  "Restore settings replaced in the current Summary buffer."
  (when bs-gnus--summary-original-settings
    (bs-gnus--summary-cancel-timers)
    (let ((prepared gnus-newsgroup-prepared))
      (setq bs-gnus--summary-rendered nil)
      (bs-gnus--summary-remove-decorations)
      (dolist (setting bs-gnus--summary-original-settings)
        (set (make-local-variable (car setting)) (cdr setting)))
      (remove-from-invisibility-spec 'bs-gnus-fold)
      (setq bs-gnus--summary-original-settings nil
            bs-gnus--summary-fold-state nil
            bs-gnus--summary-render-width nil)
      (bs-gnus--summary-update-format)
      (when prepared
        (gnus-summary-prepare)))))

(defun bs-gnus--summary-article-buffer-p ()
  "Return non-nil when the current buffer is a Gnus Summary buffer."
  (derived-mode-p 'gnus-summary-mode))

(defun bs-gnus--summary-position-point ()
  "Position point at the start of custom Summary row contents."
  (beginning-of-line)
  (move-to-column bs-gnus--summary-prefix-width))

(defun bs-gnus--article-read-summary-keys-advice
    (function &rest arguments)
  "Call FUNCTION with ARGUMENTS as an Article-originated command."
  (let ((bs-gnus--summary-navigation-from-article t))
    (apply function arguments)))

(defun bs-gnus--summary-sync-article-navigation ()
  "Start Article-originated navigation at the displayed article."
  (when (and bs-gnus--summary-navigation-from-article
             gnus-current-article
             (gnus-summary-goto-subject
              gnus-current-article nil t))
    (bs-gnus--summary-position-point)))

(defun bs-gnus--summary-find-visible-article (direction)
  "Move to the next visible real article in DIRECTION.
DIRECTION is 1 for following lines and -1 for preceding lines.
Return the article number, or nil at the buffer boundary."
  (let (article)
    (while (and (not article)
                (zerop (forward-line direction)))
      (let ((number
             (get-text-property
              (line-beginning-position) 'gnus-number)))
        (when (and (integerp number)
                   (> number 0)
                   (not (invisible-p (line-beginning-position))))
          (setq article number))))
    (when article
      (bs-gnus--summary-position-point))
    article))

(defun bs-gnus--summary-extend-at-boundary (direction)
  "Extend the Summary at its boundary in DIRECTION."
  (when gnus-auto-extend-newsgroup
    (if (> direction 0)
        (and (> bs-gnus-summary-auto-extend-count 0)
             (bs-gnus--summary-extend-old-articles))
      (bs-gnus--summary-extend-new-articles))))

(defun bs-gnus--summary-follow-point ()
  "Display the article at point when its Article buffer is visible."
  (when (and bs-gnus-summary-follow-visible-article
             (not bs-gnus--summary-navigation-from-article)
             gnus-article-buffer
             (get-buffer-window gnus-article-buffer t))
    (gnus-summary-select-article)))

(defun bs-gnus--summary-move-visible-articles (count direction)
  "Move COUNT visible articles in DIRECTION.
Return the number of requested steps that could not be completed."
  (let* ((direction
          (* direction (if (< count 0) -1 1)))
         (remaining (abs count))
         (moved 0))
    (while
        (and
         (> remaining 0)
         (or
          (bs-gnus--summary-find-visible-article direction)
          (let (article)
            (while (and (not article)
                        (bs-gnus--summary-extend-at-boundary
                         direction))
              (setq article
                    (bs-gnus--summary-find-visible-article
                     direction)))
            article)))
      (setq remaining (1- remaining)))
    (setq moved (- (abs count) remaining))
    (when (> moved 0)
      (gnus-summary-recenter)
      (bs-gnus--summary-position-point)
      (bs-gnus--summary-follow-point)
      (bs-gnus--summary-refresh-hl-line))
    (when (> remaining 0)
      (gnus-message 7 "No more articles"))
    remaining))

(defun bs-gnus--summary-extend-old-articles ()
  "Insert a batch of older articles and preserve the current article.
Return non-nil when the Summary gained at least one article."
  (let ((article (gnus-summary-article-number))
        (count (length gnus-newsgroup-data)))
    (gnus-summary-insert-old-articles
     bs-gnus-summary-auto-extend-count)
    (when article
      (gnus-summary-goto-subject article nil t))
    (> (length gnus-newsgroup-data) count)))

(defun bs-gnus--summary-extend-new-articles ()
  "Insert newly available articles and preserve the current article.
Return non-nil when the Summary gained at least one article."
  (let ((article (gnus-summary-article-number))
        (count (length gnus-newsgroup-data)))
    (gnus-summary-insert-new-articles)
    (when article
      (gnus-summary-goto-subject article nil t))
    (> (length gnus-newsgroup-data) count)))

;;;###autoload
(defun bs-gnus-summary-next (&optional count)
  "Move to the COUNTth next concrete Summary article."
  (interactive "p")
  (unless (bs-gnus--summary-article-buffer-p)
    (user-error "This command requires a Gnus Summary buffer"))
  (bs-gnus--summary-sync-article-navigation)
  (bs-gnus--summary-move-visible-articles (or count 1) 1))

;;;###autoload
(defun bs-gnus-summary-previous (&optional count)
  "Move to the COUNTth previous concrete Summary article."
  (interactive "p")
  (unless (bs-gnus--summary-article-buffer-p)
    (user-error "This command requires a Gnus Summary buffer"))
  (bs-gnus--summary-sync-article-navigation)
  (bs-gnus--summary-move-visible-articles (or count 1) -1))

;;;###autoload
(defun bs-gnus-summary-fold-toggle ()
  "Toggle folding of replies to the article at point."
  (interactive)
  (unless (and (bs-gnus--summary-article-buffer-p)
               bs-gnus--summary-rendered)
    (user-error "The custom Gnus Summary renderer is not active"))
  (let* ((article (gnus-summary-article-number))
         (thread (bs-gnus--summary-thread-for-article article))
         (descendants
          (and thread
               (bs-gnus--summary-descendants article thread))))
    (unless thread
      (user-error "No article thread at point"))
    (unless descendants
      (user-error "The current article has no replies"))
    (if (gethash article bs-gnus--summary-fold-state)
        (progn
          (remhash article bs-gnus--summary-fold-state)
          (remove-overlays
           (point-min) (point-max)
           'bs-gnus-fold-anchor article))
      (puthash article t bs-gnus--summary-fold-state)
      (bs-gnus--summary-apply-fold article thread))
    (bs-gnus--summary-restore-selection article)))

(defun bs-gnus--summary-agent-article-available-p (group article)
  "Return non-nil when ARTICLE from GROUP is stored in the Agent."
  (with-temp-buffer
    (let ((gnus-agent-cache t))
      (gnus-agent-request-article article group))))

(defun bs-gnus--summary-download-articles (group articles)
  "Ensure that GROUP ARTICLES are stored in the Gnus Agent."
  (require 'gnus-agent)
  (unless gnus-agent
    (user-error "Gnus Agent is not enabled"))
  (let* ((articles (sort (copy-sequence articles) #'<))
         (missing
          (cl-remove-if
           (lambda (article)
             (bs-gnus--summary-agent-article-available-p
              group article))
           articles))
         fetch-error)
    (when missing
      (let ((method (gnus-find-method-for-group group)))
        (unless (gnus-agent-method-p method)
          (user-error "The current Gnus method is not agentized"))
        (condition-case error-data
            (let ((gnus-command-method method))
              (gnus-agent-fetch-articles
               group (copy-sequence missing)))
          (error
           (setq fetch-error (error-message-string error-data))))))
    (let ((failed
           (cl-remove-if
            (lambda (article)
              (bs-gnus--summary-agent-article-available-p
               group article))
            articles)))
      (when failed
        (user-error
         "Failed to download Gnus articles %s%s"
         (mapconcat #'number-to-string failed ", ")
         (if fetch-error (format ": %s" fetch-error) ""))))
    (setq gnus-newsgroup-undownloaded
          (gnus-sorted-ndifference
           gnus-newsgroup-undownloaded articles))
    (save-excursion
      (dolist (article articles)
        (when (gnus-summary-goto-subject article nil t)
          (gnus-summary-update-download-mark article))))))

(defun bs-gnus--summary-render-agent-article
    (summary-buffer group article)
  "Render ARTICLE from GROUP using SUMMARY-BUFFER settings."
  (require 'gnus-art)
  (with-temp-buffer
    (let ((gnus-agent-cache t)
          (gnus-article-buffer (current-buffer))
          (gnus-summary-buffer summary-buffer)
          (gnus-tmp-internal-hook
           gnus-article-internal-prepare-hook))
      (unless (gnus-agent-request-article article group)
        (error "Gnus article %d is absent from the Agent" article))
      (gnus-article-prepare-display)
      (bs--decode-raw-utf-8
       (string-trim-right
        (buffer-substring-no-properties
         (point-min) (point-max)))))))

(defun bs-gnus--summary-build-thread-context
    (summary-buffer group articles)
  "Build a thread context for GROUP ARTICLES from SUMMARY-BUFFER."
  (let ((texts
         (mapcar
          (lambda (article)
            (bs-gnus--summary-render-agent-article
             summary-buffer group article))
          articles))
        (count (length articles)))
    (with-current-buffer
        (get-buffer-create bs-gnus-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert "# Thread Context\n\n"
              (format "Source: Gnus group `%s`\n\n" group)
              (format "Articles: %d\n" count))
      (cl-loop for text in texts
               for index from 1
               do (insert (format "\n## Article %d of %d\n\n"
                                  index count)
                          text "\n"))
      (set-buffer-modified-p nil)
      (current-buffer))))

;;;###autoload
(defun bs-gnus-summary-mark-subthread ()
  "Prepare the article at point and its replies as thread context.
Download every article to the Gnus Agent before replacing
the buffer named by `bs-gnus-context-buffer-name'.  Keep that
buffer hidden by default, select the current Summary row, and run
`bs-gnus-summary-thread-context-hook'."
  (interactive)
  (unless (derived-mode-p 'gnus-summary-mode)
    (user-error "This command requires a Gnus Summary buffer"))
  (let* ((summary-buffer (current-buffer))
         (article (gnus-summary-article-number))
         (thread
          (and article
               (bs-gnus--summary-thread-for-article article)))
         (anchor
          (and thread
               (cl-find article thread :key #'gnus-data-number)))
         (subthread
          (and anchor
               (cons anchor
                     (bs-gnus--summary-descendants
                      article thread))))
         (articles
          (mapcar #'gnus-data-number subthread))
         (group gnus-newsgroup-name))
    (unless anchor
      (user-error "No Gnus article thread at point"))
    (unless (cl-every
             (lambda (number)
               (and (integerp number) (> number 0)))
             articles)
      (user-error
       "The subthread contains unavailable sparse articles"))
    (bs-gnus--summary-download-articles group articles)
    (let ((context
           (bs-gnus--summary-build-thread-context
            summary-buffer group articles)))
      (gnus-summary-goto-subject article nil t)
      (run-hooks 'bs-gnus-summary-thread-context-hook)
      (if bs-gnus-summary-display-thread-context
          (progn
            (pop-to-buffer context)
            (goto-char (point-min))
            (push-mark (point-max) nil t))
        (goto-char (line-beginning-position))
        (push-mark (line-end-position) nil t)
        (message "Prepared %d Gnus articles in %s"
                 (length articles)
                 bs-gnus-context-buffer-name)))))

(defun bs-gnus--summary-buffers ()
  "Return live Gnus Summary buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-summary-mode)))
   (buffer-list)))

(defun bs-gnus--summary-install ()
  "Install the custom Gnus Summary renderer."
  (unless bs-gnus--summary-enabled
    (setq bs-gnus--summary-enabled t
          bs-gnus--summary-original-user-format-function
          (if (fboundp 'gnus-user-format-function-b)
              (symbol-function 'gnus-user-format-function-b)
            :unbound))
    (fset 'gnus-user-format-function-b
          #'bs-gnus-summary-format-message)
    (advice-add
     'gnus-cut-threads
     :around #'bs-gnus--summary-cut-threads-advice)
    (advice-add
     'gnus-summary-limit
     :around #'bs-gnus--summary-limit-advice)
    (advice-add
     'gnus-article-read-summary-keys
     :around #'bs-gnus--article-read-summary-keys-advice)
    (add-hook 'gnus-summary-mode-hook
              #'bs-gnus--summary-configure-buffer)
    (add-hook 'gnus-summary-generate-hook
              #'bs-gnus--summary-reset-render-state)
    (add-hook 'gnus-summary-prepare-hook
              #'bs-gnus--summary-decorate)
    (add-hook 'gnus-summary-update-hook
              #'bs-gnus--summary-schedule-decoration)
    (add-hook 'window-size-change-functions
              #'bs-gnus--summary-window-size-change)
    (dolist (buffer (bs-gnus--summary-buffers))
      (with-current-buffer buffer
        (bs-gnus--summary-configure-buffer)
        (bs-gnus--summary-update-format)
        (when gnus-newsgroup-prepared
          (gnus-summary-prepare)))))
  t)

;;;###autoload
(defun bs-gnus-summary-disable ()
  "Restore Gnus's native Summary renderer.

This is an emergency and debugging command, not a minor mode."
  (interactive)
  (when bs-gnus--summary-enabled
    (setq bs-gnus--summary-enabled nil)
    (remove-hook 'gnus-summary-mode-hook
                 #'bs-gnus--summary-configure-buffer)
    (remove-hook 'gnus-summary-generate-hook
                 #'bs-gnus--summary-reset-render-state)
    (remove-hook 'gnus-summary-prepare-hook
                 #'bs-gnus--summary-decorate)
    (remove-hook 'gnus-summary-update-hook
                 #'bs-gnus--summary-schedule-decoration)
    (remove-hook 'window-size-change-functions
                 #'bs-gnus--summary-window-size-change)
    (advice-remove
     'gnus-cut-threads
     #'bs-gnus--summary-cut-threads-advice)
    (advice-remove
     'gnus-summary-limit
     #'bs-gnus--summary-limit-advice)
    (advice-remove
     'gnus-article-read-summary-keys
     #'bs-gnus--article-read-summary-keys-advice)
    (if (eq bs-gnus--summary-original-user-format-function :unbound)
        (fmakunbound 'gnus-user-format-function-b)
      (fset 'gnus-user-format-function-b
            bs-gnus--summary-original-user-format-function))
    (setq bs-gnus--summary-original-user-format-function nil)
    (dolist (buffer (bs-gnus--summary-buffers))
      (with-current-buffer buffer
        (bs-gnus--summary-restore-buffer)))))

;;;###autoload
(defun bs-gnus-summary-enable ()
  "Enable the bs-gnus multi-line Summary renderer."
  (interactive)
  (with-eval-after-load 'gnus-sum
    (bs-gnus--summary-install)))

(provide 'bs-gnus)
;;; bs-gnus.el ends here
