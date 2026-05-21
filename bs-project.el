;;; bs-project.el --- Project integration  -*- lexical-binding:t -*-

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

;; This package integrates `project' commands with tabspaces
;; workspaces.

;;; Code:

(require 'cl-lib)
(require 'project)

(declare-function tabspaces--current-tab-name "tabspaces")
(declare-function tabspaces--get-project-for-tab "tabspaces")
(declare-function tabspaces--list-tabspaces "tabspaces")
(declare-function tabspaces-generate-descriptive-tab-name "tabspaces")

(defvar tabspaces-project-tab-map)

(defun bs-project-directory-normalizer (directory)
  "Return DIRECTORY as an expanded directory name."
  (file-name-as-directory (expand-file-name directory)))

(defun bs-project-same-project-p (directory another-directory)
  "Return non-nil when DIRECTORY and ANOTHER-DIRECTORY same name."
  (and directory
       another-directory
       (string= (bs-project-directory-normalizer directory)
                (bs-project-directory-normalizer another-directory))))

(defun bs-project-directory (project)
  "Return the normalized root directory for PROJECT."
  (bs-project-directory-normalizer (project-root project)))

(defun bs-project-current-buffer-project-directory ()
  "Return the project directory for the current buffer."
  (let (project-current-directory-override)
    (when-let* ((project (project-current nil)))
      (bs-project-directory project))))

(defun bs-project-current-tab-project-directory ()
  "Return the project directory associated with the current tab."
  (when-let* ((directory (tabspaces--get-project-for-tab
                          (tabspaces--current-tab-name))))
    (bs-project-directory-normalizer directory)))

(defun bs-project-tab-name (project-directory)
  "Return the tab name recorded for PROJECT-DIRECTORY."
  (cl-loop for (directory . tab-name) in tabspaces-project-tab-map
           when (bs-project-same-project-p directory
                                           project-directory)
           return tab-name))

(defun bs-project-remember-project-tab (project-directory tab-name)
  "Associate PROJECT-DIRECTORY with TAB-NAME."
  (setq tabspaces-project-tab-map
        (cons (cons project-directory tab-name)
              (cl-remove-if
               (lambda (entry)
                 (bs-project-same-project-p
                  (car entry)
                  project-directory))
               tabspaces-project-tab-map))))

(defun bs-project-switch-to-project-workspace (project)
  "Switch to or create the tabspaces workspace for PROJECT."
  (let ((project-directory (bs-project-directory project)))
    (unless (or (bs-project-same-project-p
                 (bs-project-current-tab-project-directory)
                 project-directory)
                (bs-project-same-project-p
                 (bs-project-current-buffer-project-directory)
                 project-directory))
      (let* ((existing-tab-names (tabspaces--list-tabspaces))
             (tab-name (or (bs-project-tab-name
                            project-directory)
                           (tabspaces-generate-descriptive-tab-name
                            project-directory
                            existing-tab-names))))
        (if (member tab-name existing-tab-names)
            (tab-bar-switch-to-tab tab-name)
          (tab-bar-new-tab)
          (tab-bar-rename-tab tab-name))
        (bs-project-remember-project-tab project-directory tab-name)))))

;;;###autoload
(defun bs-project-find-file (&optional include-all)
  "Visit a project file from that project's tabspaces workspace.

If INCLUDE-ALL is non-nil, include all files under the project
root, except VCS directories listed in `vc-directory-exclusion-list'."
  (interactive "P")
  (let* ((project (project-current t))
         (root (project-root project))
         (suggested-filename
          (delq nil
                (list (and buffer-file-name
                           (project--find-default-from buffer-file-name
                                                       project))
                      (thing-at-point 'filename)))))
    (bs-project-switch-to-project-workspace project)
    (let ((project-files-relative-names t))
      (project-find-file-in suggested-filename
                            (list root)
                            project
                            include-all))))

(provide 'bs-project)
;;; bs-project.el ends here
