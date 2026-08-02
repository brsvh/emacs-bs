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
(require 'url)

(defvar shr-inhibit-images)
(defvar shr-use-fonts)
(defvar url-http-end-of-headers)
(defvar url-http-response-status)

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

(provide 'bs-elfeed)
;;; bs-elfeed.el ends here
