;;; bs-setup-macs.el --- Addtional `setup' local macros -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2025 Burgess Chang

;; Author: Burgess Chang <bsc@brsvh.org>
;; Keywords: extensions
;; Package-Requires: ((on "0.1.0") (setup "1.4.0"))
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

;; This file provide additional local macros for `setup'.

;;; Code:

(eval-and-compile

(require 'bs-hooks)
(require 'macroexp)
(require 'setup)

(defun bs-setup-macs-maybe-unquote (form)
  "Unquote the car of FORM when it is quoted."
  (if (and (consp form)
           (= (length form) 2)
           (eq (car form) 'quote))
      (cadr form)
    form))

;; See https://www.emacswiki.org/emacs/SetupEl#h5o-13
(setup-define :add-advice
  (lambda (symbol where function)
    `(advice-add ',symbol ,where ,function))
  :after-loaded t
  :debug '(sexp sexp function-form)
  :documentation "Add a piece of advice on a function.
See `advice-add' for more details."
  :ensure '(nil nil func)
  :repeatable t)

(setup-define :after
  (lambda (features &rest body)
    (let ((features (if (listp features)
                        (bs--setup-macs-maybe-unquote features)
                      (list features)))
          (form (macroexp-progn body)))
      (dolist (feature (nreverse features))
        (setq form `(with-eval-after-load ',feature ,form)))
      form))
  :debug '([&or ([&rest sexp]) sexp] form)
  :documentation "Load the current feature after FEATURES."
  :indent 1)

(setup-define :buffer-match
  (lambda (condition action-and-flags)
    `(:option
      (append display-buffer-alist)
      '(,(setup-macs-maybe-unquote condition)
        ,@(setup-macs-maybe-unquote action-and-flags))))
  :debug '(sexp [&rest sexp])
  :documentation "Create a CONDITION and ACTION-AND-FLAGS display rule."
  :repeatable t)

(setup-define :demand
  (lambda (condition)
    (when condition
      `(require ',(setup-get 'feature))))
  :debug '(sexp)
  :documentation "Require the FEATURE of context when CONDITION."
  :ensure '(nil))

;; https://www.emacswiki.org/emacs/SetupEl#h5o-22
(setup-define :face
  (lambda (face spec)
    `(custom-set-faces (quote (,face ,spec))))
  :documentation "Customize FACE to SPEC."
  :signature '(face spec ...)
  :debug '(setup)
  :repeatable t
  :after-loaded t)

;; See https://www.emacswiki.org/emacs/SetupEl#h5o-21
(setup-define :file-match
  (lambda (glob)
    `(add-to-list 'auto-mode-alist
                  (cons ,(wildcard-to-regexp pat) ',(setup-get 'mode))))
  :documentation "Associate the current mode with files that match GLOB."
  :debug '(form)
  :repeatable t)

(setup-define :first-buffer
  (lambda (func)
    `(add-hook 'bs-first-buffer-hook ,func))
  :debug '(sexp)
  :documentation "Add FUNC to `bs-first-buffer-hook'."
  :ensure '(func)
  :repeatable t)

(setup-define :first-file
  (lambda (func)
    `(add-hook 'bs-first-file-hook ,func))
  :debug '(sexp)
  :documentation "Add FUNC to `bs-first-file-hook'."
  :ensure '(func)
  :repeatable t)

(setup-define :first-input
  (lambda (func)
    `(add-hook 'bs-first-input-hook ,func))
  :debug '(sexp)
  :documentation "Add FUNC to `bs-first-input-hook'."
  :ensure '(func)
  :repeatable t)

(setup-define :first-ui
  (lambda (func)
    `(add-hook 'bs-first-ui-hook ,func))
  :debug '(sexp)
  :documentation "Add FUNC to `bs-first-ui-hook'."
  :ensure '(func)
  :repeatable t)

(setup-define :keymap-set
  (lambda (key command)
    `(keymap-set ,(setup-get 'map) ,key ,command))
  :debug '("STRING" sexp)
  :documentation "Bind KEY to COMMAND in current map."
  :ensure '(nil func)
  :repeatable t)

(setup-define :keymap-set*
  (lambda (&rest args)
    (let* ((n (length args)) map key command)
      (cond
       ((or (< n 1) (> n 3))
        (error "Illegal arguments"))
       ;; (:with-function foo
       ;;   (:with-map foo-map
       ;;     (:keymap-set-into "a")))
       ((= n 1)
        (setq map (setup-get 'map)
              key (car args)
              command (setup-get 'func)))
       ;; (:with-function foo
       ;;   (:keymap-set-into foo-map "a"))
       ((and (= n 2)
             (symbolp (car args)))
        (setq map (car args)
              key (cadr args)
              command (setup-get 'func)))
       ;; (:with-map foo-map
       ;;   (:keymap-set-into "a" foo))
       ((and (= n 2)
             (key-valid-p (car args)))
        (setq map (setup-get 'map)
              key (car args)
              command (cadr args)))
       ;; (:keymap-set-into foo-map "a" foo)
       ((= n 3)
        (setq map (car args)
              key (cadr args)
              command (caddr args))))
      `(:with-map ,map (:keymap-set ,key ,command))))
  :debug '([&rest [&or (sexp stringp sexp)
                       (sexp stringp)
                       (stringp sexp)
                       stringp]])
  :documentation "Process KEY, MAP, COMMAND binding of ARGS.")

(setup-define :keymap-unset
  (lambda (key command)
    `(keymap-unset ,(setup-get 'map) ,key))
  :debug '(stringp)
  :documentation "Unset KEY in current map."
  :ensure '(nil)
  :repeatable t)

(setup-define :keymap-unset*
  (lambda (key command)
    `(keymap-unset ,(setup-get 'map) ,key t))
  :debug '(stringp sexp)
  :documentation "Remove KEY in current map."
  :ensure '(nil)
  :repeatable t)

;; See https://www.emacswiki.org/emacs/SetupEl#h5o-12
(setup-define :local-unhook
  (lambda (hook &rest functions)
    `(add-hook
      (quote ,(setup-get 'hook))
      (lambda ()
        ,@(mapcar
           (lambda (arg)
             (let ((fn (cond
                        ((eq (car-safe arg) 'function) arg)
                        ((eq (car-safe arg) 'quote)    `(function ,(cadr arg)))
                        ((symbolp arg)                 `(function ,arg))
                        (t                             arg))))
               `(remove-hook (quote ,hook) ,fn t)))
           functions))))
  :documentation "Remove FUNCTION from HOOK only in the current hook."
  :debug '(&rest sexp)
  :repeatable nil)

(setup-define :remove-advice
  (lambda (symbol function)
    `(advice-remove ',symbol ,function))
  :after-loaded t
  :debug '(sexp sexp)
  :documentation "Remove a piece of advice on a function.
See `advice-remove' for more details."
  :ensure '(nil func)
  :repeatable t)

;; See https://www.emacswiki.org/emacs/SetupEl#h5o-12
(setup-define :unhook
  (lambda (func)
    `(remove-hook (quote ,(setup-get 'hook)) ,func))
  :documentation "Remove FUNC from the current hook."
  :ensure '(func)
  :repeatable t
  :signature '(FUNC ...))

(setup-define :unless
  (lambda (condition &rest body)
    `(unless ,condition
       ,@body))
  :documentation "Evaluate BODY unless CONDITION is true."
  :debug '(sexp form)
  :indent 1)

(setup-define :when
  (lambda (condition &rest body)
    `(when ,condition
       ,@body))
  :documentation "Evaluate BODY when CONDITION is true."
  :debug '(sexp form)
  :indent 1)

)
(provide 'setup-macs)
;;; bs-setup-macs.el ends here
