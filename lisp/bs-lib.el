;;; bs-lib.el --- Personal Extensions -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2026 Bingshan Chang

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

;; These are extensions that provide additional features to support my
;; personal Emacs configuration.

;;; Code:

(require 'cl-lib)

(defun bs--decode-raw-utf-8 (string)
  "Decode raw UTF-8 byte sequences in STRING.
Map bytes that do not form valid UTF-8 sequences to their Latin-1
characters so the result contains only Unicode scalar values."
  (mapconcat
   (lambda (character)
     (string
      (if (eq (char-charset character) 'eight-bit)
          (logand character #xff)
        character)))
   (decode-coding-string string 'utf-8)
   ""))

;;;###autoload
(defun bs-path (&rest segments)
  "Join SEGMENTS to a path."
  (let (file-name-handler-alist path)
    (setq path
          (expand-file-name (if (cdr segments)
                                (apply #'file-name-concat segments)
                              (car segments))))
    (if (file-name-absolute-p (car segments))
        path
      (file-relative-name path))))

;;;###autoload
(defun bs-path* (&rest segments)
  "Join SEGMENTS to a path, ensure it is exists."
  (let ((path (apply #'bs-path segments)) directory)
    (if (file-directory-p path)
        (setq directory path)
      (setq directory (file-name-directory path)))
    (make-directory directory 'parents)
    path))

;;;###autoload
(defun bs-getenv (environ &optional default-value)
  "Get the value of ENVIRON.

When DEFAULT-VALUE is non-nil, if the ENVIRON value is nil, return the
DEFAULT-VALUE."
  (let ((value (getenv environ)))
    (if (null value)
        default-value
      value)))

;;;###autoload
(defun bs-call-in-current-frame (function &rest arguments)
  "Call FUNCTION with ARGUMENTS and focus the selected Emacs frame."
  (prog1
      (apply function arguments)
    (select-frame-set-input-focus (selected-frame))))

;;;###autoload
(defun bs-call-in-new-frame (function &rest arguments)
  "Create a frame in this Emacs session and call FUNCTION with ARGUMENTS.
Select and focus the new frame after FUNCTION returns.  Delete the
frame when FUNCTION exits nonlocally."
  (let ((frame (make-frame))
        completed)
    (unwind-protect
        (prog1
            (with-selected-frame frame
              (apply function arguments))
          (select-frame-set-input-focus frame)
          (setq completed t))
      (unless completed
        (when (frame-live-p frame)
          (delete-frame frame))))))

;;;###autoload
(defun bs-silence-message (func &rest args)
  "Run FUNC with ARGS, silencing all messages."
  (cl-letf (((symbol-function #'message) #'ignore))
    (apply func args)))

(provide 'bs-lib)
;;; bs.el ends here
