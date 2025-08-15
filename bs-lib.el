;;; bs-lib.el --- Personal Extensions -*- lexical-binding: t; -*-

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

(require 'cl-lib)

(defun bs--genfn (sexp &optional prefix)
  "Convert SEXP into a function symbol.

The symbol name of function will use PREFIX, default to bs-fn-."
  (or prefix (setq prefix "bs-fn-"))
  (cond
   ((and (symbolp sexp)
         (fboundp sexp))
    sexp)
   ((and (eq (car-safe sexp) 'function)
         (symbolp (cadr sexp)))
    (cadr sexp))
   ((and (consp sexp)
         (eq (car sexp) 'lambda))
    (let ((sym (intern (format "%s" (gensym prefix)))))
      (fset sym (byte-compile sexp))))
   (t
    (let ((sym (intern (format "%s" (gensym prefix))))
          (fn (lambda (&rest args)
                (ignore args)
                (eval sexp))))
      (fset sym (byte-compile fn))
      sym))))

;;;###autoload
(defmacro bs-add-hook (hook &rest rest)
  "Add functions in REST to HOOK.

REST may contain function symbols, lambda functions and keywords that
describe how to `add-hook'.

Keywords can be :append and :local, with their values corresponding to
the APPEND and LOCAL parameters in the function `add-hook'."
  (declare (indent defun))
  (let* ((append (plist-get rest :append))
         (local (plist-get rest :local))
         (sexps (cl-loop for x
                         in rest
                         unless (keywordp x)
                         collect x)))
    `(dolist (sexp ',sexps)
       (add-hook ',hook (bs--genfn sexp) ,append ,local))))

;;;###autoload
(defmacro bs-add-hook* (hook &rest rest)
  "Add single-use functions in REST to HOOK.
See `bs-add-hook'."
  (declare (indent defun))
  (let* ((append (plist-get rest :append))
         (local  (plist-get rest :local))
         (sexps  (cl-loop for x
                          in rest
                          unless (keywordp x)
                          collect x)))
    `(dolist (sexp ',sexps)
       (let* ((fn (bs--genfn sexp))
              (h (intern (format "%s" (gensym "bs-fn-")))))
         (fset h
               (lambda ()
                 (funcall fn)
                 (remove-hook ',hook h ,local)))
         (add-hook ',hook h ,append ,local)))))

;;;###autoload
(defun bs-path (&rest segments)
  "Join SEGMENTS to a path."
  (let (file-name-handler-alist path)
    (setq path (expand-file-name (if (cdr segments)
                                     (apply #'file-name-concat
                                            segments)
                                   (car segments))))
    (if (file-name-absolute-p (car segments))
        path
      (file-relative-name path))))

;;;###autoload
(defun bs-path* (&rest segments)
  "Join SEGMENTS to a path, ensure it is exists."
  (let ((path (apply #'bs-path segments)) dir)
    (if (file-directory-p path)
        (setq dir path)
      (setq dir (file-name-directory path)))
    (make-directory dir 'parents)
    path))

(defun bs-silencing-message (func &rest args)
  "Silencing any message of FUNC, around with ARGS."
  (cl-letf (((symbol-function #'message) #'ignore))
    (apply func args)))

(provide 'bs-lib)
;;; bs.el ends here
