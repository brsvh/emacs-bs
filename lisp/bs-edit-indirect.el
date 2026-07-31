;;; bs-edit-indirect.el --- Indirect editing helpers  -*- lexical-binding:t -*-

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

;; This package provides helpers for editing embedded source regions
;; in separate buffers.

;;; Code:

(require 'edit-indirect)
(require 'treesit)

(declare-function markdown-ts--code-block-language-mode
                  "markdown-ts-mode" (lang))
(declare-function markdown-edit-code-block "markdown-mode" ())

(defvar markdown-ts-default-code-block-mode)

(defun bs-edit-indirect--markdown-ts-code-block ()
  "Edit the fenced Tree-sitter Markdown code block at point indirectly."
  (let* ((root (treesit-buffer-root-node 'markdown))
         (capture
          (car (treesit-query-capture
                root '((fenced_code_block) @block)
                (point) (min (1+ (point)) (point-max)))))
         (block (cdr capture)))
    (unless block
      (user-error "Point is not in a fenced Markdown code block"))
    (let* ((last-child (treesit-node-child block -1 'named))
           (beg (save-excursion
                  (goto-char (treesit-node-start block))
                  (forward-line 1)
                  (point)))
           (end (if (and last-child
                         (equal (treesit-node-type last-child)
                                "fenced_code_block_delimiter"))
                    (treesit-node-start last-child)
                  (treesit-node-end block)))
           (language-node
            (treesit-search-subtree block "\\`language\\'"))
           (mode
            (or (and language-node
                     (markdown-ts--code-block-language-mode
                      (intern (treesit-node-text language-node t))))
                markdown-ts-default-code-block-mode))
           (edit-indirect-guess-mode-function
            (lambda (_parent-buffer _beg _end)
              (funcall mode))))
      (edit-indirect-region beg end t))))

;;;###autoload
(defun bs-edit-indirect-markdown-code-block ()
  "Edit the fenced Markdown code block at point indirectly."
  (interactive)
  (cond
   ((derived-mode-p 'markdown-ts-mode)
    (bs-edit-indirect--markdown-ts-code-block))
   ((derived-mode-p 'markdown-mode)
    (markdown-edit-code-block))
   (t
    (user-error "Current buffer is not in a Markdown mode"))))

(defun bs-edit-indirect--nix-literal-string-content-bounds (bounds)
  "Return content BOUNDS without delimiter-only lines."
  (let ((beg (car bounds))
        (end (cdr bounds)))
    (when (and (< beg end)
               (eq (char-after beg) ?\n))
      (setq beg (1+ beg)))
    (save-excursion
      (goto-char end)
      (let ((line-beg (line-beginning-position)))
        (when (and (< beg end)
                   (> line-beg (point-min))
                   (eq (char-before line-beg) ?\n)
                   (string-match-p
                    "\\`[ \t]*\\'"
                    (buffer-substring-no-properties line-beg end)))
          (setq end (max beg (1- line-beg))))))
    (cons beg end)))

;;;###autoload
(defun bs-edit-indirect-nix-literal-string ()
  "Edit the Nix literal string at point indirectly."
  (interactive)
  (let ((bounds
         (if (derived-mode-p 'nix-ts-mode)
             (when-let* ((capture
                          (car (treesit-query-capture
                                (treesit-buffer-root-node 'nix)
                                '((indented_string_expression) @string)
                                (point)
                                (min (1+ (point)) (point-max)))))
                         (node (cdr capture)))
               (cons (+ (treesit-node-start node) 2)
                     (- (treesit-node-end node) 2)))
           (let* ((state (syntax-ppss))
                  (start (nth 8 state)))
             (when (and (nth 3 state)
                        start
                        (save-excursion
                          (goto-char start)
                          (looking-at-p "''")))
               (save-excursion
                 (goto-char start)
                 (forward-sexp)
                 (cons (+ start 2) (- (point) 2))))))))
    (unless bounds
      (user-error "Point is not in a Nix literal string"))
    (setq bounds
          (bs-edit-indirect--nix-literal-string-content-bounds
           bounds))
    (let ((edit-indirect-guess-mode-function
           (lambda (_parent-buffer _beg _end)
             (fundamental-mode))))
      (edit-indirect-region (car bounds) (cdr bounds) t))))

(provide 'bs-edit-indirect)
;;; bs-edit-indirect.el ends here
