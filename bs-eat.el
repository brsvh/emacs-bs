;;; bs-eat.el --- Additional EAT Commands -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((emacs "30.1"))
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

;; This library extends `eat' with directory-aware and project-aware
;; session management.  It provides helpers for creating, locating,
;; reusing, and switching terminal buffers associated with the current
;; working context, while preferring predictable window placement and
;; practical buffer reuse for interactive terminal work.

;;; Code:

(require 'eat)
(require 'project)

(defun bs-eat--foreground-job-running-p (process)
  "Return non-nil when PROCESS currently owns a foreground job.

PROCESS is the process to inspect."
  (when-let* ((attributes (process-attributes (process-id process)))
              (process-group (alist-get 'pgrp attributes))
              (terminal-group (alist-get 'tpgid attributes)))
    (and (integerp process-group)
         (integerp terminal-group)
         (/= process-group terminal-group))))

(defun bs-eat--buffer-instance-number (buffer)
  "Return the numeric instance suffix for BUFFER.

BUFFER is the buffer to inspect."
  (if (string-match "<\\([0-9]+\\)>\\'" (buffer-name buffer))
      (string-to-number (match-string 1 (buffer-name buffer)))
    0))

(defun bs-eat--buffer-sort-p (buffer another-buffer)
  "Return non-nil when BUFFER should sort before ANOTHER-BUFFER.

BUFFER is the first buffer to compare.
ANOTHER-BUFFER is the second buffer to compare."
  (let ((buffer-number (bs-eat--buffer-instance-number buffer))
        (another-buffer-number
         (bs-eat--buffer-instance-number another-buffer)))
    (if (= buffer-number another-buffer-number)
        (string-lessp (buffer-name buffer)
                      (buffer-name another-buffer))
      (< buffer-number another-buffer-number))))

(defun bs-eat--eat-buffer-p (buffer)
  "Return non-nil when BUFFER is an Eat buffer.

BUFFER is the buffer to test."
  (with-current-buffer buffer
    (derived-mode-p 'eat-mode)))

(defun bs-eat--idle-buffer-p (buffer)
  "Return non-nil when BUFFER has a live idle Eat session.

BUFFER is the buffer to test."
  (when-let* ((process (get-buffer-process buffer)))
    (and (process-live-p process)
         (not (bs-eat--foreground-job-running-p process)))))

(defun bs-eat--normalize-directory (directory)
  "Return DIRECTORY as an expanded directory name.

DIRECTORY is the directory name to normalize."
  (file-name-as-directory (expand-file-name directory)))

(defun bs-eat--buffer-directory (buffer)
  "Return the normalized `default-directory' for BUFFER.

BUFFER is the buffer to inspect."
  (with-current-buffer buffer
    (bs-eat--normalize-directory default-directory)))

