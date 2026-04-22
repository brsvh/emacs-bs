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

(defun bs-eat--process-foreground-busy-p (process)
  "Return non-nil when PROCESS is occupied by a foreground child.

PROCESS is the process to inspect."
  (when-let* ((attributes (process-attributes (process-id process)))
              (process-group (alist-get 'pgrp attributes))
              (terminal-group (alist-get 'tpgid attributes)))
    (and (integerp process-group)
         (integerp terminal-group)
         (/= process-group terminal-group))))

(defun bs-eat--buffer-number (buffer)
  "Return the numeric suffix for BUFFER.

BUFFER is the buffer to inspect."
  (if (string-match "<\\([0-9]+\\)>\\'" (buffer-name buffer))
      (string-to-number (match-string 1 (buffer-name buffer)))
    0))

(defun bs-eat--buffer-less-p (buffer another-buffer)
  "Return non-nil when BUFFER sorts before ANOTHER-BUFFER.

BUFFER is the first buffer to compare.
ANOTHER-BUFFER is the second buffer to compare."
  (let ((buffer-number (bs-eat--buffer-number buffer))
        (another-buffer-number (bs-eat--buffer-number another-buffer)))
    (if (= buffer-number another-buffer-number)
        (string-lessp (buffer-name buffer)
                      (buffer-name another-buffer))
      (< buffer-number another-buffer-number))))

(defun bs-eat--buffer-p (buffer)
  "Return non-nil when BUFFER is an Eat buffer.

BUFFER is the buffer to test."
  (with-current-buffer buffer
    (derived-mode-p 'eat-mode)))

(defun bs-eat--buffer-busy-p (buffer)
  "Return non-nil when BUFFER is occupied by a running command.

BUFFER is the buffer to test."
  (when-let* ((process (get-buffer-process buffer)))
    (and (process-live-p process)
         (bs-eat--process-foreground-busy-p process))))

(defun bs-eat--buffer-idle-p (buffer)
  "Return non-nil when BUFFER has a live idle Eat session.

BUFFER is the buffer to test."
  (when-let* ((process (get-buffer-process buffer)))
    (and (process-live-p process)
         (not (bs-eat--process-foreground-busy-p process)))))

(defun bs-eat--directory (directory)
  "Return DIRECTORY as an expanded directory name.

DIRECTORY is the directory name to normalize."
  (file-name-as-directory (expand-file-name directory)))

(defun bs-eat--buffer-directory (buffer)
  "Return the normalized `default-directory' for BUFFER.

BUFFER is the buffer to inspect."
  (with-current-buffer buffer
    (bs-eat--directory default-directory)))

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

(defun bs-eat--match-buffer (buffer buffers scope)
  "Return BUFFER from BUFFERS associated with SCOPE.

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

(defun bs-eat--window-usable-p (window &optional buffer)
  "Return non-nil when WINDOW can safely display BUFFER.

WINDOW is the window to test.
BUFFER, when non-nil, is the buffer object to display."
  (and (window-live-p window)
       (or (eq (window-buffer window) buffer)
           (not (window-dedicated-p window)))))

(defun bs-eat--window (&optional buffer)
  "Return a visible Eat window, preferring BUFFER when non-nil.

BUFFER, when non-nil, is the buffer object to prefer."
  (or (and buffer
           (let ((window (get-buffer-window buffer)))
             (and (bs-eat--window-usable-p window buffer)
                  window)))
      (catch 'found
        (walk-windows
         (lambda (window)
           (when (and (bs-eat--buffer-p (window-buffer window))
                      (bs-eat--window-usable-p window buffer))
             (throw 'found window)))
         'no-minibuf)
        nil)))

(defun bs-eat--display-in-window (buffer window)
  "Display BUFFER in WINDOW and select WINDOW.

BUFFER is the buffer object to display.
WINDOW is the window used to display BUFFER."
  (unless (eq (window-buffer window) buffer)
    (set-window-buffer window buffer))
  (select-window window)
  buffer)

(defun bs-eat--dwim-display-buffer (buffer)
  "Display BUFFER using the current Eat DWIM window strategy.

BUFFER is the buffer to display."
  (if-let* ((window (bs-eat--window buffer)))
      (bs-eat--display-in-window buffer window)
    (switch-to-buffer-other-window buffer)))

(defun bs-eat--dwim-buffer (buffers)
  "Return the smallest-numbered idle buffer from BUFFERS.

BUFFERS is the list of candidate buffers."
  (car (sort (seq-filter #'bs-eat--buffer-idle-p
                         (copy-sequence buffers))
             #'bs-eat--buffer-less-p)))

(defun bs-eat--switch-to-buffer (buffers scope &optional buffer)
  "Switch to BUFFER selected from BUFFERS for SCOPE.

BUFFERS is the list of candidate buffers.
SCOPE is the scope description for error messages.
BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (switch-to-buffer
   (if buffer
       (bs-eat--match-buffer buffer buffers scope)
     (or (car buffers)
         (user-error "No Eat buffers are associated with %s"
                     scope)))))

(defun bs-eat--start (display-buffer-fn &optional project)
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

(defun bs-eat--current-project ()
  "Return the current project.

The return value is the current project instance from
`project-current'."
  (project-current t))

(defun bs-eat--dwim (buffers command other-window-command)
  "Reuse or create an Eat session from BUFFERS using COMMAND.

BUFFERS is the list of candidate buffers.
COMMAND is the command used to create a same-window session.
OTHER-WINDOW-COMMAND is the command used to create an other-window
session."
  (if-let* ((buffer (bs-eat--dwim-buffer buffers)))
      (bs-eat--dwim-display-buffer buffer)
    (if-let* ((window (bs-eat--window)))
        (with-selected-window window
          (funcall command))
      (funcall other-window-command))))

(defun bs-eat-list-buffers ()
  "Return the Eat buffers associated with the current directory."
  (let ((directory (bs-eat--directory default-directory))
        buffers)
    (dolist (buffer (buffer-list) (nreverse buffers))
      (when (and (bs-eat--buffer-p buffer)
                 (string=
                  directory
                  (bs-eat--buffer-directory buffer)))
        (push buffer buffers)))))

(defun bs-eat-project-list-buffers ()
  "Return the Eat buffers associated with the current project."
  (let (project-current-directory-override)
    (let ((project (project-current nil))
          buffers)
      (when project
        (dolist (buffer (project-buffers project) (nreverse buffers))
          (when (bs-eat--buffer-p buffer)
            (push buffer buffers)))))))

;;;###autoload
(defun bs/eat-switch-to-buffer (&optional buffer)
  "Switch to an Eat BUFFER associated with the current directory.

BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (interactive
   (list (bs-eat--read-buffer "Switch to Eat buffer: "
                              (bs-eat-list-buffers))))
  (bs-eat--switch-to-buffer (bs-eat-list-buffers)
                            "the current directory"
                            buffer))

;;;###autoload
(defun bs/eat-project-switch-to-buffer (&optional buffer)
  "Switch to an Eat BUFFER associated with the current project.

BUFFER, when non-nil, is the buffer object or buffer name to
switch to."
  (interactive
   (list (bs-eat--read-buffer "Switch to project Eat buffer: "
                              (bs-eat-project-list-buffers))))
  (bs-eat--switch-to-buffer (bs-eat-project-list-buffers)
                            "the current project"
                            buffer))

;;;###autoload
(defun bs/eat ()
  "Start a new Eat session for the current directory."
  (interactive)
  (bs-eat--start #'pop-to-buffer-same-window))

;;;###autoload
(defun bs/eat-other-window ()
  "Start a new Eat session for the current directory in another window."
  (interactive)
  (bs-eat--start #'switch-to-buffer-other-window))

;;;###autoload
(defun bs/eat-project ()
  "Start a new Eat session for the current project."
  (interactive)
  (bs-eat--start #'pop-to-buffer-same-window
                 (bs-eat--current-project)))

;;;###autoload
(defun bs/eat-project-other-window ()
  "Start a new Eat session for the current project in another window."
  (interactive)
  (bs-eat--start #'switch-to-buffer-other-window
                 (bs-eat--current-project)))

;;;###autoload
(defun bs/eat-dwim ()
  "Reuse an idle Eat session for the current directory or create one."
  (interactive)
  (bs-eat--dwim (bs-eat-list-buffers)
                #'bs/eat
                #'bs/eat-other-window))

;;;###autoload
(defun bs/eat-project-dwim ()
  "Reuse an idle Eat session for the current project or create one."
  (interactive)
  (bs-eat--dwim (bs-eat-project-list-buffers)
                #'bs/eat-project
                #'bs/eat-project-other-window))

(provide 'bs-eat)
;;; bs-eat.el ends here
