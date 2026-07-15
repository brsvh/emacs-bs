;;; bs.el --- Personal Emacs Lisp extensions -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Package-Requires: ((emacs "30.1") (ebdb "0.8.22") (mu4e "1.12.13") (org-vcard "0.3.1") (tabspaces "1.7"))
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

;; Personal Emacs Lisp extensions.

;;; Code:

(require 'bs-lib)
(require 'bs-ext)
(require 'bs-hooks)
(require 'bs-project)
(require 'bs-carddav)
(require 'bs-mu4e)

(provide 'bs)
;;; bs.el ends here
