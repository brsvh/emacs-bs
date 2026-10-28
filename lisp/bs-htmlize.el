;;; bs-htmlize.el --- PDF printing  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

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

;; Print `htmlize' output with a temporary headless browser.
;; PDF display follows the user's existing file mode configuration.

;;; Code:

(require 'cl-lib)
(require 'htmlize)
(require 'json)

(defgroup bs-htmlize nil
  "Print decorated buffer text to PDF."
  :group 'htmlize)

(defcustom bs-htmlize-browser "chromium"
  "Chromium-compatible executable used to print HTML."
  :type 'file
  :group 'bs-htmlize)

(defcustom bs-htmlize-latin-font nil
  "Override the Latin font family used for PDF output.
When nil, read the current frame's `default' face at print time."
  :type '(choice (const :tag "Current Emacs font" nil) string)
  :group 'bs-htmlize)

(defcustom bs-htmlize-cjk-font nil
  "Override the font family used for ordinary Chinese text.
When nil, resolve the current frame's `default' face for Han text."
  :type '(choice (const :tag "Current Emacs font" nil) string)
  :group 'bs-htmlize)

(defcustom bs-htmlize-cjk-italic-font nil
  "Override the font family used for Chinese italic text.
When nil, resolve the current frame's `italic' face for Han text."
  :type '(choice (const :tag "Current Emacs font" nil) string)
  :group 'bs-htmlize)

(defcustom bs-htmlize-cjk-bold-italic-font nil
  "Override the font family used for Chinese bold italic text.
When nil, resolve the current frame's `bold-italic' Han font."
  :type '(choice (const :tag "Current Emacs font" nil) string)
  :group 'bs-htmlize)

(defun bs-htmlize--face-family (face character)
  "Return FACE's font family for CHARACTER on the selected frame.
Return nil when no graphical font can be resolved."
  (when (display-graphic-p)
    (when-let* ((font (face-font face nil character))
                (family (font-get (font-spec :name font) :family)))
      (format "%s" family))))

(defun bs-htmlize--stylesheet ()
  "Return paged CSS using the current Emacs font mappings."
  (concat
   (mapconcat
    (lambda (entry)
      (pcase-let ((`(,family ,style ,weight) entry))
        (if family
            (format
             (concat "@font-face { font-family: 'bs-htmlize CJK';"
                     " src: local(%s);"
                     " font-style: %s; font-weight: %s;"
                     " unicode-range: U+2E80-9FFF,U+F900-FAFF,"
                     "U+FF00-FFEF,"
                     "U+20000-323AF; }\n")
             (json-encode-string family) style weight)
          "")))
    `((,(or bs-htmlize-cjk-font
            (bs-htmlize--face-family 'default ?中)) "normal" "400")
      (,(or bs-htmlize-cjk-italic-font
            (bs-htmlize--face-family 'italic ?中)) "italic" "400")
      (,(or bs-htmlize-cjk-bold-italic-font
            (bs-htmlize--face-family 'bold-italic ?中))
       "italic" "700"))
    "")
   "@page { size: A4; margin: 16mm;"
   " @bottom-right { content: counter(page);"
   " font: 9pt sans-serif; } }\n"
   "body, pre { font-family: 'bs-htmlize CJK', "
   (format "%s, monospace; }\n"
           (json-encode-string
            (or bs-htmlize-latin-font
                (bs-htmlize--face-family 'default ?A)
                "monospace")))
   "body { margin: 0; print-color-adjust: exact; }\n"
   "pre { font-size: 10pt; line-height: 1.45; white-space: pre-wrap;"
   " overflow-wrap: anywhere; tab-size: 8; }\n"))

(defun bs-htmlize--overlay-strings (begin end text)
  "Splice overlay strings from BEGIN through END into TEXT.
Include each string only in the fragment containing its endpoint."
  (let (additions)
    (dolist (overlay (overlays-in begin end))
      (let* ((start (overlay-start overlay))
             (stop (overlay-end overlay))
             (before (overlay-get overlay 'before-string))
             (after (overlay-get overlay 'after-string))
             (empty (= start stop))
             (at-start
              (and (<= begin start)
                   (or (< start end)
                       (and empty (= start end (point-max)))))))
        (when (and after
                   (if empty at-start
                     (and (< begin stop) (<= stop end))))
          (push (cons (- stop begin) after) additions))
        (when (and before at-start)
          (push (cons (- start begin) before) additions))))
    (if (null additions)
        text
      (let ((position 0) chunks)
        (dolist (entry (cl-stable-sort additions #'< :key #'car))
          (push (substring text position (car entry)) chunks)
          (push (cdr entry) chunks)
          (setq position (car entry)))
        (push (substring text position) chunks)
        (apply #'concat (nreverse chunks))))))

(defun bs-htmlize--write-html (begin end file)
  "Write decorated text between BEGIN and END to local HTML FILE."
  (let* ((htmlize-output-type 'css)
         (htmlize-html-charset "utf-8")
         (htmlize-head-tags
          (concat htmlize-head-tags
                  "<meta http-equiv=\"Content-Security-Policy\" "
                  "content=\"default-src 'none';"
                  " style-src 'unsafe-inline'; font-src 'self'\">\n"
                  "<style>\n" (bs-htmlize--stylesheet) "</style>\n"))
         ;; htmlize can receive fragments smaller than an overlay.
         (buffer
          (cl-letf (((symbol-function
                      'htmlize-add-before-after-strings)
                     #'bs-htmlize--overlay-strings))
            (htmlize-region begin end))))
    (unwind-protect
        (with-current-buffer buffer
          (let ((coding-system-for-write 'utf-8-unix))
            (write-region (point-min) (point-max) file nil 'silent)))
      (kill-buffer buffer))))

(defun bs-htmlize--finish-print
    (directory file overwrite process _event)
  "Finish printing PROCESS and remove temporary DIRECTORY.
Copy the resulting PDF to FILE, allowing replacement when OVERWRITE
is non-nil.  Display the process log on failure."
  (when (memq (process-status process) '(exit signal))
    (let ((pdf (expand-file-name "output.pdf" directory))
          (log (process-buffer process)))
      (unwind-protect
          (condition-case err
              (progn
                (unless (and (zerop (process-exit-status process))
                             (file-exists-p pdf))
                  (error "Renderer exited without producing a PDF"))
                (copy-file pdf file overwrite)
                (find-file-other-window file)
                (when (buffer-live-p log)
                  (kill-buffer log))
                (message "Printed %s" file))
            (error
             (when (buffer-live-p log)
               (display-buffer log))
             (message "PDF printing failed: %s"
                      (error-message-string err))))
        (delete-directory directory t)))))

;;;###autoload
(defun bs-htmlize-print-pdf (begin end file &optional overwrite)
  "Print BEGIN through END to FILE and visit the resulting PDF.
Interactively, print the active region or the accessible buffer.  Ask
before replacing an existing file.  Noninteractively, OVERWRITE
permits replacement.  Render asynchronously in a temporary profile."
  (interactive
   (let* ((region (use-region-p))
          ;; Buffer names may contain file wildcard characters.
          (name (replace-regexp-in-string
                 "[][?*\\\\]" ""
                 (file-name-base
                  (or buffer-file-name (buffer-name)))))
          (file (read-file-name
                 "Print to PDF: " nil nil nil
                 (concat (if (equal name "") "buffer" name) ".pdf")))
          (overwrite (and (file-exists-p file)
                          (yes-or-no-p "Replace existing PDF? "))))
     (list (if region (region-beginning) (point-min))
           (if region (region-end) (point-max)) file overwrite)))
  (setq file (expand-file-name file))
  (when (file-remote-p file)
    (user-error "Choose a local PDF destination"))
  (unless (string-equal
           (downcase (or (file-name-extension file) "")) "pdf")
    (user-error "The destination must end in .pdf"))
  (when (and (file-exists-p file) (not overwrite))
    (user-error "The destination already exists"))
  (unless (executable-find bs-htmlize-browser)
    (user-error "PDF renderer unavailable: %s" bs-htmlize-browser))
  (let* ((directory (make-temp-file "bs-htmlize-" t))
         (html (expand-file-name "input.html" directory))
         (pdf (expand-file-name "output.pdf" directory))
         (log (generate-new-buffer "*PDF printing*"))
         (default-directory directory))
    (condition-case err
        (progn
          (bs-htmlize--write-html begin end html)
          (make-process
           :name "bs-htmlize-print" :buffer log :noquery t
           :command
           (list bs-htmlize-browser "--headless"
                 "--disable-background-networking" "--no-first-run"
                 "--no-pdf-header-footer"
                 (concat "--user-data-dir=" directory "/profile")
                 (concat "--print-to-pdf=" pdf)
                 (concat "file://" html))
           :sentinel (apply-partially #'bs-htmlize--finish-print
                                      directory file overwrite)))
      ((error quit)
       (kill-buffer log)
       (delete-directory directory t)
       (signal (car err) (cdr err))))))

(provide 'bs-htmlize)
;;; bs-htmlize.el ends here
