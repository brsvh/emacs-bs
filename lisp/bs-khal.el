;;; bs-khal.el --- khal integration  -*- lexical-binding: t; -*-

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

;; This package integrates Khalel with the personal calendar
;; workflow.  Calendar imports run in a separate Emacs process so
;; that querying khal and rewriting the generated Org file do not
;; block the interactive Emacs session.

;;; Code:

(require 'bs-ext)
(require 'khalel)
(require 'org-capture)

(declare-function calfw-refresh-calendar-buffer "calfw" (&optional no-resize))
(declare-function org-agenda-redo "org-agenda" (&optional all))

(defgroup bs-khal nil
  "Personal khal and Khalel integration."
  :group 'calendar)

(defcustom bs-khal-default-calendar nil
  "Default writable calendar derived from the account configuration."
  :type '(choice (const :tag "Use Khalel default" nil)
                 string)
  :group 'bs-khal)

(defcustom bs-khal-calendar-directories nil
  "Directories containing calendar files read by khal."
  :type '(repeat directory)
  :group 'bs-khal)

(defcustom bs-khal-import-buffer-name "*bs-khal-import*"
  "Name of the buffer used by the background import process."
  :type 'string
  :group 'bs-khal)

(defcustom bs-khal-import-check-interval nil
  "Seconds between checks for calendar source changes.

When nil or non-positive, do not check periodically.  A check is
inexpensive and starts a full background import only when a calendar
file changed or the local date advanced."
  :type '(choice (const :tag "Do not check periodically" nil)
                 number)
  :group 'bs-khal)

(defcustom bs-khal-import-state-file
  (bs-path bs-state-directory "bs-khal-import-state")
  "File in which to persist the last successful import state."
  :type 'file
  :group 'bs-khal)

(defvar bs-khal--import-process nil
  "Current background calendar import process.")

(defvar bs-khal--import-pending nil
  "Whether another import should run after the current one.")

(defvar bs-khal--import-source-state nil
  "Calendar source state captured for the current import.")

(defvar bs-khal--last-import-state nil
  "Calendar source state captured for the last successful import.")

(defvar bs-khal--import-check-timer nil
  "Timer used to check whether calendar sources changed.")

(defun bs-khal--emacs-program ()
  "Return the Emacs executable used for background imports."
  (expand-file-name invocation-name invocation-directory))

(defun bs-khal--worker-form ()
  "Return the form evaluated by the background Emacs process."
  `(progn
     (require 'khalel)
     (setq khalel-import-end-date ,khalel-import-end-date
           khalel-import-format ,khalel-import-format
           khalel-import-org-file ,khalel-import-org-file
           khalel-import-org-file-confirm-overwrite nil
           khalel-import-org-file-header ,khalel-import-org-file-header
           khalel-import-org-file-read-only
           ,khalel-import-org-file-read-only
           khalel-import-start-date ,khalel-import-start-date
           khalel-khal-command ,khalel-khal-command
           khalel-khal-config ,khalel-khal-config)
     (khalel-import-events)))

(defun bs-khal--worker-command ()
  "Return the command used for the background import process."
  (let ((library (or (locate-library "khalel")
                     (error "Cannot locate the Khalel library"))))
    (list (bs-khal--emacs-program)
          "--batch"
          "--no-init-file"
          "--directory"
          (file-name-directory library)
          "--eval"
          (prin1-to-string (bs-khal--worker-form)))))

(defun bs-khal--source-state ()
  "Return a digest of the calendar sources and local date."
  (let (files)
    (dolist (directory bs-khal-calendar-directories)
      (when (file-directory-p directory)
        (setq files
              (nconc files
                     (ignore-errors
                       (directory-files-recursively
                        directory "\\.ics\\'"))))))
    (secure-hash
     'sha256
     (prin1-to-string
      (list
       1
       (format-time-string "%Y-%m-%d")
       (delq
        nil
        (mapcar
         (lambda (file)
           (when-let* ((attributes
                        (ignore-errors (file-attributes file))))
             (list file
                   (file-attribute-size attributes)
                   (file-attribute-modification-time attributes))))
         (delete-dups (sort files #'string-lessp)))))))))

(defun bs-khal--read-import-state ()
  "Return the persisted state of the last successful import."
  (when (file-readable-p bs-khal-import-state-file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents bs-khal-import-state-file)
          (read (current-buffer)))
      (error nil))))

(defun bs-khal--write-import-state (state)
  "Persist successful import STATE."
  (make-directory (file-name-directory bs-khal-import-state-file) t)
  (with-temp-file bs-khal-import-state-file
    (prin1 state (current-buffer))))

(defun bs-khal--refresh-buffers ()
  "Refresh buffers that display the imported calendar data."
  (when-let* ((buffer (find-buffer-visiting
                       khalel-import-org-file)))
    (with-current-buffer buffer
      (revert-buffer :ignore-auto :noconfirm)))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (cond
       ((derived-mode-p 'org-agenda-mode)
        (with-demoted-errors "Could not refresh Org Agenda: %S"
          (org-agenda-redo)))
       ((derived-mode-p 'calfw-calendar-mode)
        (with-demoted-errors "Could not refresh calfw: %S"
          (calfw-refresh-calendar-buffer)))))))

(defun bs-khal--import-sentinel (process _event)
  "Handle completion of background import PROCESS."
  (when (memq (process-status process) '(exit signal))
    (let ((buffer (process-buffer process))
          (pending bs-khal--import-pending)
          (source-state bs-khal--import-source-state)
          (success (and (eq (process-status process) 'exit)
                        (zerop (process-exit-status process)))))
      (setq bs-khal--import-pending nil
            bs-khal--import-process nil
            bs-khal--import-source-state nil)
      (if success
          (progn
            (setq bs-khal--last-import-state source-state)
            (with-demoted-errors "Could not persist calendar state: %S"
              (bs-khal--write-import-state source-state))
            (bs-khal--refresh-buffers)
            (when (buffer-live-p buffer)
              (kill-buffer buffer))
            (message "Calendar import finished")
            (when pending
              (bs-khal-import-events)))
        (display-warning
         'bs-khal
         (format "Calendar import failed with status %d; see %s"
                 (process-exit-status process)
                 (buffer-name buffer))
         :error)))))

;;;###autoload
(defun bs-khal-import-events ()
  "Import calendar events in a background Emacs process.

When an import is already running, queue one additional import so
that changes which arrive during the current run are not lost."
  (interactive)
  (if (process-live-p bs-khal--import-process)
      (progn
        (setq bs-khal--import-pending t)
        (message "Calendar import already running; queued another import"))
    (let ((buffer (get-buffer-create bs-khal-import-buffer-name)))
      (with-current-buffer buffer
        (erase-buffer))
      (setq bs-khal--import-source-state (bs-khal--source-state)
            bs-khal--import-process
            (make-process
             :name "bs-khal-import"
             :buffer buffer
             :command (bs-khal--worker-command)
             :connection-type 'pipe
             :noquery t
             :sentinel #'bs-khal--import-sentinel
             :stderr buffer))
      (message "Calendar import started in the background")))
  bs-khal--import-process)

(defun bs-khal--import-if-changed ()
  "Import calendar events when their source state changed."
  (when bs-khal-calendar-directories
    (let ((source-state (bs-khal--source-state)))
      (when (or (not (file-readable-p khalel-import-org-file))
                (not (equal source-state bs-khal--last-import-state)))
        (bs-khal-import-events)))))

(defun bs-khal--setup-import-check-timer ()
  "Configure the periodic calendar source check timer."
  (when (timerp bs-khal--import-check-timer)
    (cancel-timer bs-khal--import-check-timer))
  (setq bs-khal--import-check-timer nil
        bs-khal--last-import-state (bs-khal--read-import-state))
  (when (and bs-khal-calendar-directories
             (numberp bs-khal-import-check-interval)
             (> bs-khal-import-check-interval 0))
    (setq bs-khal--import-check-timer
          (run-at-time bs-khal-import-check-interval
                       bs-khal-import-check-interval
                       #'bs-khal--import-if-changed))))

;;;###autoload
(defun bs-khal-capture ()
  "Capture a new event for Khalel's default writable calendar."
  (interactive)
  (org-capture nil khalel-capture-key))

(defun bs-khal--after-export (success)
  "Start a background import after a successful export.

Return SUCCESS unchanged for the advised Khalel function."
  (when success
    (bs-khal-import-events))
  success)

(defun bs-khal--command-p (process program subcommand)
  "Return non-nil when PROCESS runs PROGRAM with SUBCOMMAND."
  (let ((command (process-command process)))
    (and command
         program
         (string=
          (file-name-nondirectory (car command))
          (file-name-nondirectory program))
         (member subcommand (cdr command)))))

(defun bs-khal--after-khalel-process (process _event)
  "Import events after a successful Khalel PROCESS finishes."
  (when (and (eq (process-status process) 'exit)
             (zerop (process-exit-status process))
             (or (bs-khal--command-p
                  process khalel-khal-command "edit")
                 (bs-khal--command-p
                  process khalel-vdirsyncer-command "sync")))
    (bs-khal-import-events)))

;;;###autoload
(defun bs-khal-setup ()
  "Configure Khalel to refresh calendars through background imports."
  (when bs-khal-default-calendar
    (setq khalel-default-calendar bs-khal-default-calendar))
  (khalel-add-capture-template)
  (bs-khal--setup-import-check-timer)
  (bs-khal--import-if-changed)
  (unless (advice-member-p
           #'bs-khal--after-export
           'khalel-export-org-subtree-to-calendar)
    (advice-add 'khalel-export-org-subtree-to-calendar
                :filter-return #'bs-khal--after-export))
  (unless (advice-member-p
           #'bs-khal--after-khalel-process
           'khalel--run-after-process)
    (advice-add 'khalel--run-after-process
                :after #'bs-khal--after-khalel-process)))

(provide 'bs-khal)
;;; bs-khal.el ends here
