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
(require 'subr-x)

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

(defun bs-single-line (value fallback)
  "Return VALUE as a trimmed single line, or FALLBACK when empty."
  (let ((value
         (string-trim
          (replace-regexp-in-string
           "[\n\r\t ]+" " " (or value "")))))
    (if (string-empty-p value) fallback value)))

(defun bs-sanitize-single-line (value)
  "Return VALUE without control characters that break one-line layout."
  (string-trim
   (replace-regexp-in-string
    "[[:cntrl:]\n\r\t]+" " "
    (if (stringp value) value ""))))

(defun bs-truncate-string (string width)
  "Truncate STRING to WIDTH columns with an ASCII ellipsis."
  (cond
   ((<= width 0) "")
   ((<= (string-width string) width) string)
   (t
    (truncate-string-to-width
     string width 0 nil (and (> width 3) "...")))))

(defun bs-right-padding (string &optional margin)
  "Return pixel-aware padding that right-aligns STRING.
Leave MARGIN columns at the right edge, defaulting to one."
  (propertize
   " " 'display
   `(space
     :align-to
     (- right
        (+ (,(string-pixel-width string)) ,(or margin 1))))))

(defun bs-top-spacing-prefix (spacing)
  "Return a zero-width line prefix adding SPACING above a row."
  (propertize
   " " 'display
   `(space
     :width 0
     :height ,(+ 1.0 (max 0 spacing))
     :ascent 100)))

(defun bs-group-by (items key-function &optional test)
  "Group ITEMS by KEY-FUNCTION while preserving their order.
Preserve the order in which keys first appear and the order of items
inside each group.  Compare keys with hash table TEST, or `equal' when
TEST is nil."
  (let ((table (make-hash-table :test (or test #'equal)))
        order)
    (dolist (item items)
      (let ((key (funcall key-function item)))
        (unless (gethash key table)
          (push key order))
        (puthash key (cons item (gethash key table)) table)))
    (mapcar
     (lambda (key)
       (nreverse (gethash key table)))
     (nreverse order))))

(defun bs-today-time-bounds (&optional time)
  "Return local calendar-day bounds around TIME as epoch seconds.
Use the current time when TIME is nil."
  (pcase-let* ((`(,_second ,_minute ,_hour ,day ,month ,year . ,_)
                (decode-time time))
               (start (encode-time 0 0 0 day month year))
               (end (encode-time 0 0 0 (1+ day) month year)))
    (cons (float-time start)
          (float-time end))))

(defun bs-message-base-subject (subject &optional fallback)
  "Return SUBJECT without common reply prefixes.
Use FALLBACK, or \"[no subject]\", when SUBJECT is nil."
  (replace-regexp-in-string
   "\\`\\(?:\\(?:re\\|fwd?\\):[[:blank:]]*\\)+" ""
   (or subject fallback "[no subject]") t t))

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
