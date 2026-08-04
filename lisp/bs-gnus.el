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
(require 'bs-notifications)
(require 'gnus)
(require 'mail-parse)
(require 'seq)
(require 'subr-x)

(declare-function mail-header-date "nnheader" (header))
(declare-function mail-header-from "nnheader" (header))
(declare-function mail-header-id "nnheader" (header))
(declare-function mail-header-number "nnheader" (header))
(declare-function mail-header-references "nnheader" (header))
(declare-function mail-header-subject "nnheader" (header))
(declare-function mail-decode-encoded-word-string "mail-parse" (string))
(declare-function mail-extract-address-components "mail-extr" (address))
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
(declare-function gnus-summary-limit "gnus-sum" (articles))
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
(declare-function gnus-agent-article-name
                  "gnus-agent" (article group))
(declare-function gnus-agent-braid-nov
                  "gnus-agent" (articles file))
(declare-function gnus-agent-check-overview-buffer
                  "gnus-agent" (&optional buffer))
(declare-function gnus-agent-create-buffer "gnus-agent" ())
(declare-function gnus-agent-load-alist "gnus-agent" (group))
(declare-function gnus-agent-retrieve-headers
                  "gnus-agent" (articles group &optional fetch-old))
(declare-function gnus-agent-save-alist
                  "gnus-agent" (group &optional articles state))
(declare-function gnus-agent-save-group-info
                  "gnus-agent" (method group active))
(declare-function gnus-agent-method-p "gnus" (method-or-server))
(declare-function gnus-agent-request-article
                  "gnus-agent" (article group))
(declare-function gnus-sorted-ndifference "gnus-range" (list1 list2))
(declare-function gnus-summary-update-download-mark
                  "gnus-sum" (article))
(declare-function nntp-list-active-group
                  "nntp" (group &optional server))
(declare-function auth-source-pass-enable "auth-source-pass" ())
(declare-function auth-source-search "auth-source" (&rest spec))
(declare-function gnus-activate-group
                  "gnus-start"
                  (group &optional scan dont-check method dont-sub-check))
(declare-function gnus-get-unread-articles-in-group
                  "gnus-start" (info active &optional update))
(declare-function gnus-make-hashtable-from-newsrc-alist
                  "gnus-start" ())
(declare-function gnus-set-active "gnus" (group active))
(declare-function gnus-status-message "gnus" (command-method))
(declare-function gnus-summary-insert-articles
                  "gnus-sum" (articles))
(declare-function gnus-summary-goto-article
                  "gnus-sum" (article &optional all-headers force))
(declare-function gnus-ignored-from-addresses "gnus-sum" ())
(declare-function gnus-notifications-notify
                  "gnus-notifications"
                  (from subject &optional photo-file))
(declare-function gravatar-retrieve-synchronously "gravatar" (mail-address))
(declare-function range-member-p "range" (number ranges))

(defvar gnus-current-article)
(defvar auth-sources)
(defvar auth-source-pass-extra-query-keywords)
(defvar gnus-agent)
(defvar gnus-agent-article-alist)
(defvar gnus-agent-cache)
(defvar gnus-agent-covered-methods)
(defvar gnus-agent-directory)
(defvar gnus-agent-file-coding-system)
(defvar gnus-agent-overview-buffer)
(defvar gnus-active-hashtb)
(defvar gnus-article-buffer)
(defvar gnus-article-internal-prepare-hook)
(defvar gnus-command-method)
(defvar gnus-ancient-mark)
(defvar gnus-cached-mark)
(defvar gnus-canceled-mark)
(defvar gnus-catchup-mark)
(defvar gnus-del-mark)
(defvar gnus-downloadable-mark)
(defvar gnus-downloaded-mark)
(defvar gnus-dormant-mark)
(defvar gnus-duplicate-mark)
(defvar gnus-expirable-mark)
(defvar gnus-forwarded-mark)
(defvar gnus-kill-file-mark)
(defvar gnus-killed-mark)
(defvar gnus-low-score-mark)
(defvar gnus-no-mark)
(defvar gnus-process-mark)
(defvar gnus-read-mark)
(defvar gnus-replied-mark)
(defvar gnus-saved-mark)
(defvar gnus-score-below-mark)
(defvar gnus-score-over-mark)
(defvar gnus-spam-mark)
(defvar gnus-sparse-mark)
(defvar gnus-undownloaded-mark)
(defvar gnus-unseen-mark)
(defvar gnus-unsendable-mark)
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
(defvar gnus-group-mode-map)
(defvar gnus-group-buffer)
(defvar gnus-home-directory)
(defvar gnus-directory)
(defvar gnus-level-subscribed)
(defvar gnus-newsrc-alist)
(defvar gnus-newsrc-hashtb)
(defvar gnus-opened-servers)
(defvar gnus-plugged)
(defvar gnus-select-method)
(defvar gnus-secondary-select-methods)
(defvar gnus-startup-file)
(defvar gnus-summary-line-format)
(defvar gnus-summary-mark-positions)
(defvar gnus-summary-buffer)
(defvar gnus-notifications-id-to-msg)
(defvar gnus-notifications-minimum-level)
(defvar gnus-notifications-sent)
(defvar gnus-notifications-use-gravatar)
(defvar gnus-ignored-from-addresses)
(defvar gravatar-default-image)
(defvar gravatar-size)
(defvar gnus-ticked-mark)
(defvar gnus-topic-alist)
(defvar gnus-topic-indent-level)
(defvar gnus-topic-mode)
(defvar gnus-tmp-thread-tree-header-string)
(defvar gnus-tmp-internal-hook)
(defvar gnus-tmp-unread)
(defvar gnus-unread-mark)
(defvar gnus-use-cache)
(defvar gnus-newsgroup-active)
(defvar gnus-newsgroup-articles)
(defvar gnus-newsgroup-highest)
(defvar gnus-newsgroup-headers)
(defvar gnus-newsgroup-unreads)
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

(defface bs-gnus-summary-unread-mark-face
  '((t :inherit error :weight bold))
  "Face for unread article marks in Summary buffers."
  :group 'bs-gnus)

(defface bs-gnus-summary-attention-mark-face
  '((t :inherit warning :weight bold))
  "Face for article marks requiring attention."
  :group 'bs-gnus)

(defface bs-gnus-summary-activity-mark-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for reply, forwarding, and new-article marks."
  :group 'bs-gnus)

(defface bs-gnus-summary-stored-mark-face
  '((t :inherit success :weight bold))
  "Face for locally stored article marks."
  :group 'bs-gnus)

(defface bs-gnus-summary-quiet-mark-face
  '((t :inherit shadow))
  "Face for inactive and unavailable article marks."
  :group 'bs-gnus)

(defface bs-gnus-summary-negative-mark-face
  '((t :inherit error :weight bold))
  "Face for rejected, failed, and low-score article marks."
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

(defface bs-gnus-summary-month-face
  '((t :inherit font-lock-keyword-face
       :height 1.10 :underline nil :extend t))
  "Face used for month separators in Summary buffers."
  :group 'bs-gnus)

(defface bs-gnus-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for complete Gnus header lines."
  :group 'bs-gnus)

(defface bs-gnus-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in Gnus header lines."
  :group 'bs-gnus)

(defface bs-gnus-update-value-face
  '((t :inherit font-lock-keyword-face :slant italic))
  "Face used for update times and progress values."
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

(defcustom bs-gnus-summary-month-format "%Y %b"
  "Format used for root-article month separators in Summary buffers."
  :type 'string
  :group 'bs-gnus)

(defcustom bs-gnus-summary-month-line-spacing 0.65
  "Relative spacing added above and below Summary month separators."
  :type 'number
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

(defcustom bs-gnus-today-context-maximum-length 900000
  "Maximum number of characters in a Gnus today context.
Article bodies share the available space equally after reserving
space for context, thread, and article metadata.  This keeps the
result below provider limits while retaining every article."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-summary-display-thread-context nil
  "Whether to display the generated thread context buffer.
When nil, keep the buffer named by `bs-gnus-context-buffer-name'
hidden and select the current Summary row.  When non-nil, display
that buffer and select all of its text."
  :type 'boolean
  :group 'bs-gnus)

(defcustom bs-gnus-summary-thread-context-hook nil
  "Hook run after preparing a Gnus context.
The hook runs in the originating Summary or Group buffer while the
buffer named by `bs-gnus-context-buffer-name' contains the selected
subthread or today's articles."
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

(defcustom bs-gnus-update-interval (* 30 60)
  "Seconds between complete background Gnus updates."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-update-retry-delays '(300 900 1800)
  "Seconds to wait after consecutive background update failures.
After exhausting the list, continue using its final delay."
  :type '(repeat natnum)
  :group 'bs-gnus)

(defcustom bs-gnus-update-stall-timeout 120
  "Seconds without worker output before an update is considered stalled."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-notifications-avatar-cache-directory
  (locate-user-emacs-file "cache/gnus/notification-avatars/")
  "Directory containing persistent notification avatars."
  :type 'directory
  :group 'bs-gnus)

(defcustom bs-gnus-notifications-avatar-cache-expiry
  (* 90 24 60 60)
  "Seconds before a cached notification avatar expires."
  :type 'natnum
  :group 'bs-gnus)

(defcustom bs-gnus-notifications-read-display-function
  #'bs-call-in-new-frame
  "Function used to display Gnus notification Read actions.
The function receives the action function followed by its arguments.
Use `bs-call-in-current-frame' or `bs-call-in-new-frame' for the
standard behaviors."
  :type 'function
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

(defvar bs-gnus--update-enabled nil
  "Non-nil when background Gnus updates are installed.")

(defvar bs-gnus--update-processes (make-hash-table :test #'equal)
  "Live update worker processes keyed by Gnus server name.")

(defvar bs-gnus--update-progress (make-hash-table :test #'equal)
  "Worker progress records keyed by Gnus server name.")

(defvar bs-gnus--update-failures (make-hash-table :test #'equal)
  "Most recent worker failure messages keyed by Gnus server name.")

(defvar bs-gnus--update-retry-counts (make-hash-table :test #'equal)
  "Consecutive worker failure counts keyed by Gnus server name.")

(defvar bs-gnus--update-retry-timers (make-hash-table :test #'equal)
  "Retry timers keyed by Gnus server name.")

(defvar bs-gnus--update-apply-queue nil
  "Pending local operations produced by background workers.")

(defvar bs-gnus--update-apply-timer nil
  "Idle timer applying staged update results.")

(defvar bs-gnus--update-apply-done 0
  "Number of staged update operations applied in the current batch.")

(defvar bs-gnus--update-apply-total 0
  "Total staged update operations in the current batch.")

(defvar bs-gnus--update-imported-bodies
  (make-hash-table :test #'equal)
  "Imported article numbers keyed by full Gnus group name.")

(defvar bs-gnus--update-apply-errors
  (make-hash-table :test #'equal)
  "Local staging errors keyed by Gnus server name.")

(defvar bs-gnus--update-periodic-timer nil
  "Timer starting the next complete background update.")

(defvar bs-gnus--update-start-timer nil
  "Idle timer starting the first update of a Gnus session.")

(defvar bs-gnus--update-header-timer nil
  "Timer refreshing countdown text in Gnus header lines.")

(defvar bs-gnus--update-next-time nil
  "Absolute time scheduled for the next complete update.")

(defvar bs-gnus--update-source-total 0
  "Number of remote sources in the most recent complete update.")

(defvar bs-gnus--update-original-group-g-binding nil
  "Binding replaced by `bs-gnus-update' in `gnus-group-mode-map'.")

(defvar bs-gnus--update-group-binding-saved-p nil
  "Non-nil after saving the original Group `g' binding.")

(defvar bs-gnus--update-worker-credential nil
  "Credential supplied to the isolated update worker.")

(defvar bs-gnus--update-worker-auth-source-search-function nil
  "Original `auth-source-search' function in an update worker.")

(defvar bs-gnus--update-worker-live-agent-directory nil
  "Live Agent directory read by an isolated update worker.")

(defvar bs-gnus--update-worker-avatar-cache-directory nil
  "Persistent avatar cache written by an isolated update worker.")

(defvar bs-gnus--update-worker-avatar-cache-expiry nil
  "Avatar cache lifetime used by an isolated update worker.")

(defvar bs-gnus--update-worker-gravatar-default-image nil
  "Gravatar fallback policy used by an isolated update worker.")

(defvar bs-gnus--update-worker-gravatar-size nil
  "Gravatar image size used by an isolated update worker.")

(defvar bs-gnus--notifications-enabled nil
  "Non-nil when the background-update notification adapter is enabled.")

(defvar bs-gnus--notifications-client
  (bs-notifications-create-client
   :source 'gnus
   :key-function #'bs-gnus--notifications-key
   :delivery-function #'bs-gnus--notifications-deliver
   :error-function #'bs-gnus--notifications-report-error)
  "Gnus client of the shared desktop notification queue.")

(defvar bs-gnus--update-header-map
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1] #'bs-gnus-update)
    (define-key map [mode-line mouse-1] #'bs-gnus-update)
    map)
  "Keymap used by the clickable Group update status.")

(defconst bs-gnus--update-protocol-version 2
  "Protocol version shared with background update workers.")

(defconst bs-gnus--update-header-chunk-size 200
  "Maximum number of headers fetched between progress reports.")

(defconst bs-gnus--update-body-chunk-size 10
  "Maximum number of article bodies fetched between progress reports.")

(defconst bs-gnus--update-apply-time-budget 0.01
  "Maximum seconds spent in one staged-result application slice.")

(put 'bs-gnus--summary-fold-state 'permanent-local t)

(defun bs-gnus--group-buffers ()
  "Return live Gnus Group buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-group-mode)))
   (buffer-list)))

(defun bs-gnus--summary-buffers ()
  "Return live Gnus Summary buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-summary-mode)))
   (buffer-list)))

(defun bs-gnus--update-worker-emit (kind payload)
  "Write a worker message of KIND containing PAYLOAD to standard output."
  (princ (format "BS-GNUS-%s %S\n" kind payload)))

(defun bs-gnus--update-worker-read-request ()
  "Read one background update request from standard input."
  (with-temp-buffer
    (insert-file-contents "/dev/stdin")
    (goto-char (point-min))
    (read (current-buffer))))

(defun bs-gnus--update-worker-auth-source-search (&rest spec)
  "Return the worker credential or search authentication using SPEC."
  (if bs-gnus--update-worker-credential
      (list bs-gnus--update-worker-credential)
    (apply bs-gnus--update-worker-auth-source-search-function spec)))

(defun bs-gnus--update-worker-article-range (low high)
  "Return the inclusive article-number sequence from LOW through HIGH."
  (when (<= low high)
    (number-sequence low high)))

(defun bs-gnus--update-worker-filter-active (articles active)
  "Return ARTICLES whose numbers fall within ACTIVE."
  (let ((low (or (car active) 0))
        (high (or (cdr active) -1)))
    (seq-filter
     (lambda (article)
       (and (integerp article)
            (<= low article high)))
     articles)))

(defun bs-gnus--update-worker-decode-header (value)
  "Decode the mail header field VALUE without failing an update."
  (condition-case nil
      (mail-decode-encoded-word-string (or value ""))
    (error (or value ""))))

(defun bs-gnus--update-worker-overview-records
    (file group articles)
  "Return notification records for ARTICLES in overview FILE and GROUP."
  (let ((wanted (make-hash-table :test #'eql))
        (records (make-hash-table :test #'eql)))
    (dolist (article articles)
      (puthash article t wanted))
    (when (file-readable-p file)
      (require 'mail-extr)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward
                "^\\([0-9]+\\)\t\\([^\t]*\\)\t\\([^\t]*\\)\t\\([^\t]*\\)\t"
                nil t)
          (let ((article (string-to-number (match-string 1))))
            (when (gethash article wanted)
              (let* ((raw-subject (match-string 2))
                     (raw-from (match-string 3))
                     (date (match-string 4))
                     (subject
                      (bs-gnus--update-worker-decode-header
                       raw-subject))
                     (from
                      (bs-gnus--update-worker-decode-header
                       raw-from))
                     (address-parts
                      (mail-extract-address-components from))
                     (sender
                      (or (car address-parts)
                          (cadr address-parts)
                          from
                          "Unknown sender"))
                     (address (cadr address-parts))
                     (timestamp
                      (condition-case nil
                          (float-time (date-to-time date))
                        (error 0.0))))
                (puthash
                 article
                 (list :group group
                       :article article
                       :sender sender
                       :address address
                       :subject (if (string-empty-p subject)
                                    "(no subject)"
                                  subject)
                       :timestamp timestamp)
                 records)))))))
    (delq nil
          (mapcar (lambda (article) (gethash article records))
                  articles))))

(defun bs-gnus--update-worker-avatar-current-p (file)
  "Return non-nil when cached avatar FILE is present and current."
  (when-let* ((attributes (file-attributes file)))
    (and (> (file-attribute-size attributes) 0)
         (< (float-time
             (time-subtract
              (current-time)
              (file-attribute-modification-time attributes)))
            bs-gnus--update-worker-avatar-cache-expiry))))

(defun bs-gnus--update-worker-write-avatar (file data)
  "Atomically write avatar DATA to cache FILE."
  (make-directory bs-gnus--update-worker-avatar-cache-directory t)
  (let ((temporary
         (make-temp-file
          (expand-file-name
           ".avatar-"
           bs-gnus--update-worker-avatar-cache-directory))))
    (unwind-protect
        (progn
          (with-temp-buffer
            (set-buffer-multibyte nil)
            (insert data)
            (let ((coding-system-for-write 'binary))
              (write-region (point-min) (point-max)
                            temporary nil 'silent)))
          (rename-file temporary file t)
          (setq temporary nil))
      (when (and temporary (file-exists-p temporary))
        (delete-file temporary)))))

(defun bs-gnus--update-worker-avatar (address)
  "Return a cached Gravatar file for ADDRESS, retrieving it if needed."
  (when (and (stringp address)
             (not (string-empty-p address))
             bs-gnus--update-worker-avatar-cache-directory)
    (let* ((normalized (downcase (string-trim address)))
           (file
            (expand-file-name
             (secure-hash 'sha256 normalized)
             bs-gnus--update-worker-avatar-cache-directory)))
      (if (bs-gnus--update-worker-avatar-current-p file)
          file
        (when (file-exists-p file)
          (delete-file file))
        (condition-case nil
            (progn
              (require 'gravatar)
              (let* ((gravatar-default-image
                      (or bs-gnus--update-worker-gravatar-default-image
                          gravatar-default-image))
                     (gravatar-size
                      (or bs-gnus--update-worker-gravatar-size
                          gravatar-size))
                     (image
                      (gravatar-retrieve-synchronously normalized))
                     (data
                      (and (not (eq image 'error))
                           (plist-get (cdr image) :data))))
                (when (stringp data)
                  (bs-gnus--update-worker-write-avatar file data)
                  file)))
          (error nil))))))

(defun bs-gnus--update-worker-add-avatars (records)
  "Attach persistent Gravatar paths to notification RECORDS."
  (mapcar
   (lambda (record)
     (plist-put
      record :photo-file
      (bs-gnus--update-worker-avatar
       (plist-get record :address))))
   records))

(defun bs-gnus--update-worker-scan-groups (groups method)
  "Scan GROUPS through METHOD and return fetch plans."
  (let ((done 0)
        (total (length groups))
        plans
        errors)
    (dolist (spec groups)
      (let ((group (plist-get spec :group)))
        (condition-case err
            (if-let* ((active
                       (gnus-activate-group
                        group nil nil method)))
                (let* ((old-active (plist-get spec :active))
                       (old-high (or (cdr old-active) 0))
                       (new-low
                        (max (or (car active) 0)
                             (1+ old-high)))
                       (new-articles
                        (bs-gnus--update-worker-article-range
                         new-low (or (cdr active) -1)))
                       (body-articles
                        (sort
                         (delete-dups
                          (append
                           (copy-sequence
                            (plist-get spec :missing-bodies))
                           (copy-sequence new-articles)))
                         #'<))
                       (body-articles
                        (bs-gnus--update-worker-filter-active
                         body-articles active))
                       (notification-articles
                        (and (plist-get spec :notify)
                             (sort
                              (delete-dups
                               (append
                                (copy-sequence new-articles)
                                (copy-sequence
                                 (plist-get
                                  spec :notification-articles))))
                              #'<)))
                       (notification-articles
                        (bs-gnus--update-worker-filter-active
                         notification-articles active))
                       (live-overview
                        (and notification-articles
                             (bs-gnus--update-agent-file
                              bs-gnus--update-worker-live-agent-directory
                              method group ".overview")))
                       (local-notifications
                        (and live-overview
                             (bs-gnus--update-worker-overview-records
                              live-overview group
                              notification-articles)))
                       (local-articles
                        (mapcar
                         (lambda (record)
                           (plist-get record :article))
                         local-notifications))
                       (header-articles
                        (sort
                         (delete-dups
                          (append
                           (copy-sequence body-articles)
                           (seq-difference
                            notification-articles local-articles #'=)))
                         #'<)))
                  (push
                   (list :group group
                         :active active
                         :new-articles new-articles
                         :header-articles header-articles
                         :body-articles body-articles
                         :notification-articles notification-articles
                         :local-notifications local-notifications)
                   plans))
              (let ((status
                     (string-trim
                      (or (ignore-errors
                            (gnus-status-message method))
                          ""))))
                (push
                 (cons group
                       (if (string-empty-p status)
                           "Cannot activate group"
                         status))
                 errors)))
          (error
           (push (cons group (error-message-string err)) errors))))
      (setq done (1+ done))
      (bs-gnus--update-worker-emit
       "PROGRESS"
       (list :phase 'checking :done done :total total)))
    (list (nreverse plans) (nreverse errors))))

(defun bs-gnus--update-worker-fetch-group
    (plan completed total)
  "Fetch the staged data described by PLAN.
COMPLETED and TOTAL describe body-download progress.  Return a
pair containing the fetched body numbers and any errors."
  (let* ((group (plist-get plan :group))
         (headers (plist-get plan :header-articles))
         (bodies (plist-get plan :body-articles))
         fetched
         errors)
    (dolist (chunk (seq-partition
                    headers bs-gnus--update-header-chunk-size))
      (condition-case err
          (gnus-agent-retrieve-headers chunk group)
        (error
         (push (cons group (error-message-string err)) errors)))
      (bs-gnus--update-worker-emit
       "PROGRESS"
       (list :phase 'downloading
             :done completed :total total)))
    (dolist (chunk (seq-partition
                    bodies bs-gnus--update-body-chunk-size))
      (condition-case err
          (setq fetched
                (nconc fetched
                       (gnus-agent-fetch-articles group chunk)))
        (error
         (push (cons group (error-message-string err)) errors)))
      (setq completed (+ completed (length chunk)))
      (bs-gnus--update-worker-emit
       "PROGRESS"
       (list :phase 'downloading
             :done completed :total total)))
    (list fetched (nreverse errors) completed)))

(defun bs-gnus--update-worker-notifications (plan method)
  "Return notification records from PLAN after fetching through METHOD."
  (let* ((group (plist-get plan :group))
         (articles (plist-get plan :notification-articles))
         (stage-overview
          (and articles
               (bs-gnus--update-agent-file
                gnus-agent-directory method group ".overview")))
         (staged
          (and stage-overview
               (bs-gnus--update-worker-overview-records
                stage-overview group articles)))
         (table (make-hash-table :test #'eql)))
    (dolist (record (plist-get plan :local-notifications))
      (puthash (plist-get record :article) record table))
    (dolist (record staged)
      (puthash (plist-get record :article) record table))
    (bs-gnus--update-worker-add-avatars
     (delq nil
           (mapcar (lambda (article) (gethash article table))
                   articles)))))

(defun bs-gnus--update-worker-run (request)
  "Execute background update REQUEST and return its result."
  (unless (= (or (plist-get request :protocol) -1)
             bs-gnus--update-protocol-version)
    (error "Unsupported bs-gnus update protocol"))
  (require 'auth-source-pass)
  (setq auth-source-pass-extra-query-keywords
        (plist-get request :auth-source-pass-extra-query-keywords))
  (auth-source-pass-enable)
  (setq auth-sources (plist-get request :auth-sources))
  (require 'gnus-agent)
  (require 'gnus-start)
  (let* ((source (plist-get request :source))
         (method (plist-get request :method))
         (groups (plist-get request :groups))
         (stage (file-name-as-directory
                 (plist-get request :stage)))
         (gnus-agent-directory stage)
         (gnus-home-directory stage)
         (gnus-directory stage)
         (gnus-startup-file (expand-file-name "newsrc" stage))
         (gnus-select-method method)
         (gnus-secondary-select-methods nil)
         (gnus-agent t)
         (gnus-agent-cache t)
         (gnus-agent-covered-methods (list source))
         (gnus-opened-servers nil)
         (gnus-plugged t)
         (gnus-use-cache nil)
         (bs-gnus--update-worker-credential
          (plist-get request :credential))
         (bs-gnus--update-worker-auth-source-search-function
          (symbol-function 'auth-source-search))
         (bs-gnus--update-worker-live-agent-directory
          (file-name-as-directory
           (plist-get request :live-agent-directory)))
         (bs-gnus--update-worker-avatar-cache-directory
          (and-let* ((directory
                      (plist-get request :avatar-cache-directory)))
            (file-name-as-directory directory)))
         (bs-gnus--update-worker-avatar-cache-expiry
          (plist-get request :avatar-cache-expiry))
         (bs-gnus--update-worker-gravatar-default-image
          (plist-get request :gravatar-default-image))
         (bs-gnus--update-worker-gravatar-size
          (plist-get request :gravatar-size))
         (gnus-newsrc-alist
          (cons
           (gnus-info-make "dummy.group" 0 nil)
           (mapcar
            (lambda (spec)
              (gnus-info-make
               (plist-get spec :group)
               3
               (plist-get spec :read)
               nil method))
            groups)))
         plans
         errors
         results
         (completed 0)
         total)
    (cl-letf (((symbol-function 'auth-source-search)
               #'bs-gnus--update-worker-auth-source-search))
      (setq gnus-active-hashtb (gnus-make-hashtable 50))
      (gnus-make-hashtable-from-newsrc-alist)
      (pcase-let ((`(,scanned ,scan-errors)
                   (bs-gnus--update-worker-scan-groups
                    groups method)))
        (setq plans scanned
              errors scan-errors))
      (setq total
            (cl-loop
             for plan in plans
             sum (length (plist-get plan :body-articles))))
      (bs-gnus--update-worker-emit
       "PROGRESS"
       (list :phase 'downloading :done 0 :total total))
      (dolist (plan plans)
        (pcase-let ((`(,fetched ,fetch-errors ,new-completed)
                     (bs-gnus--update-worker-fetch-group
                      plan completed total)))
          (setq completed new-completed
                errors (nconc errors fetch-errors))
          (push
           (append
            plan
            (list :fetched-bodies fetched
                  :notifications
                  (bs-gnus--update-worker-notifications
                   plan method)))
           results)))
      (list :protocol bs-gnus--update-protocol-version
            :source source
            :method method
            :stage stage
            :groups (nreverse results)
            :errors errors))))

;;;###autoload
(defun bs-gnus-update-worker ()
  "Run one noninteractive Gnus update worker from standard input."
  (let ((inhibit-message t)
        (message-log-max nil)
        result)
    (condition-case err
        (setq result
              (bs-gnus--update-worker-run
               (bs-gnus--update-worker-read-request)))
      (error
       (setq result
             (list :protocol bs-gnus--update-protocol-version
                   :fatal (error-message-string err)))))
    (bs-gnus--update-worker-emit "RESULT" result)))

(defun bs-gnus--update-active-p ()
  "Return non-nil while a worker or local apply operation is active."
  (or (> (hash-table-count bs-gnus--update-processes) 0)
      bs-gnus--update-apply-queue
      (timerp bs-gnus--update-apply-timer)))

(defun bs-gnus--update-force-header ()
  "Redisplay visible Gnus header lines."
  (dolist (buffer (append (bs-gnus--group-buffers)
                          (bs-gnus--summary-buffers)))
    (with-current-buffer buffer
      (force-mode-line-update t))))

(defun bs-gnus--update-next-text ()
  "Return the time remaining before the next complete update."
  (if (not bs-gnus--update-next-time)
      "not scheduled"
    (let ((seconds
           (max 0
                (float-time
                 (time-subtract
                  bs-gnus--update-next-time
                  (current-time))))))
      (if (< seconds 60)
          "<1 minutes"
        (format "%d minutes" (ceiling (/ seconds 60.0)))))))

(defun bs-gnus--update-progress-record (source payload)
  "Merge worker progress PAYLOAD into the record for SOURCE."
  (let ((record (copy-sequence
                 (or (gethash source bs-gnus--update-progress)
                     (list :phase 'checking
                           :check-done 0 :check-total 0
                           :download-done 0 :download-total 0))))
        (phase (plist-get payload :phase)))
    (setq record (plist-put record :phase phase))
    (pcase phase
      ('checking
       (setq record
             (plist-put record :check-done
                        (or (plist-get payload :done) 0))
             record
             (plist-put record :check-total
                        (or (plist-get payload :total) 0))))
      ('downloading
       (setq record
             (plist-put record :download-done
                        (or (plist-get payload :done) 0))
             record
             (plist-put record :download-total
                        (or (plist-get payload :total) 0)))))
    (puthash source record bs-gnus--update-progress)))

(defun bs-gnus--update-progress-text ()
  "Return the aggregate worker or local-apply progress text."
  (cond
   ((or bs-gnus--update-apply-queue
        (timerp bs-gnus--update-apply-timer))
    (format "APPLYING %d/%d"
            bs-gnus--update-apply-done
            bs-gnus--update-apply-total))
   ((> (hash-table-count bs-gnus--update-processes) 0)
    (let ((checking nil)
          (check-done 0)
          (check-total 0)
          (download-done 0)
          (download-total 0))
      (maphash
       (lambda (_source record)
         (when (eq (plist-get record :phase) 'checking)
           (setq checking t))
         (setq check-done
               (+ check-done
                  (if (eq (plist-get record :phase) 'checking)
                      (or (plist-get record :check-done) 0)
                    (or (plist-get record :check-total) 0)))
               check-total
               (+ check-total
                  (or (plist-get record :check-total) 0))
               download-done
               (+ download-done
                  (or (plist-get record :download-done) 0))
               download-total
               (+ download-total
                  (or (plist-get record :download-total) 0))))
       bs-gnus--update-progress)
      (if checking
          (format "CHECKING %d/%d" check-done check-total)
        (format "DOWNLOADING %d/%d"
                download-done download-total))))
   (t nil)))

(defun bs-gnus--update-header-status ()
  "Return the clickable background-update status for the Group header."
  (let* ((progress (bs-gnus--update-progress-text))
         (failure-count (hash-table-count bs-gnus--update-failures))
         (text
          (cond
           (progress
            (pcase-let ((`(,label ,value)
                         (split-string progress " " t)))
              (concat
               (propertize label 'face 'bs-gnus-header-label-face)
               " "
               (propertize value 'face 'bs-gnus-update-value-face))))
           ((> failure-count 0)
            (concat
             (propertize "UPDATE FAILED"
                         'face 'bs-gnus-header-label-face)
             " "
             (propertize
              (format "%d/%d"
                      failure-count
                      (max failure-count
                           bs-gnus--update-source-total))
              'face '(error bs-gnus-update-value-face))))
           (t
            (concat
             (propertize "NEXT UPDATE"
                         'face 'bs-gnus-header-label-face)
             " "
             (propertize (bs-gnus--update-next-text)
                         'face 'bs-gnus-update-value-face))))))
    (add-text-properties
     0 (length text)
     (list 'mouse-face 'mode-line-highlight
           'help-echo "mouse-1: update Gnus in the background"
           'keymap bs-gnus--update-header-map)
     text)
    text))

(defun bs-gnus--update-missing-bodies (group)
  "Return unread article numbers in GROUP absent from the Agent."
  (require 'gnus-agent)
  (let ((unread (gnus-list-of-unread-articles group))
        (gnus-agent-article-alist nil))
    (gnus-agent-load-alist group)
    (seq-remove
     (lambda (article)
       (or (cdr (assq article gnus-agent-article-alist))
           (file-exists-p
            (gnus-agent-article-name
             (number-to-string article) group))))
     unread)))

(defun bs-gnus--notifications-sent-articles (group)
  "Return article numbers already notified for GROUP this session."
  (and (boundp 'gnus-notifications-sent)
       (cdr (assoc group gnus-notifications-sent))))

(defun bs-gnus--notifications-candidates (group)
  "Return unread GROUP articles not yet notified this session."
  (seq-remove
   (lambda (article)
     (bs-notifications-key-pending-p
      bs-gnus--notifications-client
      (cons group article)))
   (seq-difference
    (gnus-list-of-unread-articles group)
    (bs-gnus--notifications-sent-articles group)
    #'=)))

(defun bs-gnus--update-sources ()
  "Return background-update requests grouped by remote NNTP source."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (info (cdr gnus-newsrc-alist))
      (when (<= (gnus-info-level info) gnus-level-subscribed)
        (let* ((group (gnus-info-group info))
               (method (gnus-find-method-for-group group)))
          (when (eq (car method) 'nntp)
            (let* ((source (gnus-method-to-server method t))
                   (entry (gethash source table))
                   (notify
                    (and bs-gnus--notifications-enabled
                         (<= (gnus-info-level info)
                             gnus-notifications-minimum-level)))
                   (spec
                    (list :group group
                          :active (copy-tree
                                   (or (gnus-active group)
                                       '(0 . 0)))
                          :read (copy-tree (gnus-info-read info))
                          :missing-bodies
                          (bs-gnus--update-missing-bodies group)
                          :notify notify
                          :notification-articles
                          (and notify
                               (bs-gnus--notifications-candidates
                                group)))))
              (if entry
                  (setf (plist-get entry :groups)
                        (nconc (plist-get entry :groups)
                               (list spec)))
                (puthash
                 source
                 (list :source source
                       :method method
                       :groups (list spec))
                 table)))))))
    (let (sources)
      (maphash (lambda (_source entry) (push entry sources)) table)
      (sort sources
            (lambda (left right)
              (string-lessp (plist-get left :source)
                            (plist-get right :source)))))))

(defun bs-gnus--update-source (source)
  "Return the current update request for SOURCE."
  (seq-find
   (lambda (entry)
     (equal (plist-get entry :source) source))
   (bs-gnus--update-sources)))

(defun bs-gnus--update-cancel-timer (timer)
  "Cancel TIMER when it is live."
  (when (timerp timer)
    (cancel-timer timer)))

(defun bs-gnus--update-cancel-retry (source)
  "Cancel the pending retry for SOURCE."
  (when-let* ((timer (gethash source bs-gnus--update-retry-timers)))
    (bs-gnus--update-cancel-timer timer)
    (remhash source bs-gnus--update-retry-timers)))

(defun bs-gnus--update-retry-delay (failure-count)
  "Return the retry delay for FAILURE-COUNT consecutive failures."
  (let* ((delays (or bs-gnus-update-retry-delays
                     (list bs-gnus-update-interval)))
         (index (min (1- (max 1 failure-count))
                     (1- (length delays)))))
    (max 1 (nth index delays))))

(defun bs-gnus--update-retry-source (source)
  "Retry the failed background update for SOURCE."
  (bs-gnus--update-cancel-retry source)
  (when (and bs-gnus--update-enabled
             (gnus-alive-p)
             (not (gethash source bs-gnus--update-processes)))
    (if-let* ((entry (bs-gnus--update-source source)))
        (bs-gnus--update-start-source entry)
      (remhash source bs-gnus--update-failures)
      (remhash source bs-gnus--update-retry-counts))))

(defun bs-gnus--update-record-failure (source errors)
  "Record ERRORS for SOURCE and schedule its next retry."
  (let* ((count (1+ (or (gethash source
                                 bs-gnus--update-retry-counts)
                        0)))
         (delay (bs-gnus--update-retry-delay count)))
    (puthash source count bs-gnus--update-retry-counts)
    (puthash source errors bs-gnus--update-failures)
    (bs-gnus--update-cancel-retry source)
    (when (and bs-gnus--update-enabled (gnus-alive-p))
      (puthash
       source
       (run-at-time delay nil
                    #'bs-gnus--update-retry-source source)
       bs-gnus--update-retry-timers))))

(defun bs-gnus--update-record-success (source)
  "Clear failure and retry state for SOURCE."
  (bs-gnus--update-cancel-retry source)
  (remhash source bs-gnus--update-failures)
  (remhash source bs-gnus--update-retry-counts))

(defun bs-gnus--update-schedule-next ()
  "Schedule the next complete background update."
  (bs-gnus--update-cancel-timer bs-gnus--update-periodic-timer)
  (let ((delay (max 1 bs-gnus-update-interval)))
    (setq bs-gnus--update-next-time
          (time-add (current-time) delay)
          bs-gnus--update-periodic-timer
          (run-at-time delay nil #'bs-gnus--update-periodic))))

(defun bs-gnus--update-periodic ()
  "Start one scheduled complete background update."
  (setq bs-gnus--update-periodic-timer nil
        bs-gnus--update-next-time nil)
  (when (and bs-gnus--update-enabled (gnus-alive-p))
    (if (bs-gnus--update-active-p)
        (bs-gnus--update-schedule-next)
      (bs-gnus-update))))

(defun bs-gnus--update-worker-command ()
  "Return the command used to start an isolated update worker."
  (let ((library (or (symbol-file 'bs-gnus-update-worker 'defun)
                     load-file-name
                     buffer-file-name)))
    (unless library
      (error "Cannot locate bs-gnus for the update worker"))
    (list (expand-file-name invocation-name invocation-directory)
          "-Q" "--batch"
          "-L" (file-name-directory library)
          "-l" library
          "-f" "bs-gnus-update-worker")))

(defun bs-gnus--update-reset-watchdog (process)
  "Reset the inactivity watchdog belonging to PROCESS."
  (bs-gnus--update-cancel-timer
   (process-get process 'bs-gnus-watchdog))
  (process-put
   process 'bs-gnus-watchdog
   (run-at-time
    (max 1 bs-gnus-update-stall-timeout) nil
    #'bs-gnus--update-worker-stalled process)))

(defun bs-gnus--update-worker-stalled (process)
  "Terminate PROCESS after it stops reporting progress."
  (when (process-live-p process)
    (process-put process 'bs-gnus-stalled t)
    (delete-process process)))

(defun bs-gnus--update-process-line (process line)
  "Handle one protocol LINE received from PROCESS."
  (cond
   ((string-prefix-p "BS-GNUS-PROGRESS " line)
    (when-let* ((payload
                 (ignore-errors
                   (read
                    (substring
                     line (length "BS-GNUS-PROGRESS "))))))
      (bs-gnus--update-progress-record
       (process-get process 'bs-gnus-source)
       payload)
      (bs-gnus--update-force-header)))
   ((string-prefix-p "BS-GNUS-RESULT " line)
    (process-put
     process 'bs-gnus-result
     (ignore-errors
       (read
        (substring line (length "BS-GNUS-RESULT "))))))))

(defun bs-gnus--update-process-filter (process output)
  "Consume protocol OUTPUT from background update PROCESS."
  (bs-gnus--update-reset-watchdog process)
  (let ((pending (concat (or (process-get process 'bs-gnus-pending) "")
                         output))
        newline)
    (while (setq newline (string-search "\n" pending))
      (bs-gnus--update-process-line
       process (substring pending 0 newline))
      (setq pending (substring pending (1+ newline))))
    (process-put process 'bs-gnus-pending pending)))

(defun bs-gnus--update-delete-stage (stage)
  "Delete the private temporary update directory STAGE."
  (when (and (stringp stage)
             (file-directory-p stage)
             (string-prefix-p
              (expand-file-name "bs-gnus-update-"
                                temporary-file-directory)
              (expand-file-name stage)))
    (delete-directory stage t)))

(defun bs-gnus--update-process-error (process event)
  "Return a concise failure description for PROCESS and EVENT."
  (let* ((buffer (process-get process 'bs-gnus-stderr))
         (details
          (and (buffer-live-p buffer)
               (with-current-buffer buffer
                 (string-trim (buffer-string))))))
    (cond
     ((process-get process 'bs-gnus-stalled)
      (format "No worker progress for %d seconds"
              bs-gnus-update-stall-timeout))
     ((and details (not (string-empty-p details)))
      (truncate-string-to-width details 300 nil nil "..."))
     (t (string-trim event)))))

(defun bs-gnus--update-finish-process (process event)
  "Finalize background PROCESS after EVENT."
  (when (memq (process-status process) '(exit signal failed))
    (when-let* ((pending (process-get process 'bs-gnus-pending))
                ((not (string-empty-p pending))))
      (bs-gnus--update-process-line process pending))
    (bs-gnus--update-cancel-timer
     (process-get process 'bs-gnus-watchdog))
    (let* ((source (process-get process 'bs-gnus-source))
           (stage (process-get process 'bs-gnus-stage))
           (result (process-get process 'bs-gnus-result)))
      (when (eq process (gethash source bs-gnus--update-processes))
        (remhash source bs-gnus--update-processes))
      (cond
       ((and result
             (= (or (plist-get result :protocol) -1)
                bs-gnus--update-protocol-version)
             (not (plist-get result :fatal)))
        (bs-gnus--update-enqueue-result result))
       (t
        (let ((error
               (or (plist-get result :fatal)
                   (bs-gnus--update-process-error process event))))
          (bs-gnus--update-record-failure source (list error))
          (remhash source bs-gnus--update-progress)
          (bs-gnus--update-delete-stage stage))))
      (dolist (buffer (list (process-buffer process)
                            (process-get process 'bs-gnus-stderr)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      (bs-gnus--update-force-header))))

(defun bs-gnus--update-process-sentinel (process event)
  "Dispatch update PROCESS completion described by EVENT."
  (bs-gnus--update-finish-process process event))

(defun bs-gnus--update-method-address (method)
  "Return the network address configured by NNTP METHOD."
  (or (cadr (assq 'nntp-address (cddr method)))
      (cadr method)))

(defun bs-gnus--update-credential (method)
  "Return a serializable authentication record for NNTP METHOD."
  (require 'auth-source)
  (when-let* ((entry
               (car
                (auth-source-search
                 :max 1
                 :host (bs-gnus--update-method-address method)
                 :require '(:user :secret))))
              (secret (plist-get entry :secret))
              (password
               (if (functionp secret)
                   (funcall secret)
                 secret)))
    (list :host (plist-get entry :host)
          :port (plist-get entry :port)
          :user (plist-get entry :user)
          :secret password
          :force t)))

(defun bs-gnus--update-start-source (entry)
  "Start the isolated worker described by source ENTRY."
  (let* ((source (plist-get entry :source))
         (stage (make-temp-file "bs-gnus-update-" t))
         (stdout (generate-new-buffer
                  (format " *bs-gnus-update %s*" source)))
         (stderr (generate-new-buffer
                  (format " *bs-gnus-update %s stderr*" source)))
         (request
          (list :protocol bs-gnus--update-protocol-version
                :source source
                :method (plist-get entry :method)
                :groups (plist-get entry :groups)
                :stage stage
                :live-agent-directory gnus-agent-directory
                :avatar-cache-directory
                (and bs-gnus--notifications-enabled
                     gnus-notifications-use-gravatar
                     bs-gnus-notifications-avatar-cache-directory)
                :avatar-cache-expiry
                bs-gnus-notifications-avatar-cache-expiry
                :gravatar-default-image
                (and (boundp 'gravatar-default-image)
                     gravatar-default-image)
                :gravatar-size
                (and (boundp 'gravatar-size) gravatar-size)
                :auth-sources auth-sources
                :auth-source-pass-extra-query-keywords
                (and (boundp 'auth-source-pass-extra-query-keywords)
                     auth-source-pass-extra-query-keywords)
                :credential
                (bs-gnus--update-credential
                 (plist-get entry :method))))
         process)
    (bs-gnus--update-cancel-retry source)
    (condition-case err
        (progn
          (setq process
                (make-process
                 :name (format "bs-gnus-update-%s" source)
                 :buffer stdout
                 :stderr stderr
                 :command (bs-gnus--update-worker-command)
                 :coding 'utf-8-unix
                 :connection-type 'pipe
                 :filter #'bs-gnus--update-process-filter
                 :sentinel #'bs-gnus--update-process-sentinel
                 :noquery t))
          (process-put process 'bs-gnus-source source)
          (process-put process 'bs-gnus-stage stage)
          (process-put process 'bs-gnus-stderr stderr)
          (puthash source process bs-gnus--update-processes)
          (puthash
           source
           (list :phase 'checking
                 :check-done 0
                 :check-total (length (plist-get entry :groups))
                 :download-done 0
                 :download-total 0)
           bs-gnus--update-progress)
          (bs-gnus--update-reset-watchdog process)
          (process-send-string process
                               (concat (prin1-to-string request) "\n"))
          (process-send-eof process))
      (error
       (when (process-live-p process)
         (delete-process process))
       (dolist (buffer (list stdout stderr))
         (when (buffer-live-p buffer)
           (kill-buffer buffer)))
       (bs-gnus--update-delete-stage stage)
       (bs-gnus--update-record-failure
        source (list (error-message-string err)))))))

;;;###autoload
(defun bs-gnus-update ()
  "Update Gnus remotely without blocking the main Emacs process."
  (interactive)
  (unless (gnus-alive-p)
    (user-error "Gnus is not running"))
  (if (bs-gnus--update-active-p)
      (message "%s" (or (bs-gnus--update-progress-text)
                        "Gnus update already in progress"))
    (let ((sources (bs-gnus--update-sources)))
      (setq bs-gnus--update-source-total (length sources))
      (bs-gnus--update-schedule-next)
      (if (not sources)
          (message "No subscribed NNTP groups to update")
        (dolist (entry sources)
          (bs-gnus--update-start-source entry))
        (bs-gnus--update-force-header)))))

(defun bs-gnus--update-agent-file (directory method group name)
  "Return the Agent file NAME for GROUP and METHOD below DIRECTORY."
  (let ((gnus-agent-directory (file-name-as-directory directory))
        (gnus-command-method method))
    (gnus-agent-article-name name group)))

(defun bs-gnus--update-overview-articles (file)
  "Return sorted article numbers present in overview FILE."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (articles)
        (while (re-search-forward "^\\([0-9]+\\)\t" nil t)
          (push (string-to-number (match-string 1)) articles))
        (nreverse articles)))))

(defun bs-gnus--update-merge-overview
    (stage method group header-articles)
  "Merge staged overview data for GROUP through METHOD.
STAGE is the worker Agent root.  HEADER-ARTICLES contains the
requested header numbers.  Return the numbers actually available."
  (require 'gnus-agent)
  (let* ((live-directory gnus-agent-directory)
         (stage-file
          (bs-gnus--update-agent-file
           stage method group ".overview"))
         (live-file
          (bs-gnus--update-agent-file
           live-directory method group ".overview"))
         (available
          (seq-intersection
           header-articles
           (or (bs-gnus--update-overview-articles stage-file) nil)
           #'=)))
    (when available
      (gnus-agent-create-buffer)
      (with-current-buffer gnus-agent-overview-buffer
        (erase-buffer)
        (insert-file-contents stage-file))
      (let ((gnus-command-method method))
        (gnus-agent-braid-nov available live-file)
        (with-current-buffer nntp-server-buffer
          (gnus-agent-check-overview-buffer)
          (make-directory (file-name-directory live-file) t)
          (let ((coding-system-for-write
                 gnus-agent-file-coding-system))
            (write-region (point-min) (point-max)
                          live-file nil 'silent)))
        (let ((gnus-agent-article-alist nil))
          (gnus-agent-load-alist group)
          (gnus-agent-save-alist group available nil))))
    available))

(defun bs-gnus--update-apply-metadata
    (_source method stage plan)
  "Apply active and overview metadata in PLAN from STAGE through METHOD."
  (let* ((group (plist-get plan :group))
         (active (plist-get plan :active))
         (available
          (bs-gnus--update-merge-overview
           stage method group
           (plist-get plan :header-articles)))
         (info (gnus-get-info group)))
    (setf (plist-get plan :available-headers) available)
    (when (and info active)
      (gnus-set-active group (copy-tree active))
      (gnus-get-unread-articles-in-group info active)
      (let ((gnus-command-method method))
        (gnus-agent-save-group-info
         method (gnus-group-real-name group) active)))))

(defun bs-gnus--update-copy-body
    (_source method stage group article)
  "Copy staged ARTICLE for GROUP through METHOD into the live Agent."
  (let* ((live-directory gnus-agent-directory)
         (name (number-to-string article))
         (source-file
          (bs-gnus--update-agent-file
           stage method group name))
         (destination
          (bs-gnus--update-agent-file
           live-directory method group name)))
    (when (file-readable-p source-file)
      (unless (file-exists-p destination)
        (make-directory (file-name-directory destination) t)
        (copy-file source-file destination))
      (puthash
       group
       (cons article
             (gethash group bs-gnus--update-imported-bodies))
       bs-gnus--update-imported-bodies))))

(defun bs-gnus--update-summary-window-states (buffer)
  "Return visible-window positions anchored to articles in BUFFER."
  (mapcar
   (lambda (window)
     (let ((start (window-start window)))
       (list
        window
        (or (get-text-property start 'gnus-intangible buffer)
            (with-current-buffer buffer
              (save-excursion
                (goto-char start)
                (gnus-summary-article-number))))
        (window-hscroll window))))
   (get-buffer-window-list buffer nil t)))

(defun bs-gnus--update-restore-summary-windows (buffer states)
  "Restore BUFFER windows from article-anchored STATES."
  (dolist (state states)
    (pcase-let ((`(,window ,article ,hscroll) state))
      (when (and (window-live-p window)
                 (eq (window-buffer window) buffer))
        (when article
          (with-current-buffer buffer
            (save-excursion
              (when (gnus-summary-goto-subject article nil t)
                (set-window-start window
                                  (line-beginning-position))))))
        (set-window-hscroll window hscroll)))))

(defun bs-gnus--update-current-summary-article ()
  "Return the article anchoring point in the current Summary buffer."
  (or (get-text-property (point) 'gnus-intangible)
      (gnus-summary-article-number)))

(defun bs-gnus--update-refresh-summary (group active new-articles)
  "Insert NEW-ARTICLES for GROUP locally and record ACTIVE."
  (dolist (buffer (bs-gnus--summary-buffers))
    (with-current-buffer buffer
      (when (equal gnus-newsgroup-name group)
        (let ((selected (bs-gnus--update-current-summary-article))
              (states
               (bs-gnus--update-summary-window-states buffer))
              (old
               (sort
                (mapcar #'gnus-data-number gnus-newsgroup-data)
                #'<)))
          (setq gnus-newsgroup-active (copy-tree active)
                gnus-newsgroup-highest (cdr active))
          (when new-articles
            (let ((gnus-agent-cache t))
              (gnus-summary-insert-articles new-articles))
            (setq gnus-newsgroup-unreads
                  (gnus-sorted-nunion
                   gnus-newsgroup-unreads new-articles))
            (gnus-summary-limit
             (gnus-sorted-nunion old new-articles)))
          (when selected
            (gnus-summary-goto-subject selected nil t))
          (bs-gnus--update-restore-summary-windows
           buffer states))))))

(defun bs-gnus--update-finish-group
    (_source method _stage plan)
  "Finalize live Agent and Summary state described by PLAN through METHOD."
  (let* ((group (plist-get plan :group))
         (imported
          (sort
           (delete-dups
            (gethash group bs-gnus--update-imported-bodies))
           #'<))
         (available (plist-get plan :available-headers))
         (new-articles
          (seq-intersection
           (plist-get plan :new-articles)
           available #'=)))
    (remhash group bs-gnus--update-imported-bodies)
    (when imported
      (let ((gnus-command-method method)
            (gnus-agent-article-alist nil))
        (gnus-agent-load-alist group)
        (gnus-agent-save-alist
         group imported (time-to-days nil))))
    (bs-gnus--update-refresh-summary
     group (plist-get plan :active) new-articles)))

(defun bs-gnus--notifications-group-eligible-p (group)
  "Return non-nil when GROUP remains eligible for notifications."
  (when-let* ((info (gnus-get-info group)))
    (<= (gnus-info-level info)
        gnus-notifications-minimum-level)))

(defun bs-gnus--notifications-article-unread-p (group article)
  "Return non-nil when ARTICLE remains unread and active in GROUP."
  (when-let* ((info (gnus-get-info group))
              (active (gnus-active group)))
    (and (<= (car active) article (cdr active))
         (not (range-member-p article (gnus-info-read info))))))

(defun bs-gnus--notifications-own-address-p (address)
  "Return non-nil when ADDRESS matches `gnus-ignored-from-addresses'."
  (and (boundp 'gnus-ignored-from-addresses)
       gnus-ignored-from-addresses
       (stringp address)
       (not (string-empty-p address))
       (condition-case nil
           (if (functionp gnus-ignored-from-addresses)
               (funcall gnus-ignored-from-addresses address)
             (let ((regexp (gnus-ignored-from-addresses)))
               (and regexp (string-match-p regexp address))))
         (error nil))))

(defun bs-gnus--notifications-mark-sent (group article id)
  "Record ARTICLE in GROUP as notified under notification ID."
  (let ((entry (assoc group gnus-notifications-sent)))
    (unless entry
      (setq entry (list group))
      (push entry gnus-notifications-sent))
    (cl-pushnew article (cdr entry) :test #'=))
  (unless (eq id t)
    (push (list id group article)
          gnus-notifications-id-to-msg)))

(defun bs-gnus--notifications-key (record)
  "Return the notification queue key for article RECORD."
  (cons (plist-get record :group)
        (plist-get record :article)))

(defun bs-gnus--notifications-deliver (record)
  "Deliver unread article RECORD if it remains eligible."
  (when bs-gnus--notifications-enabled
    (let ((group (plist-get record :group))
          (article (plist-get record :article))
          (address (plist-get record :address)))
      (when (and (bs-gnus--notifications-group-eligible-p group)
                 (bs-gnus--notifications-article-unread-p
                  group article)
                 (not (memq article
                            (bs-gnus--notifications-sent-articles
                             group)))
                 (not (bs-gnus--notifications-own-address-p address)))
        (when-let* ((id
                     (gnus-notifications-notify
                      (plist-get record :sender)
                      (plist-get record :subject)
                      (and-let* ((file
                                  (plist-get record :photo-file)))
                        (and (file-readable-p file) file)))))
          (bs-gnus--notifications-mark-sent
           group article id))))))

(defun bs-gnus--notifications-report-error (record error-data)
  "Report ERROR-DATA encountered while notifying about article RECORD."
  (message "Failed to notify about Gnus article %d: %s"
           (plist-get record :article)
           (error-message-string error-data)))

(defun bs-gnus--notifications-send (record)
  "Queue unread article RECORD for serial desktop notification delivery."
  (when bs-gnus--notifications-enabled
    (bs-notifications-enqueue
     bs-gnus--notifications-client record)))

(defun bs-gnus--notifications-read-and-position
    (function id key group article)
  "Call FUNCTION with ID and KEY, then focus ARTICLE from GROUP."
  (funcall function id key)
  (when (and (derived-mode-p 'gnus-summary-mode)
             (equal gnus-newsgroup-name group))
    (gnus-summary-goto-article article nil t)
    (when-let* ((window
                 (get-buffer-window gnus-article-buffer)))
      (select-window window))))

(defun bs-gnus--notifications-action-with-display-function
    (function id key)
  "Call notification action FUNCTION with ID and KEY.
Open mapped Read actions using the configured display function."
  (let ((message (assoc id gnus-notifications-id-to-msg)))
    (if (and (member key '("default" "read")) message)
        (funcall
         bs-gnus-notifications-read-display-function
         #'bs-gnus--notifications-read-and-position
         function id key (nth 1 message) (nth 2 message))
      (funcall function id key))))

(defun bs-gnus--update-group-identity-at (buffer position)
  "Return the Group or Topic identity at POSITION in BUFFER."
  (with-current-buffer buffer
    (list (get-text-property position 'gnus-group)
          (get-text-property position 'gnus-topic))))

(defun bs-gnus--update-find-group-identity (group topic)
  "Return the current buffer position matching GROUP or TOPIC."
  (save-excursion
    (goto-char (point-min))
    (catch 'position
      (while (not (eobp))
        (when (or (and group
                       (equal group
                              (get-text-property
                               (point) 'gnus-group)))
                  (and topic
                       (equal topic
                              (get-text-property
                               (point) 'gnus-topic))))
          (throw 'position (point)))
        (forward-line 1))
      nil)))

(defun bs-gnus--update-refresh-group ()
  "Rebuild the live Group buffer from locally updated Gnus state."
  (when (and (boundp 'gnus-group-buffer)
             (buffer-live-p (get-buffer gnus-group-buffer)))
    (with-current-buffer gnus-group-buffer
      (let* ((identity
              (bs-gnus--update-group-identity-at
               (current-buffer) (point)))
             (windows (get-buffer-window-list (current-buffer) nil t))
             (states
              (mapcar
               (lambda (window)
                 (append
                  (list window)
                  (bs-gnus--update-group-identity-at
                   (current-buffer) (window-start window))
                  (list (window-hscroll window))))
               windows)))
        (gnus-group-list-groups
         (car gnus-group-list-mode)
         (cdr gnus-group-list-mode))
        (when-let* ((position
                     (bs-gnus--update-find-group-identity
                      (car identity) (cadr identity))))
          (goto-char position))
        (dolist (state states)
          (pcase-let ((`(,window ,group ,topic ,hscroll) state))
            (when (and (window-live-p window)
                       (eq (window-buffer window) (current-buffer)))
              (when-let* ((position
                           (bs-gnus--update-find-group-identity
                            group topic)))
                (set-window-start window position))
              (set-window-hscroll window hscroll))))))))

(defun bs-gnus--update-finish-source
    (source stage worker-errors)
  "Finish SOURCE application from STAGE with WORKER-ERRORS."
  (let ((errors
         (nconc
          (copy-sequence worker-errors)
          (nreverse
           (gethash source bs-gnus--update-apply-errors)))))
    (remhash source bs-gnus--update-apply-errors)
    (remhash source bs-gnus--update-progress)
    (condition-case err
        (bs-gnus--update-refresh-group)
      (error
       (push (error-message-string err) errors)))
    (if errors
        (bs-gnus--update-record-failure source errors)
      (bs-gnus--update-record-success source))
    (bs-gnus--update-delete-stage stage)
    (bs-gnus--update-force-header)))

(defun bs-gnus--update-apply-operation (operation)
  "Apply one staged update OPERATION."
  (pcase operation
    (`(metadata ,source ,method ,stage ,plan)
     (bs-gnus--update-apply-metadata
      source method stage plan))
    (`(body ,source ,method ,stage ,group ,article)
     (bs-gnus--update-copy-body
      source method stage group article))
    (`(finish-group ,source ,method ,stage ,plan)
     (bs-gnus--update-finish-group
      source method stage plan))
    (`(notification ,_source ,record)
     (bs-gnus--notifications-send record))
    (`(finish-source ,source ,stage ,errors)
     (bs-gnus--update-finish-source
      source stage errors))))

(defun bs-gnus--update-schedule-apply ()
  "Schedule the next idle slice that applies staged update data."
  (unless (timerp bs-gnus--update-apply-timer)
    (setq bs-gnus--update-apply-timer
          (run-with-idle-timer
           0.05 nil #'bs-gnus--update-apply-slice))))

(defun bs-gnus--update-apply-slice ()
  "Apply staged update operations within a short time budget."
  (setq bs-gnus--update-apply-timer nil)
  (let ((deadline (+ (float-time)
                     bs-gnus--update-apply-time-budget)))
    (while (and bs-gnus--update-apply-queue
                (< (float-time) deadline)
                (not (input-pending-p)))
      (let* ((operation (pop bs-gnus--update-apply-queue))
             (source (nth 1 operation)))
        (condition-case err
            (bs-gnus--update-apply-operation operation)
          (error
           (puthash
            source
            (cons (error-message-string err)
                  (gethash source bs-gnus--update-apply-errors))
            bs-gnus--update-apply-errors)))
        (setq bs-gnus--update-apply-done
              (1+ bs-gnus--update-apply-done)))))
  (if bs-gnus--update-apply-queue
      (bs-gnus--update-schedule-apply)
    (setq bs-gnus--update-apply-done 0
          bs-gnus--update-apply-total 0))
  (bs-gnus--update-force-header))

(defun bs-gnus--update-enqueue-result (result)
  "Queue local application operations for worker RESULT."
  (let ((source (plist-get result :source))
        (method (plist-get result :method))
        (stage (plist-get result :stage))
        notification-records
        operations)
    (dolist (original-plan (plist-get result :groups))
      (let ((plan
             (plist-put original-plan :available-headers nil)))
        (push (list 'metadata source method stage plan)
              operations)
        (dolist (article (plist-get plan :fetched-bodies))
          (push (list 'body source method stage
                      (plist-get plan :group) article)
                operations))
        (push (list 'finish-group source method stage plan)
              operations)
        (setq notification-records
              (nconc notification-records
                     (copy-sequence
                      (plist-get plan :notifications))))))
    (dolist (record
             (sort notification-records
                   (lambda (left right)
                     (let ((left-time
                            (plist-get left :timestamp))
                           (right-time
                            (plist-get right :timestamp)))
                       (if (= left-time right-time)
                           (let ((left-group
                                  (plist-get left :group))
                                 (right-group
                                  (plist-get right :group)))
                             (if (equal left-group right-group)
                                 (< (plist-get left :article)
                                    (plist-get right :article))
                               (string-lessp left-group
                                             right-group)))
                         (< left-time right-time))))))
      (push (list 'notification source record)
            operations))
    (push (list 'finish-source source stage
                (plist-get result :errors))
          operations)
    (setq operations (nreverse operations)
          bs-gnus--update-apply-total
          (+ bs-gnus--update-apply-total
             (length operations))
          bs-gnus--update-apply-queue
          (nconc bs-gnus--update-apply-queue operations))
    (bs-gnus--update-schedule-apply)
    (bs-gnus--update-force-header)))

(defun bs-gnus--update-install-group-binding ()
  "Install the nonblocking Group `g' binding when enabled."
  (when (and bs-gnus--update-enabled
             (boundp 'gnus-group-mode-map))
    (unless bs-gnus--update-group-binding-saved-p
      (setq bs-gnus--update-original-group-g-binding
            (lookup-key gnus-group-mode-map (kbd "g"))
            bs-gnus--update-group-binding-saved-p t))
    (define-key gnus-group-mode-map (kbd "g") #'bs-gnus-update)))

(defun bs-gnus--update-restore-group-binding ()
  "Restore the Group binding replaced by the update component."
  (when (and bs-gnus--update-group-binding-saved-p
             (boundp 'gnus-group-mode-map))
    (define-key gnus-group-mode-map (kbd "g")
                bs-gnus--update-original-group-g-binding))
  (setq bs-gnus--update-original-group-g-binding nil
        bs-gnus--update-group-binding-saved-p nil))

(defun bs-gnus--update-start-initial ()
  "Start the first background update of the current Gnus session."
  (setq bs-gnus--update-start-timer nil)
  (when (and bs-gnus--update-enabled (gnus-alive-p))
    (bs-gnus-update)))

(defun bs-gnus--update-start ()
  "Start timers for one active Gnus session."
  (bs-gnus--update-cancel-timer bs-gnus--update-start-timer)
  (bs-gnus--update-cancel-timer bs-gnus--update-header-timer)
  (setq bs-gnus--update-header-timer
        (run-at-time 0 30 #'bs-gnus--update-force-header)
        bs-gnus--update-start-timer
        (run-with-idle-timer
         0.1 nil #'bs-gnus--update-start-initial)))

(defun bs-gnus--update-stop ()
  "Stop all background update work owned by the current Gnus session."
  (dolist (timer (list bs-gnus--update-start-timer
                       bs-gnus--update-periodic-timer
                       bs-gnus--update-header-timer
                       bs-gnus--update-apply-timer))
    (bs-gnus--update-cancel-timer timer))
  (setq bs-gnus--update-start-timer nil
        bs-gnus--update-periodic-timer nil
        bs-gnus--update-header-timer nil
        bs-gnus--update-apply-timer nil
        bs-gnus--update-next-time nil)
  (maphash
   (lambda (_source timer)
     (bs-gnus--update-cancel-timer timer))
   bs-gnus--update-retry-timers)
  (clrhash bs-gnus--update-retry-timers)
  (maphash
   (lambda (_source process)
     (bs-gnus--update-cancel-timer
      (process-get process 'bs-gnus-watchdog))
     (set-process-sentinel process #'ignore)
     (when (process-live-p process)
       (delete-process process))
     (bs-gnus--update-delete-stage
      (process-get process 'bs-gnus-stage))
     (dolist (buffer (list (process-buffer process)
                           (process-get process 'bs-gnus-stderr)))
       (when (buffer-live-p buffer)
         (kill-buffer buffer))))
   bs-gnus--update-processes)
  (clrhash bs-gnus--update-processes)
  (let (stages)
    (dolist (operation bs-gnus--update-apply-queue)
      (when-let* ((stage
                   (pcase operation
                     (`(metadata ,_ ,_ ,value . ,_) value)
                     (`(body ,_ ,_ ,value . ,_) value)
                     (`(finish-group ,_ ,_ ,value . ,_) value)
                     (`(finish-source ,_ ,value . ,_) value))))
        (cl-pushnew stage stages :test #'equal)))
    (mapc #'bs-gnus--update-delete-stage stages))
  (setq bs-gnus--update-apply-queue nil
        bs-gnus--update-apply-done 0
        bs-gnus--update-apply-total 0)
  (dolist (table (list bs-gnus--update-progress
                       bs-gnus--update-failures
                       bs-gnus--update-retry-counts
                       bs-gnus--update-imported-bodies
                       bs-gnus--update-apply-errors))
    (clrhash table))
  (bs-gnus--update-force-header))

;;;###autoload
(defun bs-gnus-notifications-enable ()
  "Deliver configured Gnus notifications from background updates."
  (interactive)
  (require 'gnus-notifications)
  (unless (advice-member-p
           #'bs-gnus--notifications-action-with-display-function
           'gnus-notifications-action)
    (advice-add
     'gnus-notifications-action :around
     #'bs-gnus--notifications-action-with-display-function))
  (setq bs-gnus--notifications-enabled t))

;;;###autoload
(defun bs-gnus-notifications-disable ()
  "Disable notifications without clearing this session's sent state."
  (interactive)
  (setq bs-gnus--notifications-enabled nil)
  (bs-notifications-clear-client bs-gnus--notifications-client)
  (advice-remove
   'gnus-notifications-action
   #'bs-gnus--notifications-action-with-display-function))

;;;###autoload
(defun bs-gnus-update-enable ()
  "Enable nonblocking background updates while Gnus is active."
  (interactive)
  (unless bs-gnus--update-enabled
    (setq bs-gnus--update-enabled t)
    (add-hook 'gnus-started-hook #'bs-gnus--update-start)
    (add-hook 'gnus-exit-gnus-hook #'bs-gnus--update-stop)
    (with-eval-after-load 'gnus-group
      (bs-gnus--update-install-group-binding))
    (when (gnus-alive-p)
      (bs-gnus--update-start)))
  t)

;;;###autoload
(defun bs-gnus-update-disable ()
  "Disable background Gnus updates and restore the native Group binding."
  (interactive)
  (when bs-gnus--update-enabled
    (setq bs-gnus--update-enabled nil)
    (remove-hook 'gnus-started-hook #'bs-gnus--update-start)
    (remove-hook 'gnus-exit-gnus-hook #'bs-gnus--update-stop)
    (bs-gnus--update-stop)
    (bs-gnus--update-restore-group-binding)))

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
  "Return the highest known article number in GROUP."
  (if-let* ((active (gnus-active group)))
      (cdr active)
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
  "Return update status and right-aligned Group statistics."
  (let* ((status (bs-gnus--update-header-status))
         (statistics
          (bs-gnus--group-root-statistics
           (bs-gnus--group-root-unread)))
         (header
          (concat
           status
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

(defun bs-gnus--summary-root-date (thread)
  "Return THREAD's root-article date, or nil when it is invalid."
  (condition-case nil
      (date-to-time
       (mail-header-date
        (gnus-data-header (car thread))))
    (error nil)))

(defun bs-gnus--summary-root-month (thread)
  "Return the month key and title of THREAD's root article."
  (when-let* ((date (bs-gnus--summary-root-date thread)))
    (cons (format-time-string "%Y-%m" date)
          (format-time-string bs-gnus-summary-month-format date))))

(defun bs-gnus--summary-threads-ordered-p (threads)
  "Return non-nil when THREADS have descending root-article dates."
  (let (previous
        (ordered-p t))
    (while (and ordered-p threads)
      (when-let* ((date (bs-gnus--summary-root-date (car threads))))
        (when (and previous (time-less-p previous date))
          (setq ordered-p nil))
        (setq previous date))
      (setq threads (cdr threads)))
    ordered-p))

(defun bs-gnus--summary-month-data (threads)
  "Return month boundaries and preceding breaks for THREADS.
The car is a hash table mapping root article numbers to month
labels and first-boundary flags.  The cdr marks root articles after
which the ordinary thread separator should be omitted."
  (let ((boundaries (make-hash-table :test #'eql))
        (breaks (make-hash-table :test #'eql))
        previous
        last-month
        (first-p t))
    (dolist (thread threads)
      (let* ((root (car thread))
             (article (gnus-data-number root))
             (month (bs-gnus--summary-root-month thread))
             (key (car-safe month))
             (title (cdr-safe month)))
        (when (and key (not (equal key last-month)))
          (puthash article (cons title first-p) boundaries)
          (when previous
            (puthash previous t breaks))
          (setq first-p nil
                last-month key))
        (setq previous article)))
    (cons boundaries breaks)))

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
             (propertize
              " unread · "
              'face 'bs-gnus-group-source-face)
             (propertize
              (number-to-string loaded)
              'face 'bs-gnus-summary-group-loaded-face)
             (propertize
              " loaded · "
              'face 'bs-gnus-group-source-face)
             (propertize
              (number-to-string total)
              'face 'bs-gnus-group-total-face)
             (propertize
              " total"
              'face 'bs-gnus-group-source-face)))
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

(defun bs-gnus--summary-month-line (title article first-p)
  "Return a month separator for TITLE anchored to ARTICLE.
FIRST-P says that this is the first month in the Summary buffer."
  (let* ((top-spacing
          (+ bs-gnus-summary-month-line-spacing
             (if first-p bs-gnus-header-bottom-spacing 0)))
         (line
          (bs-gnus--summary-decoration-line
           (concat "  " title) article 'month-separator))
         (newline (1- (length line))))
    (add-text-properties
     0 (length line)
     '(face bs-gnus-summary-month-face)
     line)
    (add-text-properties
     0 1
     `(line-prefix ,(bs-gnus--top-spacing-prefix top-spacing))
     line)
    (add-text-properties
     newline (length line)
     `(line-spacing ,bs-gnus-summary-month-line-spacing)
     line)
    line))

(defun bs-gnus--summary-context-line (header width)
  "Return an unselectable context line for HEADER fitted to WIDTH."
  (let* ((prefix
          (concat
           (make-string bs-gnus--summary-prefix-width ?\s)
           "…  "))
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

(defun bs-gnus--summary-primary-mark-face (mark)
  "Return the face appropriate for primary article MARK."
  (cond
   ((= mark gnus-unread-mark)
    'bs-gnus-summary-unread-mark-face)
   ((memq mark (list gnus-ticked-mark gnus-dormant-mark))
    'bs-gnus-summary-attention-mark-face)
   ((memq mark
          (list gnus-ancient-mark gnus-expirable-mark
                gnus-del-mark gnus-read-mark gnus-catchup-mark
                gnus-sparse-mark))
    'bs-gnus-summary-quiet-mark-face)
   ((memq mark
          (list gnus-killed-mark gnus-spam-mark
                gnus-kill-file-mark gnus-low-score-mark
                gnus-canceled-mark gnus-duplicate-mark))
    'bs-gnus-summary-negative-mark-face)))

(defun bs-gnus--summary-secondary-mark-face (mark)
  "Return the face appropriate for secondary article MARK."
  (cond
   ((= mark gnus-process-mark)
    'bs-gnus-summary-attention-mark-face)
   ((memq mark (list gnus-cached-mark gnus-saved-mark))
    'bs-gnus-summary-stored-mark-face)
   ((memq mark
          (list gnus-replied-mark gnus-forwarded-mark
                gnus-unseen-mark))
    'bs-gnus-summary-activity-mark-face)))

(defun bs-gnus--summary-download-mark-face (mark)
  "Return the face appropriate for Agent download MARK."
  (cond
   ((= mark gnus-downloaded-mark)
    'bs-gnus-summary-stored-mark-face)
   ((= mark gnus-undownloaded-mark)
    'bs-gnus-summary-quiet-mark-face)
   ((= mark gnus-downloadable-mark)
    'bs-gnus-summary-attention-mark-face)
   ((= mark gnus-unsendable-mark)
    'bs-gnus-summary-negative-mark-face)))

(defun bs-gnus--summary-score-mark-face (mark)
  "Return the face appropriate for article score MARK."
  (cond
   ((= mark gnus-score-over-mark)
    'bs-gnus-summary-stored-mark-face)
   ((= mark gnus-score-below-mark)
    'bs-gnus-summary-negative-mark-face)))

(defun bs-gnus--summary-mark-face (kind mark)
  "Return the face for mark KIND whose character is MARK."
  (pcase kind
    ('unread (bs-gnus--summary-primary-mark-face mark))
    ('replied (bs-gnus--summary-secondary-mark-face mark))
    ('download (bs-gnus--summary-download-mark-face mark))
    ('score (bs-gnus--summary-score-mark-face mark))))

(defun bs-gnus--summary-remove-mark-faces ()
  "Remove faces previously added to individual Summary marks."
  (let ((position (point-min)))
    (while (setq position
                 (text-property-not-all
                  position (point-max) 'bs-gnus-mark-face nil))
      (let* ((end
              (next-single-property-change
               position 'bs-gnus-mark-face nil (point-max)))
             (mark-face
              (get-text-property position 'bs-gnus-mark-face))
             (current (get-text-property position 'face))
             (faces
              (cond
               ((eq current mark-face) nil)
               ((listp current)
                (delq mark-face (copy-sequence current)))
               (t current))))
        (put-text-property position end 'face faces)
        (remove-text-properties
         position end '(bs-gnus-mark-face nil))
        (setq position end)))))

(defun bs-gnus--summary-apply-mark-faces ()
  "Apply semantic faces to visible Summary status marks."
  (bs-gnus--summary-remove-mark-faces)
  (dolist (data gnus-newsgroup-data)
    (save-excursion
      (goto-char (gnus-data-pos data))
      (let ((start (line-beginning-position))
            (end (line-end-position)))
        (dolist (entry gnus-summary-mark-positions)
          (when-let* ((offset (cdr entry))
                      (position (+ start offset))
                      ((< position end))
                      (mark
                       (if (eq (car entry) 'unread)
                           (gnus-data-mark data)
                         (char-after position)))
                      ((not (= mark ?\s)))
                      (face
                       (bs-gnus--summary-mark-face
                        (car entry) mark)))
            (add-face-text-property
             position (1+ position) face nil)
            (put-text-property
             position (1+ position) 'bs-gnus-mark-face face)))))))

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
  (bs-gnus--summary-remove-mark-faces)
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
        (bs-gnus--summary-apply-mark-faces)
        (let* ((count-width
                (bs-gnus--summary-thread-count-width threads))
               (month-data
                (when (bs-gnus--summary-threads-ordered-p threads)
                  (bs-gnus--summary-month-data threads)))
               (month-boundaries (car month-data))
               (month-breaks (cdr month-data)))
          (dolist (thread (reverse threads))
            (let ((root (car thread))
                  (last (car (last thread))))
              (goto-char (gnus-data-pos last))
              (forward-line 1)
              (unless (or (eobp)
                          (gethash
                           (gnus-data-number root) month-breaks))
                (insert
                 (bs-gnus--summary-decoration-line
                  "" (gnus-data-number root) 'separator)))
              (goto-char (gnus-data-pos root))
              (beginning-of-line)
              (when-let* ((month
                           (gethash
                            (gnus-data-number root)
                            month-boundaries)))
                (insert
                 (bs-gnus--summary-month-line
                  (car month) (gnus-data-number root) (cdr month))))
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

(defun bs-gnus--today-bounds ()
  "Return today's local-time bounds as epoch seconds."
  (pcase-let* ((`(,_second ,_minute ,_hour ,day ,month ,year . ,_)
                (decode-time))
               (start (encode-time 0 0 0 day month year)))
    (cons (float-time start)
          (float-time (time-add start (days-to-time 1))))))

(defun bs-gnus--today-overview-records
    (file group method start end)
  "Return today's records from overview FILE for GROUP and METHOD.
START and END are epoch seconds bounding the local calendar day."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (records)
        (while (not (eobp))
          (let* ((line
                  (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position)))
                 (fields (split-string line "\t" nil))
                 (article (and (car fields)
                               (string-to-number (car fields))))
                 (date (nth 3 fields))
                 (timestamp
                  (and date
                       (condition-case nil
                           (float-time (date-to-time date))
                         (error nil)))))
            (when (and (>= (length fields) 6)
                       (> article 0)
                       timestamp
                       (<= start timestamp)
                       (< timestamp end))
              (push
               (list :group group
                     :method method
                     :article article
                     :subject
                     (bs-gnus--update-worker-decode-header
                      (nth 1 fields))
                     :from
                     (bs-gnus--update-worker-decode-header
                      (nth 2 fields))
                     :date date
                     :timestamp timestamp
                     :message-id (nth 4 fields)
                     :references (nth 5 fields))
               records)))
          (forward-line 1))
        (nreverse records)))))

(defun bs-gnus--today-records ()
  "Return today's locally indexed articles from subscribed Gnus groups."
  (pcase-let ((`(,start . ,end) (bs-gnus--today-bounds)))
    (let (records)
      (dolist (info (cdr gnus-newsrc-alist))
        (when (<= (gnus-info-level info) gnus-level-subscribed)
          (let* ((group (gnus-info-group info))
                 (method (gnus-find-method-for-group group)))
            (when (gnus-agent-method-p method)
              (setq records
                    (nconc
                     records
                     (bs-gnus--today-overview-records
                      (bs-gnus--update-agent-file
                       gnus-agent-directory method group ".overview")
                      group method start end)))))))
      (sort records
            (lambda (left right)
              (< (plist-get left :timestamp)
                 (plist-get right :timestamp)))))))

(defun bs-gnus--context-subject (record)
  "Return RECORD's subject without common reply prefixes."
  (replace-regexp-in-string
   "\\`\\(?:\\(?:re\\|fwd?\\):[ \\t]*\\)+" ""
   (or (plist-get record :subject) "[no subject]") t t))

(defun bs-gnus--context-thread-key (record)
  "Return a stable thread key for Gnus overview RECORD."
  (or (car (split-string (or (plist-get record :references) "")))
      (let ((message-id (plist-get record :message-id)))
        (and (not (string-empty-p (or message-id "")))
             message-id))
      (downcase (bs-gnus--context-subject record))))

(defun bs-gnus--records-by-thread (records)
  "Group chronological Gnus RECORDS by thread in first-article order."
  (let ((table (make-hash-table :test #'equal))
        order)
    (dolist (record records)
      (let ((key (bs-gnus--context-thread-key record)))
        (unless (gethash key table)
          (push key order))
        (puthash key (cons record (gethash key table)) table)))
    (mapcar
     (lambda (key)
       (nreverse (gethash key table)))
     (nreverse order))))

(defun bs-gnus--context-article-fallback (record &optional error-data)
  "Return metadata for unavailable article RECORD.
When ERROR-DATA is non-nil, include its local rendering error."
  (format
   (concat "From: %s\nSubject: %s\nDate: %s\n"
           "Message-ID: %s\nNewsgroup: %s\nArticle: %d\n\n%s")
   (or (plist-get record :from) "[unknown]")
   (or (plist-get record :subject) "[no subject]")
   (or (plist-get record :date) "[unknown]")
   (or (plist-get record :message-id) "[none]")
   (plist-get record :group)
   (plist-get record :article)
   (if error-data
       (format "[Article body could not be rendered locally: %s]"
               (error-message-string error-data))
     "[Article body was not cached locally.]")))

(defun bs-gnus--render-context-record (source record)
  "Render Gnus overview RECORD using SOURCE buffer settings."
  (condition-case error-data
      (let ((gnus-command-method (plist-get record :method))
            (group (plist-get record :group))
            (article (plist-get record :article)))
        (if (bs-gnus--summary-agent-article-available-p group article)
            (bs-gnus--summary-render-agent-article
             source group article)
          (bs-gnus--context-article-fallback record)))
    (error
     (bs-gnus--context-article-fallback record error-data))))

(defun bs-gnus--build-today-context (source records)
  "Build and return a Gnus context from today's RECORDS using SOURCE."
  (let* ((threads (bs-gnus--records-by-thread records))
         (thread-count (length threads))
         (article-count (length records))
         (preamble
          (concat
           "# Today's Gnus Context\n\n"
           "Source: All subscribed groups in the local Gnus Agent\n\n"
           (format "Threads: %d\n" thread-count)
           (format "Articles: %d\n" article-count)))
         (sections
          (cl-loop
           for thread in threads
           for thread-index from 1
           for groups = (delete-dups
                         (mapcar
                          (lambda (record)
                            (plist-get record :group))
                          thread))
           collect
           (cons
            (concat
             (format "\n## Thread %d of %d: %s\n\n"
                     thread-index thread-count
                     (bs-gnus--context-subject (car thread)))
             (format "Newsgroups: %s\n"
                     (mapconcat #'identity groups ", ")))
            (cl-loop
             for record in thread
             for article-index from 1
             collect
             (cons
              (format "\n### Article %d of %d\n\n"
                      article-index (length thread))
              record)))))
         (fixed-length
          (+ (length preamble)
             (cl-loop
              for (thread-heading . articles) in sections
              sum
              (+ (length thread-heading)
                 (cl-loop
                  for article in articles
                  sum (1+ (length (car article))))))))
         (body-budget
          (if (zerop article-count)
              0
            (/ (max 0
                    (- bs-gnus-today-context-maximum-length
                       fixed-length))
               article-count)))
         (truncation
          "\n\n[Article body truncated to fit context budget.]"))
    (when (> fixed-length bs-gnus-today-context-maximum-length)
      (user-error
       "Gnus today context metadata needs %d characters; budget is %d"
       fixed-length bs-gnus-today-context-maximum-length))
    (with-current-buffer
        (get-buffer-create bs-gnus-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert preamble)
      (dolist (section sections)
        (insert (car section))
        (dolist (article (cdr section))
          (let ((rendered
                 (bs-gnus--render-context-record source (cdr article))))
            (insert
             (car article)
             (if (> (length rendered) body-budget)
                 (concat
                  (substring
                   rendered 0
                   (max 0 (- body-budget (length truncation))))
                  (substring
                   truncation 0 (min body-budget (length truncation))))
               rendered)
             "\n"))))
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

;;;###autoload
(defun bs-gnus-prepare-today-context ()
  "Prepare today's local articles from a Gnus Group or Summary buffer.
Group articles by thread and order each thread chronologically.
Read only Agent overview and body data without contacting any news
server."
  (interactive)
  (unless (derived-mode-p 'gnus-group-mode 'gnus-summary-mode)
    (user-error "This command requires a Gnus Group or Summary buffer"))
  (require 'gnus-agent)
  (unless gnus-agent
    (user-error "Gnus Agent is not enabled"))
  (let* ((source (current-buffer))
         (records (bs-gnus--today-records)))
    (unless records
      (user-error "No locally indexed Gnus articles from today"))
    (bs-gnus--build-today-context source records)
    (run-hooks 'bs-gnus-summary-thread-context-hook)
    (message "Prepared %d Gnus articles from today in %s"
             (length records) bs-gnus-context-buffer-name)))

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
