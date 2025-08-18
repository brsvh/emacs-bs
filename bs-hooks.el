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
;; and `bs-init-ui-hook' source code originates from `on', with the
;; conceptual inspiration drawn from Doom Emacs.

;;; Code:

;;
;; Load time:
;;

;;;###autoload
(eval-and-compile
  (require 'bs-lib)

  (defvar bs-after-init-final-hook nil
    "Normal hook run at the end of `after-init-hook'.")

  (bs-add-hook after-init-hook :append 100
    (run-hooks 'bs-after-init-final-hook))

  (defvar bs-first-buffer-hook nil
    "Transient hooks run before the first opened buffer.")

  (defun bs-first-buffer-helper (&rest _)
    "Helper for run `bs-first-buffer-hook'."
    (run-hooks 'bs-first-buffer-hook)
    (advice-remove 'after-find-file 'bs-first-buffer-helper)
    (remove-hook 'window-buffer-change-functions
                 'bs-first-buffer-helper)
    (remove-hook 'server-visit-hook 'bs-first-buffer-helper))

  (defvar bs-first-file-hook nil
    "Transient hooks run before the first opened file.")

  (defun bs-first-file-helper (&rest _)
    "Helper for run `bs-first-file-hook'."
    (run-hooks 'bs-first-file-hook)
    (advice-remove 'after-find-file 'bs-first-file-helper)
    (remove-hook 'dired-initial-position-hook 'bs-first-file-helper))

  (defvar bs-first-input-hook nil
    "Transient hooks run before the first user input.")

  (defun bs-first-input-helper (&rest _)
    "Helper for run `bs-first-input-hook'."
    (run-hooks 'bs-first-input-hook)
    (remove-hook 'pre-command-hook 'bs-first-input-helper))

  (defvar bs-init-ui-hook nil
    "Transient hooks when the UI has been initialized.")

  (defun bs-init-ui-helper (&rest _)
    "Helper for run `bs-init-ui-hook'."
    (run-hooks 'bs-init-ui-hook)
    (remove-hook 'server-after-make-frame-hook #'bs-init-ui-helper)
    (remove-hook 'after-init-hook #'bs-init-ui-helper))

  (if (daemonp)
      (bs-add-hook server-after-make-frame-hook bs-init-ui-helper)
    (bs-add-hook after-init-hook bs-init-ui-helper))

  (bs-add-hook window-setup-hook :append -100
    (bs-add-advice after-find-file
      :before bs-first-buffer-helper
      :before bs-first-file-helper)
    (bs-add-hook window-buffer-change-functions bs-first-buffer-helper)
    (bs-add-hook dired-initial-position-hook bs-first-file-helper)
    (bs-add-hook pre-command-hook bs-first-input-helper))

  (bs-add-hook server-visit-hook bs-first-buffer-helper))

(provide 'bs-hooks)
;;; bs-hooks.el ends here