(defun bs-eat--buffer-names (buffers)
  "Return the names of BUFFERS.

BUFFERS is the list of buffers to name."
  (mapcar #'buffer-name buffers))

(defun bs-eat--read-buffer (prompt buffers)
  "Read an Eat buffer with PROMPT from BUFFERS.

PROMPT is the minibuffer prompt string.
BUFFERS is the list of candidate buffers."
  (unless buffers
    (user-error "No Eat buffers are available"))
  (get-buffer
   (completing-read prompt
                    (bs-eat--buffer-names buffers)
                    nil
                    t
                    nil
                    nil
                    (buffer-name (or (car buffers)
                                     (current-buffer))))))

(defun bs-eat--require-buffer (buffer buffers scope)
  "Return BUFFER from BUFFERS after validating SCOPE membership.

BUFFER is the buffer object or buffer name to validate.
BUFFERS is the list of candidate buffers.
SCOPE is the scope description for error messages."
  (let ((target (get-buffer buffer)))
    (unless (buffer-live-p target)
      (user-error "Buffer %S does not exist" buffer))
    (unless (memq target buffers)
      (user-error "Buffer %s is not associated with %s"
                  (buffer-name target)
                  scope))
    target))

(defun bs-eat--display-buffer (buffer &optional other-window)
  "Display BUFFER via `pop-to-buffer'.

BUFFER is the buffer to display.
When OTHER-WINDOW is non-nil, avoid reusing the selected window.
Window placement itself is delegated to user `display-buffer'
rules."
  (pop-to-buffer buffer
                 (and other-window
                      '(nil . ((inhibit-same-window . t)))))
  buffer)

(defun bs-eat--sort-buffers (buffers)
  "Return BUFFERS sorted by their Eat instance number."
  (sort (copy-sequence buffers) #'bs-eat--buffer-sort-p))

(defun bs-eat--process-live-p (buffer)
  "Return non-nil when BUFFER has a live process."
  (process-live-p (get-buffer-process buffer)))

(defun bs-eat--running-buffer-p (buffer)
  "Return non-nil when BUFFER has a live foreground job."
  (when-let* ((process (get-buffer-process buffer)))
    (and (process-live-p process)
         (bs-eat--foreground-job-running-p process))))

(defun bs-eat--exited-buffer-p (buffer)
  "Return non-nil when BUFFER no longer has a live process."
  (not (bs-eat--process-live-p buffer)))

(defun bs-eat--buffer-label (count &optional qualifier)
  "Return a human-readable buffer label for COUNT and QUALIFIER."
  (format "%s%s"
          (if qualifier
              (format "%s Eat buffer" qualifier)
            "Eat buffer")
          (if (= count 1) "" "s")))

(defun bs-eat--report-no-buffers (scope &optional qualifier)
  "Report that no Eat buffers for SCOPE match QUALIFIER."
  (message "No %s are associated with %s"
           (bs-eat--buffer-label 2 qualifier)
           scope))

(defun bs-eat--report-killed-buffers (killed total scope &optional qualifier)
  "Report that KILLED of TOTAL Eat buffers for SCOPE were removed.

QUALIFIER describes the kind of buffers that were targeted."
  (if (= killed total)
      (message "Killed %d %s for %s"
               killed
               (bs-eat--buffer-label killed qualifier)
               scope)
    (message "Killed %d of %d %s for %s"
             killed
             total
             (bs-eat--buffer-label total qualifier)
             scope)))

(defun bs-eat--bottom-window-p (window)
  "Return non-nil when WINDOW is at the bottom of its frame."
  (window-at-side-p window 'bottom))

(defun bs-eat--bottom-windows-for-buffer (buffer)
  "Return visible bottom windows currently displaying BUFFER."
  (seq-filter #'bs-eat--bottom-window-p
              (get-buffer-window-list buffer nil 'visible)))

(defun bs-eat--delete-windows-safely (windows)
  "Delete live WINDOWS, ignoring windows that cannot be deleted."
  (dolist (window windows)
    (when (window-live-p window)
      (ignore-errors
        (delete-window window)))))

(defun bs-eat--kill-buffer-no-query (buffer)
  "Kill BUFFER without running `process-kill-buffer-query-function'."
  (let ((bottom-windows (bs-eat--bottom-windows-for-buffer buffer)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((kill-buffer-query-functions
               (remq #'process-kill-buffer-query-function
                     kill-buffer-query-functions)))
          (when (kill-buffer buffer)
            (bs-eat--delete-windows-safely bottom-windows)))))))

(defun bs-eat--kill-buffers-no-query (buffers)
  "Kill BUFFERS without per-buffer process kill confirmation."
  (let (killed-buffers)
    (dolist (buffer buffers (nreverse killed-buffers))
      (when (bs-eat--kill-buffer-no-query buffer)
        (push buffer killed-buffers)))))

(defun bs-eat--clear-buffers-if (buffers scope qualifier predicate)
  "Kill BUFFERS for SCOPE that match PREDICATE.

QUALIFIER describes the kind of buffers being removed."
  (let* ((targets (seq-filter predicate (bs-eat--sort-buffers buffers)))
         (total (length targets)))
    (if (zerop total)
        (progn
          (bs-eat--report-no-buffers scope qualifier)
          nil)
      (let ((killed-buffers (bs-eat--kill-buffers-no-query targets)))
        (bs-eat--report-killed-buffers
         (length killed-buffers) total scope qualifier)
        killed-buffers))))

(defun bs-eat--confirm-buffer-kill (buffers running-buffers scope)
  "Confirm killing BUFFERS for SCOPE when RUNNING-BUFFERS is non-nil."
  (let ((total (length buffers))
        (running-count (length running-buffers)))
    (or (zerop running-count)
        (y-or-n-p
         (format "Kill %d %s for %s, including %d running process%s? "
                 total
                 (bs-eat--buffer-label total)
                 scope
                 running-count
                 (if (= running-count 1) "" "es"))))))

(defun bs-eat--kill-buffers (buffers scope)
  "Kill BUFFERS for SCOPE, confirming only once for running processes."
  (let* ((targets (bs-eat--sort-buffers buffers))
         (total (length targets))
         (running-buffers (seq-filter #'bs-eat--running-buffer-p targets)))
    (cond
     ((zerop total)
      (bs-eat--report-no-buffers scope)
      nil)
     ((not (bs-eat--confirm-buffer-kill targets running-buffers scope))
      (message "Canceled killing %d %s for %s"
               total
               (bs-eat--buffer-label total)
               scope)
      nil)
     (t
      (let ((killed-buffers (bs-eat--kill-buffers-no-query targets)))
        (bs-eat--report-killed-buffers (length killed-buffers) total scope)
        killed-buffers)))))

(defun bs-eat--first-idle-buffer (buffers)
  "Return the smallest-numbered idle buffer from BUFFERS.

BUFFERS is the list of candidate buffers."
  (car (sort (seq-filter #'bs-eat--idle-buffer-p
                         (copy-sequence buffers))
             #'bs-eat--buffer-sort-p)))

(defun bs-eat--switch-buffer (buffers scope &optional buffer)
  "Switch to BUFFER selected from BUFFERS for SCOPE.

BUFFERS is the list of candidate buffers.
SCOPE is the scope description for error messages.
BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (bs-eat--display-buffer
   (if buffer
       (bs-eat--require-buffer buffer buffers scope)
     (or (car buffers)
         (user-error "No Eat buffers are associated with %s"
                     scope)))))

(defun bs-eat--open-session (&optional project other-window)
  "Create a new Eat session for PROJECT.

PROJECT, when non-nil, is the project instance used for the session
root directory and buffer name.
When OTHER-WINDOW is non-nil, avoid reusing the selected window."
  (let* ((default-directory (if project
                                (project-root project)
                              default-directory))
         (eat-buffer-name (if project
                              (project-prefixed-buffer-name "eat")
                            eat-buffer-name)))
    (eat--1 nil t
            (lambda (buffer)
              (bs-eat--display-buffer buffer other-window)))))

(defun bs-eat--reuse-or-open (buffers open-command)
  "Reuse or create an Eat session from BUFFERS with OPEN-COMMAND.

BUFFERS is the list of candidate buffers.
OPEN-COMMAND is the command used to create a new session when no
idle buffer is available."
  (if-let* ((buffer (bs-eat--first-idle-buffer buffers)))
      (bs-eat--display-buffer buffer)
    (funcall open-command)))

(defun bs-eat-directory-buffers ()
  "Return the Eat buffers associated with the current directory."
  (let ((directory (bs-eat--normalize-directory default-directory))
        buffers)
    (dolist (buffer (buffer-list) (nreverse buffers))
      (when (and (bs-eat--eat-buffer-p buffer)
                 (string=
                  directory
                  (bs-eat--buffer-directory buffer)))
        (push buffer buffers)))))

(defun bs-eat-project-buffers ()
  "Return the Eat buffers associated with the current project."
  (let (project-current-directory-override)
    (let ((project (project-current nil))
          buffers)
      (when project
        (dolist (buffer (project-buffers project) (nreverse buffers))
          (when (bs-eat--eat-buffer-p buffer)
            (push buffer buffers)))))))

;;;###autoload
(defun bs/eat-switch (&optional buffer)
  "Switch to an Eat BUFFER associated with the current directory.

BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (interactive
   (list (bs-eat--read-buffer "Switch to Eat buffer: "
                              (bs-eat-directory-buffers))))
  (bs-eat--switch-buffer (bs-eat-directory-buffers)
                         "the current directory"
                         buffer))

;;;###autoload
(defun bs/eat-project-switch (&optional buffer)
  "Switch to an Eat BUFFER associated with the current project.

BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (interactive
   (list (bs-eat--read-buffer "Switch to project Eat buffer: "
                              (bs-eat-project-buffers))))
  (bs-eat--switch-buffer (bs-eat-project-buffers)
                         "the current project"
                         buffer))

;;;###autoload
(defun bs/eat-clear-buffers ()
  "Kill exited Eat buffers associated with the current directory."
  (interactive)
  (bs-eat--clear-buffers-if (bs-eat-directory-buffers)
                            "the current directory"
                            "exited"
                            #'bs-eat--exited-buffer-p))

;;;###autoload
(defun bs/eat-clear-idle-buffers ()
  "Kill idle Eat buffers associated with the current directory."
  (interactive)
  (bs-eat--clear-buffers-if (bs-eat-directory-buffers)
                            "the current directory"
                            "idle"
                            #'bs-eat--idle-buffer-p))

;;;###autoload
(defun bs/eat-kill-buffers ()
  "Kill Eat buffers associated with the current directory.

When any associated buffer has a running process, ask only once
before killing all of them."
  (interactive)
  (bs-eat--kill-buffers (bs-eat-directory-buffers)
                        "the current directory"))

;;;###autoload
(defun bs/eat-project-clear-buffers ()
  "Kill exited Eat buffers associated with the current project."
  (interactive)
  (bs-eat--clear-buffers-if (bs-eat-project-buffers)
                            "the current project"
                            "exited"
                            #'bs-eat--exited-buffer-p))

;;;###autoload
(defun bs/eat-project-clear-idle-buffers ()
  "Kill idle Eat buffers associated with the current project."
  (interactive)
  (bs-eat--clear-buffers-if (bs-eat-project-buffers)
                            "the current project"
                            "idle"
                            #'bs-eat--idle-buffer-p))

;;;###autoload
(defun bs/eat-project-kill-buffers ()
  "Kill Eat buffers associated with the current project.

When any associated buffer has a running process, ask only once
before killing all of them."
  (interactive)
  (bs-eat--kill-buffers (bs-eat-project-buffers)
                        "the current project"))

;;;###autoload
(defun bs/eat-open ()
  "Start a new Eat session for the current directory."
  (interactive)
  (bs-eat--open-session))

;;;###autoload
(defun bs/eat-open-other-window ()
  "Start a new Eat session for the current directory in another window."
  (interactive)
  (bs-eat--open-session nil t))

;;;###autoload
(defun bs/eat-project-open ()
  "Start a new Eat session for the current project."
  (interactive)
  (bs-eat--open-session (project-current t)))

;;;###autoload
(defun bs/eat-project-open-other-window ()
  "Start a new Eat session for the current project in another window."
  (interactive)
  (bs-eat--open-session (project-current t) t))

;;;###autoload
(defun bs/eat-dwim ()
  "Reuse an idle Eat session for the current directory or create one."
  (interactive)
  (bs-eat--reuse-or-open (bs-eat-directory-buffers)
                         #'bs/eat-open-other-window))

;;;###autoload
(defun bs/eat-project-dwim ()
  "Reuse an idle Eat session for the current project or create one."
  (interactive)
  (bs-eat--reuse-or-open (bs-eat-project-buffers)
                         #'bs/eat-project-open-other-window))

(provide 'bs-eat)
;;; bs-eat.el ends here
