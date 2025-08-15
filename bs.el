;;; bs.el --- Personal Extensions -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2025 Bingshan Chang

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

;; These are extensions that provide additional features to support my
;; personal Emacs configuration.

;;; Code:

(require 'bs-lib)
(require 'simple)
(require 'tabify)

(defgroup bs nil
  "Customize Bingshan's Emacs Configuration."
  :prefix "bs-"
  :group 'emacs)

;;;###autoload
(defcustom bs-cache-directory (expand-file-name "~/.cache/emacs/")
  "Directory beneath which additional volatile files are placed."
  :group 'bs
  :type 'directory)

;;;###autoload
(defcustom bs-config-directory (expand-file-name "~/.config/emacs/")
  "Directory beneath which additional config files are placed."
  :type 'directory
  :group 'bs)

;;;###autoload
(defcustom bs-data-directory (expand-file-name "~/.local/share/emacs/")
  "Directory beneath which additional non-volatile files are placed."
  :group 'bs
  :type 'directory)

;;;###autoload
(defcustom bs-state-directory (expand-file-name "~/.local/state/emacs/")
  "Directory beneath which additional state files are placed."
  :group 'bs
  :type 'directory)

;;;###autoload
(defun bs/server-start ()
  "Allow this Emacs process to be a server for client processes."
  (interactive)
  (eval-and-compile
    (require 'server))
  (unless (server-running-p) (server-start)))

;;;###autoload
(defun bs/delete-trailing-whitespace (&optional buffer)
  "Delete trailing whitespaces in BUFFER."
  (interactive "bBuffer: ")
  (let ((buffer (or buffer (current-buffer))))
    (with-current-buffer (get-buffer buffer)
      (delete-trailing-whitespace (point-min) (point-max)))))

;;;###autoload
(defun bs/untabify (&optional buffer)
  "Do `untabify' in BUFFER."
  (interactive "bBuffer: ")
  (let ((buffer (or buffer (current-buffer))))
    (with-current-buffer (get-buffer buffer)
      (untabify (point-min) (point-max)))))

;;;###autoload
(defun bs/guess-buffer-major-mode (&optional buffer)
  "Guess the major mode of a BUFFER."
  (interactive "bBuffer: ")
  (let ((buffer (or buffer (current-buffer))))
    (with-current-buffer (get-buffer buffer)
      (and (set-auto-mode)
           (not (eq major-mode 'fundamental-mode))))))

;;;###autoload
(defun bs/guess-file-major-mode (&optional buffer)
  "Guess the major mode of a BUFFER.

The BUFFER must be saved in a file."
  (interactive "bBuffer: ")
  (let ((buffer (or buffer (current-buffer))))
    (with-current-buffer (get-buffer buffer)
      (and (buffer-file-name (get-buffer buffer))
           (bs/guess-buffer-major-mode buffer)))))

(provide 'bs)
;;; bs.el ends here
