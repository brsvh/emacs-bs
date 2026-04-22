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

(defun bs-eat--reusable-window-p (window &optional buffer)
  "Return non-nil when WINDOW can safely display BUFFER.

WINDOW is the window to test.
BUFFER, when non-nil, is the buffer object to display."
  (and (window-live-p window)
       (or (eq (window-buffer window) buffer)
           (not (window-dedicated-p window)))))

(defun bs-eat--find-window (&optional buffer)
  "Return a visible Eat window, preferring BUFFER when non-nil.

BUFFER, when non-nil, is the buffer object to prefer."
  (or (and buffer
           (let ((window (get-buffer-window buffer)))
             (and (bs-eat--reusable-window-p window buffer)
                  window)))
      (catch 'found
        (walk-windows
         (lambda (window)
           (when (and (bs-eat--eat-buffer-p (window-buffer window))
                      (bs-eat--reusable-window-p window buffer))
             (throw 'found window)))
         'no-minibuf)
        nil)))

(defun bs-eat--show-in-window (buffer window)
  "Display BUFFER in WINDOW and select WINDOW.

BUFFER is the buffer object to display.
WINDOW is the window used to display BUFFER."
  (unless (eq (window-buffer window) buffer)
    (set-window-buffer window buffer))
  (select-window window)
  buffer)

(defun bs-eat--show-buffer (buffer)
  "Display BUFFER using the current Eat window preference.

BUFFER is the buffer to display."
  (if-let* ((window (bs-eat--find-window buffer)))
      (bs-eat--show-in-window buffer window)
    (switch-to-buffer-other-window buffer)))

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
  (switch-to-buffer
   (if buffer
       (bs-eat--require-buffer buffer buffers scope)
     (or (car buffers)
         (user-error "No Eat buffers are associated with %s"
                     scope)))))

(defun bs-eat--open-session (display-buffer-fn &optional project)
  "Create a new Eat session with DISPLAY-BUFFER-FN and PROJECT.

DISPLAY-BUFFER-FN is a function that displays the new Eat buffer.
PROJECT, when non-nil, is the project instance used for the session
root directory and buffer name."
  (let* ((default-directory (if project
                                (project-root project)
                              default-directory))
         (eat-buffer-name (if project
                              (project-prefixed-buffer-name "eat")
                            eat-buffer-name)))
    (eat--1 nil t display-buffer-fn)))

(defun bs-eat--reuse-or-open (buffers command other-window-command)
  "Reuse or create an Eat session from BUFFERS using COMMAND.

BUFFERS is the list of candidate buffers.
COMMAND is the command used to create a same-window session.
OTHER-WINDOW-COMMAND is the command used to create an other-window
session."
  (if-let* ((buffer (bs-eat--first-idle-buffer buffers)))
      (bs-eat--show-buffer buffer)
    (if-let* ((window (bs-eat--find-window)))
        (with-selected-window window
          (funcall command))
      (funcall other-window-command))))

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
(defun bs/eat-open ()
  "Start a new Eat session for the current directory."
  (interactive)
  (bs-eat--open-session #'pop-to-buffer-same-window))

;;;###autoload
(defun bs/eat-open-other-window ()
  "Start a new Eat session for the current directory in another window."
  (interactive)
  (bs-eat--open-session #'switch-to-buffer-other-window))

;;;###autoload
(defun bs/eat-project-open ()
  "Start a new Eat session for the current project."
  (interactive)
  (bs-eat--open-session #'pop-to-buffer-same-window
                        (project-current t)))

;;;###autoload
(defun bs/eat-project-open-other-window ()
  "Start a new Eat session for the current project in another window."
  (interactive)
  (bs-eat--open-session #'switch-to-buffer-other-window
                        (project-current t)))

;;;###autoload
(defun bs/eat-dwim ()
  "Reuse an idle Eat session for the current directory or create one."
  (interactive)
  (bs-eat--reuse-or-open (bs-eat-directory-buffers)
                         #'bs/eat-open
                         #'bs/eat-open-other-window))

;;;###autoload
(defun bs/eat-project-dwim ()
  "Reuse an idle Eat session for the current project or create one."
  (interactive)
  (bs-eat--reuse-or-open (bs-eat-project-buffers)
                         #'bs/eat-project-open
                         #'bs/eat-project-open-other-window))

(provide 'bs-eat)
;;; bs-eat.el ends here
