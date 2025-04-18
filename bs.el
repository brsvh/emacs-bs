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
(require 'xdg)

;;;###autoload
(defgroup bs nil
  "Customize Bingshan's Emacs Configuration."
  :prefix "bs-"
  :group 'emacs)

;;;###autoload
(defcustom bs-cache-directory (bs-path "emacs/" (xdg-cache-home))
  "Directory beneath which additional volatile files are placed."
  :group 'bs
  :type 'directory)

;;;###autoload
(defcustom bs-config-directory (bs-path "emacs/" (xdg-config-home))
  "Directory beneath which additional config files are placed."
  :type 'directory
  :group 'bs)

;;;###autoload
(defcustom bs-data-directory (bs-path "emacs/" (xdg-data-home))
  "Directory beneath which additional non-volatile files are placed."
  :group 'bs
  :type 'directory)

;;;###autoload
(defcustom bs-state-directory (bs-path "emacs/" (xdg-state-home))
  "Directory beneath which additional state files are placed."
  :group 'bs
  :type 'directory)

(provide 'bs)
;;; bs.el ends here
