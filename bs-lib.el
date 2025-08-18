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

(defun bs--advice-name (target &optional name)
  "Intern a readable, unique advice symbol like TARGET@NAME."
  (or name (setq name (gensym "bs-fn-")))
  (let* ((target-name (if (symbolp target)
                          (symbol-name target)
                        (format "%s" target)))
         (full-name  (format "%s@%s" target-name name)))
    (intern full-name)))


(defconst bs--advice-hows '(:after
                            :after-until
                            :after-while
                            :around
                            :before
                            :before-until
                            :before-while
                            :filter-args
                            :filter-return
                            :override)
  "HOW keywords for `bs-add-advice' and `bs-add-advice*'.")

(defun bs--advice-list-how-form (plist)
  "Construct the list of (HOW . FORM) from PLIST.

FORM must be a function symbol or a lambda function follow the arguments
requirement of HOW."
  (let (result)
    (while plist
      (let ((how (pop plist))
            (form (pop plist)))
        (unless (memq how bs--advice-hows)
          (error "Unknown advice how: %S" k))
        (cond
         ((and (consp form)
               (eq (car form) 'function)
               (symbolp (cadr form)))
          (push (cons how (cadr spec)) result))
         ((and (symbolp form)
               (fboundp form))
          (push (cons how form) result))
         ((and (consp form)
               (eq (car form) 'lambda))
          (push (cons how form) result))
         (t
          (error "FORM must be a function or lambda function, got: %S"
                 form)))))
    (nreverse result)))

;;;###autoload
(defmacro bs-add-advice (target &rest how-form-list)
  "Add multiple advices (HOW-FORM-LIST) to TARGET.

HOW-FORM-LIST must be [:HOW FUNCTION-NAME] or [:HOW LAMBDA-EXPR]."
  (declare (indent defun))
  (let* ((parsed-list (bs--advice-list-how-form how-form-list))
         (advices
          (mapcar
           (lambda (how-form)
             (let* ((how (car how-form))
                    (form (cdr how-form))
                    (lambdap (and (consp form)
                                  (eq (car form) 'lambda)))
                    (name (symbol-name (gensym "bs-fn-")))
                    (sym (if lambdap
                             (bs--advice-name target name)
                           form)))
               (if lambdap
                   `(progn
                      (defun ,sym ,(cadr form) ,@(cddr form))
                      (advice-add ',target ,how #',sym))
                 `(advice-add ',target ,how #',sym))))
           parsed-list)))
    `(progn ,@advices)))

;;;###autoload
(defmacro bs-add-advice* (target &rest how-form-list)
  "Add multiple single-use advices (HOW-FORM-LIST) to TARGET.

HOW-FORM-LIST must be [:HOW FUNCTION-NAME] or [:HOW LAMBDA-EXPR]."
  (declare (indent defun))
  (let* ((parsed-list (bs--advice-list-how-form how-form-list))
         (advices
          (mapcar
           (lambda (how-form)
             (let* ((how (car how-form))
                    (form (cdr how-form))
                    (lambdap (and (consp form)
                                  (eq (car form) 'lambda)))
                    (name (symbol-name (gensym "bs-fn-")))
                    (sym (bs--advice-name target name))
                    (callee (if lambdap
                                (let* ((sym (gensym "bs-fn-"))
                                       (name (symbol-name sym)))
                                  (bs--advice-name target name))
                              form)))
               `(progn
                  ,(when lambdap
                     `(defun ,callee ,(cadr form) ,@(cddr form)))
                  (defun ,sym ,(pcase how
                                 (:around '(orig-fn &rest args))
                                 (:filter-args '(args))
                                 (:filter-return '(ret))
                                 (_ '(&rest args)))
                    (unwind-protect
                        ,(pcase how
                           (:around `(apply #',callee orig-fn args))
                           (:filter-args `(funcall #',callee args))
                           (:filter-return `(funcall #',callee ret))
                           (_ `(apply #',callee args)))
                      (advice-remove ',target ',sym)))
                  (advice-add ',target ,how #',sym))))
           parsed-list)))
    `(progn ,@advices)))

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
