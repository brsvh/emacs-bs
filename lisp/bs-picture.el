;;; bs-picture.el --- Text drawing helpers  -*- lexical-binding:t -*-

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

;; Temporarily adapt filling and display settings for `picture'.

;;; Code:

(require 'face-remap)

(defvar-local bs-picture--state nil
  "Saved filling, wrapping and face state before drawing text.")

;;;###autoload
(defun bs-picture-setup ()
  "Prepare fixed-pitch text drawing and save previous settings."
  (unless bs-picture--state
    (setq bs-picture--state
          (list (local-variable-p 'auto-fill-function)
                auto-fill-function
                visual-line-mode
                (face-remap-add-relative 'default 'fixed-pitch)))
    (setq-local auto-fill-function nil)
    (when visual-line-mode
      (visual-line-mode -1)
      ;; Disabling wrapping restores its old value of this variable.
      (setq-local truncate-lines t))))

;;;###autoload
(defun bs-picture-restore ()
  "Restore filling, wrapping and faces saved before drawing."
  (when bs-picture--state
    (pcase-let ((`(,local ,fill ,wrap ,face)
                 bs-picture--state))
      (setq bs-picture--state nil)
      (face-remap-remove-relative face)
      (when wrap
        (visual-line-mode 1))
      (if local
          (setq-local auto-fill-function fill)
        (kill-local-variable 'auto-fill-function)))))

(provide 'bs-picture)
;;; bs-picture.el ends here
