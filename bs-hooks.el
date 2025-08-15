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

;;; Code:

;;
;; Load time:
;;

;;;###autoload
(progn
  (defvar bs-after-init-final-hook nil
    "Normal hook run at the end of `after-init-hook'.")

  (add-hook 'after-init-hook
            (lambda ()
              (run-hooks 'bs-after-init-final-hook))
            100))

(provide 'bs-hooks)
;;; bs-hooks.el ends here
