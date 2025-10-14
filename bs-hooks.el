;;; bs-hooks.el --- Personal Hooks -*- lexical-binding: t; -*-

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

;; Just some custom hooks.

;; `bs-first-buffer-hook', `bs-first-file-hook', `bs-first-input-hook'
;; and `bs-first-ui-hook' source code originates from `on', with the
;; conceptual inspiration drawn from Doom Emacs.

;;; Code:

(defvar bs-after-init-final-hook nil
  "Normal hook run at the end of `after-init-hook'.")

;;;###autoload
(defun run-bs-after-init-final-hook (&rest _)
  "Run `bs-after-init-final-hook'."
  (run-hooks 'bs-after-init-final-hook))

(defvar bs-first-buffer-hook nil
  "Transient hooks run before the first opened buffer.")

;;;###autoload
(defun run-bs-first-buffer-hook (&rest _)
  "Run `bs-first-buffer-hook'."
  (run-hooks 'bs-first-buffer-hook)
  (advice-remove 'after-find-file 'run-bs-first-buffer-hook)
  (remove-hook 'window-buffer-change-functions 'run-bs-first-buffer-hook)
  (remove-hook 'server-visit-hook 'run-bs-first-buffer-hook))

(defvar bs-first-file-hook nil
  "Transient hooks run before the first opened file.")

;;;###autoload
(defun run-bs-first-file-hook (&rest _)
  "Run `bs-first-file-hook'."
  (run-hooks 'bs-first-file-hook)
  (advice-remove 'after-find-file 'run-bs-first-file-hook)
  (remove-hook 'dired-initial-position-hook 'run-bs-first-file-hook))

(defvar bs-first-input-hook nil
  "Transient hooks run before the first user input.")

;;;###autoload
(defun run-bs-first-input-hook (&rest _)
  "Run `bs-first-input-hook'."
  (run-hooks 'bs-first-input-hook)
  (remove-hook 'pre-command-hook 'run-bs-first-input-hook))

(defvar bs-first-ui-hook nil
  "Transient hooks when the UI has been initialized.")

;;;###autoload
(defun run-bs-first-ui-hook (&rest _)
  "Run `bs-first-ui-hook'."
  (run-hooks 'bs-first-ui-hook)
  (remove-hook 'server-after-make-frame-hook 'run-bs-first-ui-hook)
  (remove-hook 'after-init-hook 'run-bs-first-ui-hook))

;;;###autoload
(progn
  (add-hook 'after-init-hook 'run-bs-after-init-final-hook 100)

  (if (daemonp)
      (add-hook 'server-after-make-frame-hook 'run-bs-first-ui-hook)
    (add-hook 'after-init-hook 'run-bs-first-ui-hook))

  (add-hook 'window-setup-hook
            #'(lambda ()
                (advice-add 'after-find-file :before #'run-bs-first-buffer-hook)
                (advice-add 'after-find-file :before #'run-bs-first-file-hook)

                (add-hook 'window-buffer-change-functions 'run-bs-first-buffer-hook)
                (add-hook 'dired-initial-position-hook 'run-bs-first-file-hook)
                (add-hook 'pre-command-hook 'run-bs-first-input-hook))
            -100)

  (add-hook 'server-visit-hook 'run-bs-first-buffer-hook))

(provide 'bs-hooks)
;;; bs-hooks.el ends here
