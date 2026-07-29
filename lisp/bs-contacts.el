;;; bs-contacts.el --- Local vCard contact integration  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: comm, extensions
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

;; This package provides commands for managing local vCard address
;; books through khard and synchronizing them through vdirsyncer.
;; Account-specific metadata is supplied by the user's configuration.

;;; Code:

(require 'cl-lib)
(require 'mail-parse)
(require 'subr-x)

(defgroup bs-contacts nil
  "Manage local vCard address books."
  :group 'comm)

(defcustom bs-contacts-khard-command "khard"
  "Program used to query and modify local vCard address books.

The value names an executable.  Contact commands invoke it directly
with an argument list and never through a shell."
  :type 'string
  :group 'bs-contacts)

(defcustom bs-contacts-vdirsyncer-command "vdirsyncer"
  "Program used to synchronize local vCard address books.

The value names an executable.  Synchronization commands invoke it
directly with an argument list and never through a shell."
  :type 'string
  :group 'bs-contacts)

(defcustom bs-contacts-addressbooks nil
  "Alist of address books available to contact commands.

Each entry has a stable string ID as its car and an alist of metadata
as its cdr.  Metadata may include `accountName', `addressbookId',
`default', `id', `khardName', `name', `path', `readOnly', and
`syncCollection'."
  :type '(alist :key-type string :value-type sexp)
  :group 'bs-contacts)

(defcustom bs-contacts-default-addressbook nil
  "Metadata alist for the default writable address book.

The value is nil when no writable default has been configured.  A
non-nil value follows the metadata format documented by
`bs-contacts-addressbooks'."
  :type '(choice (const :tag "No default address book" nil)
                 sexp)
  :group 'bs-contacts)

(defcustom bs-contacts-sync-collections nil
  "Vdirsyncer collection names synchronized by contact commands.

Each string is passed to vdirsyncer as a complete collection name.
An empty list means that contact synchronization has no targets."
  :type '(repeat string)
  :group 'bs-contacts)

(defcustom bs-contacts-cache-check-interval 2
  "Minimum seconds between fallback checks of local vCard files.

File notifications invalidate the cache immediately when available.
This interval controls a file-state check that also covers systems
without file notification support and events that may have been
missed.  A nil or non-positive value checks on every cache access."
  :type '(choice (const :tag "Check on every access" nil)
                 number)
  :group 'bs-contacts)

(defcustom bs-contacts-view-buffer-name "*bs-contacts*"
  "Name of the read-only buffer used to display a contact."
  :type 'string
  :group 'bs-contacts)

(defcustom bs-contacts-sync-buffer-name "*bs-contacts-sync*"
  "Name of the buffer containing vdirsyncer contact sync output."
  :type 'string
  :group 'bs-contacts)

(cl-defstruct
    (bs-contacts-contact
     (:constructor bs-contacts-contact-create
                   (&key uid addressbook name emails)))
  "A contact read from a local vCard address book.

UID and ADDRESSBOOK form the stable identity.  NAME is the display
name, and EMAILS is a list of email address strings."
  uid
  addressbook
  name
  emails)

(cl-defstruct
    (bs-contacts-mail-candidate
     (:constructor bs-contacts-mail-candidate-create
                   (&key email display source contact)))
  "A mail completion candidate derived from a contact source.

EMAIL is the address used for identity and deduplication.  DISPLAY is
the string inserted into a mail header.  SOURCE records the candidate
source, and CONTACT is the associated contact record when available."
  email
  display
  source
  contact)

(defun bs-contacts--metadata-get (metadata key)
  "Return from METADATA the value associated with KEY."
  (alist-get key metadata))

(defun bs-contacts--addressbook (addressbook-id)
  "Return metadata for ADDRESSBOOK-ID.

Signal `user-error' when ADDRESSBOOK-ID is not configured."
  (or (cdr (assoc addressbook-id bs-contacts-addressbooks))
      (user-error "Unknown contact address book: %s" addressbook-id)))

(defun bs-contacts--default-addressbook-id ()
  "Return the configured default writable address book ID.

Signal `user-error' when no default address book is configured."
  (or (bs-contacts--metadata-get bs-contacts-default-addressbook 'id)
      (user-error "No default writable contact address book is configured")))

(defun bs-contacts--ensure-writable-addressbook (addressbook-id)
  "Return writable metadata for ADDRESSBOOK-ID.

Signal `user-error' unless ADDRESSBOOK-ID names the configured default
address book and that address book is writable."
  (let ((addressbook (bs-contacts--addressbook addressbook-id)))
    (unless (equal addressbook-id
                   (bs-contacts--default-addressbook-id))
      (user-error "Contact address book is not the default writable target: %s"
                  addressbook-id))
    (when (bs-contacts--metadata-get addressbook 'readOnly)
      (user-error "Contact address book is read-only: %s" addressbook-id))
    addressbook))

(defun bs-contacts--make-contact (uid addressbook name emails)
  "Return a contact identified by UID and ADDRESSBOOK.

NAME is the contact display name.  EMAILS is a list of email address
strings.  UID may contain any characters accepted by khard, but it
must be a non-empty string."
  (unless (and (stringp uid)
               (not (string-empty-p uid)))
    (error "Contact UID must be a non-empty string"))
  (unless (and (stringp addressbook)
               (not (string-empty-p addressbook)))
    (error "Contact address book ID must be a non-empty string"))
  (bs-contacts-contact-create
   :uid uid
   :addressbook addressbook
   :name (or name "")
   :emails (copy-sequence emails)))

(defun bs-contacts--contact-identity (contact)
  "Return CONTACT's stable identity as (ADDRESSBOOK . UID)."
  (cons (bs-contacts-contact-addressbook contact)
        (bs-contacts-contact-uid contact)))

(defun bs-contacts--contact-label (contact)
  "Return a stable, unambiguous completion label for CONTACT."
  (let* ((name (bs-contacts-contact-name contact))
         (emails (bs-contacts-contact-emails contact))
         (primary-email (car emails))
         (identity (bs-contacts--contact-identity contact)))
    (format "%s%s [%s · %s]"
            (if (string-empty-p name) "(unnamed contact)" name)
            (if primary-email (format " <%s>" primary-email) "")
            (car identity)
            (cdr identity))))

(declare-function bs-mu4e-clean-mail-address "bs-mu4e" (address))
(declare-function bs-mu4e-completion-candidate "bs-mu4e" (candidate))
(declare-function bs-mu4e-email-address-p "bs-mu4e" (string))
(declare-function bs-mu4e-trim-contact-name "bs-mu4e" (name))
(declare-function file-notify-rm-watch "filenotify" (descriptor))

(defvar bs-contacts--cache nil
  "Cached contacts derived from local vCard address books.")

(defvar bs-contacts--cache-valid-p nil
  "Whether `bs-contacts--cache' represents the current local data.")

(defvar bs-contacts--cache-file-state nil
  "Local vCard state recorded when the cache was last populated.")

(defvar bs-contacts--cache-last-check nil
  "Time of the last fallback local vCard state check.")

(defvar bs-contacts--watch-descriptors nil
  "File notification descriptors for configured address books.")

(defvar bs-contacts--watched-paths nil
  "Address book paths represented by current file watches.")

(defvar bs-contacts--edit-buffers (make-hash-table :test #'equal)
  "Writable contact buffers keyed by (ADDRESSBOOK . UID).")

(defvar bs-contacts--sync-process nil
  "Current vdirsyncer process used for contact synchronization.")

(defvar-local bs-contacts--edit-operation nil
  "Operation performed when the current contact edit buffer is submitted.")

(defvar-local bs-contacts--edit-addressbook nil
  "Stable address book ID associated with the current edit buffer.")

(defvar-local bs-contacts--edit-uid nil
  "Contact UID associated with the current edit buffer, or nil for creation.")

(defvar-local bs-contacts--edit-key nil
  "Registry key for the current contact edit buffer.")

(defun bs-contacts--addressbook-paths ()
  "Return the configured local address book paths without duplicates."
  (delete-dups
   (delq nil
         (mapcar
          (lambda (entry)
            (let ((path
                   (bs-contacts--metadata-get (cdr entry) 'path)))
              (when (and (stringp path)
                         (not (string-empty-p path)))
                (expand-file-name path))))
          bs-contacts-addressbooks))))

(defun bs-contacts--file-state (file)
  "Return a comparable state record for FILE."
  (let ((attributes (file-attributes file 'string)))
    (list file
          (file-attribute-size attributes)
          (file-attribute-modification-time attributes))))

(defun bs-contacts--local-file-state ()
  "Return a comparable state for configured local vCard files."
  (mapcan
   (lambda (path)
     (cond
      ((file-directory-p path)
       (mapcar #'bs-contacts--file-state
               (sort (directory-files-recursively path "\\.vcf\\'")
                     #'string<)))
      ((file-exists-p path)
       (list (bs-contacts--file-state path)))
      (t
       (list (list path 'missing)))))
   (bs-contacts--addressbook-paths)))

(defun bs-contacts--invalidate-cache (&optional _event)
  "Mark the contact cache stale without modifying local vCard files.

EVENT is ignored and permits this function to be used as a file
notification callback."
  (setq bs-contacts--cache-valid-p nil
        bs-contacts--cache-last-check nil))

(defun bs-contacts--remove-watches ()
  "Remove all contact address book file watches."
  (dolist (descriptor bs-contacts--watch-descriptors)
    (ignore-errors (file-notify-rm-watch descriptor)))
  (setq bs-contacts--watch-descriptors nil
        bs-contacts--watched-paths nil))

(defun bs-contacts--ensure-watches ()
  "Watch configured local address books when file notification is available."
  (let ((paths (bs-contacts--addressbook-paths)))
    (unless (equal paths bs-contacts--watched-paths)
      (bs-contacts--remove-watches)
      (setq bs-contacts--watched-paths paths)
      (when (and (require 'filenotify nil t)
                 (fboundp 'file-notify-add-watch))
        (dolist (path paths)
          (when (file-directory-p path)
            (condition-case nil
                (push (file-notify-add-watch
                       path
                       '(change attribute-change)
                       #'bs-contacts--invalidate-cache)
                      bs-contacts--watch-descriptors)
              (file-notify-error nil)
              (file-error nil))))))))

(defun bs-contacts--fallback-check-due-p ()
  "Return non-nil when the local vCard fallback check is due."
  (or (null bs-contacts--cache-last-check)
      (not (numberp bs-contacts-cache-check-interval))
      (<= bs-contacts-cache-check-interval 0)
      (>= (float-time
           (time-subtract nil bs-contacts--cache-last-check))
          bs-contacts-cache-check-interval)))

(defun bs-contacts--check-local-file-state ()
  "Invalidate the cache when configured local vCard state changed."
  (when (bs-contacts--fallback-check-due-p)
    (let ((state (bs-contacts--local-file-state)))
      (setq bs-contacts--cache-last-check (current-time))
      (when (and bs-contacts--cache-valid-p
                 (not (equal state bs-contacts--cache-file-state)))
        (setq bs-contacts--cache-valid-p nil)))))

(defun bs-contacts--contacts ()
  "Return contacts, loading them lazily when the cache is stale."
  (bs-contacts--ensure-watches)
  (bs-contacts--check-local-file-state)
  (if bs-contacts--cache-valid-p
      bs-contacts--cache
    (let ((contacts (bs-contacts--read-contacts))
          (state (bs-contacts--local-file-state)))
      (setq bs-contacts--cache contacts
            bs-contacts--cache-file-state state
            bs-contacts--cache-last-check (current-time)
            bs-contacts--cache-valid-p t)
      contacts)))

;;;###autoload
(defun bs-contacts-refresh ()
  "Discard derived contact data and reload it from local address books.

This command queries khard and updates only the in-memory cache.  It
does not modify vCard files or run synchronization."
  (interactive)
  (bs-contacts--invalidate-cache)
  (let ((contacts (bs-contacts--contacts)))
    (message "Refreshed %d contact%s"
             (length contacts)
             (if (= (length contacts) 1) "" "s"))
    contacts))

(defun bs-contacts--process-error-text (stdout stderr)
  "Return concise diagnostic text from STDOUT and STDERR."
  (let ((text (string-trim
               (string-join
                (delq nil
                      (list (unless (string-empty-p stderr) stderr)
                            (unless (string-empty-p stdout) stdout)))
                "\n"))))
    (if (string-empty-p text) "no diagnostic output" text)))

(defun bs-contacts--call-khard
    (operation addressbook-id arguments &optional input)
  "Run khard OPERATION with ARGUMENTS and return standard output.

ADDRESSBOOK-ID is used only to describe the operation and may be nil.
When INPUT is non-nil, send it to khard's standard input before
closing the stream.
Signal `user-error' if khard cannot be started or exits unsuccessfully.
Standard output and standard error are captured separately.  Every
element of ARGUMENTS is passed as a distinct process argument."
  (let ((stdout-buffer (generate-new-buffer " *bs-contacts-khard-output*"))
        (stderr-buffer (generate-new-buffer " *bs-contacts-khard-error*"))
        process)
    (unwind-protect
        (condition-case error-data
            (progn
              (setq process
                    (make-process
                     :name "bs-contacts-khard"
                     :buffer stdout-buffer
                     :command (cons bs-contacts-khard-command
                                    (cons operation arguments))
                     :connection-type 'pipe
                     :coding 'utf-8-unix
                     :noquery t
                     :sentinel #'ignore
                     :stderr stderr-buffer))
              (when input
                (process-send-string process input))
              (process-send-eof process)
              (while (process-live-p process)
                (accept-process-output process 0.1))
              (let ((stdout (with-current-buffer stdout-buffer
                              (buffer-string)))
                    (stderr (with-current-buffer stderr-buffer
                              (buffer-string)))
                    (exit-status (process-exit-status process)))
                (if (and (eq (process-status process) 'exit)
                         (zerop exit-status))
                    stdout
                  (user-error
                   "Khard %s failed%s (status %s): %s"
                   operation
                   (if addressbook-id
                       (format " for address book %s" addressbook-id)
                     "")
                   exit-status
                   (bs-contacts--process-error-text stdout stderr)))))
          (file-missing
           (user-error "Cannot run khard command %s: %s"
                       bs-contacts-khard-command
                       (error-message-string error-data))))
      (when (buffer-live-p stdout-buffer)
        (kill-buffer stdout-buffer))
      (when (buffer-live-p stderr-buffer)
        (kill-buffer stderr-buffer)))))

(defun bs-contacts--khard-addressbook-name (addressbook-id &optional writable)
  "Return khard's name for ADDRESSBOOK-ID.

When WRITABLE is non-nil, require the address book to be the configured
default writable target."
  (let* ((addressbook
          (if writable
              (bs-contacts--ensure-writable-addressbook addressbook-id)
            (bs-contacts--addressbook addressbook-id)))
         (name (bs-contacts--metadata-get addressbook 'khardName)))
    (unless (and (stringp name)
                 (not (string-empty-p name)))
      (user-error "Contact address book has no khard name: %s"
                  addressbook-id))
    name))

(defun bs-contacts--khard-list (addressbook-id)
  "Return khard's parsable contact list for ADDRESSBOOK-ID."
  (let ((addressbook-name
         (bs-contacts--khard-addressbook-name addressbook-id)))
    (bs-contacts--call-khard
     "list"
     addressbook-id
     (list "--addressbook" addressbook-name
           "--parsable"
           "--fields" "uid,formatted_name,address_book"))))

(defun bs-contacts--khard-show (addressbook-id uid &optional format)
  "Return khard output for UID in ADDRESSBOOK-ID.

FORMAT defaults to `pretty' and may also be `yaml' or `vcard'."
  (let ((addressbook-name
         (bs-contacts--khard-addressbook-name addressbook-id)))
    (bs-contacts--call-khard
     "show"
     addressbook-id
     (list "--addressbook" addressbook-name
           "--format" (symbol-name (or format 'pretty))
           uid))))

(defun bs-contacts--khard-template ()
  "Return a new-contact YAML template from khard."
  (bs-contacts--call-khard "template" nil nil))

(defun bs-contacts--khard-new (addressbook-id input-file)
  "Create a contact in ADDRESSBOOK-ID from YAML INPUT-FILE.

Return khard's standard output after a successful creation."
  (let ((addressbook-name
         (bs-contacts--khard-addressbook-name addressbook-id t)))
    (bs-contacts--call-khard
     "new"
     addressbook-id
     (list "--addressbook" addressbook-name
           "--input-file" input-file))))

(defun bs-contacts--khard-edit (addressbook-id uid input-file)
  "Edit UID in ADDRESSBOOK-ID from YAML INPUT-FILE.

Return khard's standard output after a successful edit."
  (let ((addressbook-name
         (bs-contacts--khard-addressbook-name addressbook-id t)))
    (bs-contacts--call-khard
     "edit"
     addressbook-id
     (list "--addressbook" addressbook-name
           "--format" "yaml"
           "--input-file" input-file
           uid)
     "yes\n")))

(defun bs-contacts--khard-remove (addressbook-id uid)
  "Remove UID from ADDRESSBOOK-ID without khard's second prompt.

The caller must obtain user confirmation before invoking this
function.  Return khard's standard output after successful removal."
  (let ((addressbook-name
         (bs-contacts--khard-addressbook-name addressbook-id t)))
    (bs-contacts--call-khard
     "remove"
     addressbook-id
     (list "--addressbook" addressbook-name "--force" uid))))

(defun bs-contacts--unfold-vcard (vcard)
  "Return VCARD with line endings normalized and folded lines joined."
  (replace-regexp-in-string
   "\n[ \t]"
   ""
   (replace-regexp-in-string "\r\n?" "\n" vcard)
   t
   t))

(defun bs-contacts--unescape-vcard-value (value)
  "Return VALUE with standard vCard backslash escapes decoded."
  (replace-regexp-in-string
   "\\\\\\([nN,;\\\\]\\)"
   (lambda (match)
     (pcase (aref match 1)
       ((or ?n ?N) "\n")
       (character (char-to-string character))))
   value
   t
   t))

(defun bs-contacts--vcard-emails (vcard)
  "Return all email addresses from machine-readable VCARD."
  (let ((case-fold-search t)
        emails)
    (dolist (line (split-string (bs-contacts--unfold-vcard vcard) "\n" t))
      (when (string-match
             "\\`\\(?:[^.;:]+\\.\\)?EMAIL\\(?:;[^:]*\\)?:\\(.*\\)\\'"
             line)
        (let ((email
               (string-trim
                (bs-contacts--unescape-vcard-value
                 (match-string 1 line)))))
          (setq email (replace-regexp-in-string
                       "\\`mailto:" "" email t t))
          (unless (string-empty-p email)
            (push email emails)))))
    (delete-dups (nreverse emails))))

(defun bs-contacts--parse-list-line (line addressbook-id addressbook-name)
  "Return the contact represented by parsable khard LINE.

ADDRESSBOOK-ID is the configured stable ID and ADDRESSBOOK-NAME is
khard's expected name for the selected address book."
  (let ((fields (split-string line "\t" nil)))
    (unless (= (length fields) 3)
      (error "Malformed khard list output for %s: %S"
             addressbook-id line))
    (pcase-let ((`(,uid ,name ,reported-addressbook) fields))
      (unless (equal reported-addressbook addressbook-name)
        (error "Unexpected khard address book for %s: %S"
               addressbook-id reported-addressbook))
      (bs-contacts--make-contact
       uid
       addressbook-id
       name
       (bs-contacts--vcard-emails
        (bs-contacts--khard-show addressbook-id uid 'vcard))))))

(defun bs-contacts--read-addressbook (addressbook-id)
  "Read and return all contacts from ADDRESSBOOK-ID through khard."
  (let* ((addressbook-name
          (bs-contacts--khard-addressbook-name addressbook-id))
         (output (bs-contacts--khard-list addressbook-id)))
    (if (string-empty-p (string-trim output))
        nil
      (mapcar
       (lambda (line)
         (bs-contacts--parse-list-line
          line addressbook-id addressbook-name))
       (split-string (string-trim-right output) "\n" t)))))

(defun bs-contacts--read-contacts ()
  "Read contacts from every configured local address book through khard."
  (mapcan
   (lambda (entry)
     (bs-contacts--read-addressbook (car entry)))
   bs-contacts-addressbooks))

(defun bs-contacts--completion-table (candidates)
  "Return a standard completion table for CANDIDATES."
  (lambda (string predicate action)
    (if (eq action 'metadata)
        '(metadata
          (category . bs-contact)
          (display-sort-function . identity)
          (cycle-sort-function . identity))
      (complete-with-action action candidates string predicate))))

(defun bs-contacts--select-contact (&optional prompt predicate)
  "Read and return a contact using standard completion.

PROMPT defaults to \"Contact: \".  When PREDICATE is non-nil, call it
with each contact and offer only contacts for which it returns
non-nil.  Signal `user-error' when no contact is available."
  (let* ((contacts
          (if predicate
              (cl-remove-if-not predicate (bs-contacts--contacts))
            (bs-contacts--contacts)))
         (candidates
          (mapcar
           (lambda (contact)
             (cons (bs-contacts--contact-label contact) contact))
           contacts)))
    (unless candidates
      (user-error "No contacts are available"))
    (let ((selection
           (completing-read
            (or prompt "Contact: ")
            (bs-contacts--completion-table (mapcar #'car candidates))
            nil
            t)))
      (cdr (assoc selection candidates)))))

;;;###autoload
(defun bs-contacts-select ()
  "Select and return a local contact using standard completion.

The completion label contains the contact name, primary email,
address book, and UID so that contacts with the same name remain
distinct.  This command has no side effects beyond loading the
derived contact cache and reporting the selection."
  (interactive)
  (let ((contact (bs-contacts--select-contact)))
    (message "%s" (bs-contacts--contact-label contact))
    contact))

(define-derived-mode bs-contacts-view-mode special-mode "Contact"
  "Major mode for displaying a contact returned by khard.")

;;;###autoload
(defun bs-contacts-show (&optional contact)
  "Display CONTACT in a read-only buffer and return that buffer.

Interactively, select CONTACT using standard completion.  The command
queries khard by the contact's address book and UID.  It does not
modify local vCard data or create temporary files."
  (interactive)
  (let* ((selected-contact
          (or contact (bs-contacts--select-contact "Show contact: ")))
         (output
          (bs-contacts--khard-show
           (bs-contacts-contact-addressbook selected-contact)
           (bs-contacts-contact-uid selected-contact)))
         (buffer (get-buffer-create bs-contacts-view-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output)
        (unless (bolp)
          (insert "\n"))
        (goto-char (point-min))
        (bs-contacts-view-mode)))
    (pop-to-buffer buffer)
    buffer))

(defvar-keymap bs-contacts-edit-mode-map
  :doc "Keymap for `bs-contacts-edit-mode'."
  :parent text-mode-map
  "C-c C-c" #'bs-contacts-edit-submit
  "C-c C-k" #'bs-contacts-edit-cancel
  "<remap> <save-buffer>" #'bs-contacts-edit-submit
  "<remap> <write-file>" #'bs-contacts-edit-refuse-write-file)

(define-derived-mode bs-contacts-edit-mode text-mode "Contact YAML"
  "Major mode for editing khard YAML input.

Use `bs-contacts-edit-submit' to validate and apply the buffer through
khard.  Use `bs-contacts-edit-cancel' to discard it.  The buffer never
visits the temporary input file passed to khard."
  (setq-local buffer-file-name nil)
  (setq-local buffer-offer-save nil)
  (setq-local require-final-newline t)
  (setq-local header-line-format
              "Submit: C-c C-c or C-x C-s    Cancel: C-c C-k"))

(defun bs-contacts-edit-refuse-write-file ()
  "Refuse to write the current contact YAML buffer as a normal file."
  (interactive)
  (user-error "Use C-c C-c to submit this contact through khard"))

(defun bs-contacts--with-yaml-input-file (function)
  "Call FUNCTION with a private temporary file containing this buffer.

Delete the temporary file after FUNCTION returns or signals.  Return
FUNCTION's return value."
  (let ((input-file (make-temp-file "bs-contacts-" nil ".yaml")))
    (unwind-protect
        (progn
          (write-region (point-min) (point-max) input-file nil 'silent)
          (funcall function input-file))
      (when (file-exists-p input-file)
        (delete-file input-file)))))

(defun bs-contacts--open-edit-buffer (operation addressbook-id uid contents)
  "Open a contact YAML buffer for OPERATION and return it.

ADDRESSBOOK-ID is the stable target address book ID.  UID is nil for
creation and identifies an existing contact for editing.  CONTENTS is
the initial YAML text."
  (let ((buffer
         (generate-new-buffer
          (if uid
              (format "*bs-contact-edit:%s*" uid)
            "*bs-contact-new*"))))
    (with-current-buffer buffer
      (insert contents)
      (goto-char (point-min))
      (bs-contacts-edit-mode)
      (setq bs-contacts--edit-operation operation
            bs-contacts--edit-addressbook addressbook-id
            bs-contacts--edit-uid uid)
      (when uid
        (setq bs-contacts--edit-key (cons addressbook-id uid))
        (puthash bs-contacts--edit-key
                 buffer
                 bs-contacts--edit-buffers)
        (add-hook 'kill-buffer-hook
                  #'bs-contacts--unregister-edit-buffer nil t))
      (set-buffer-modified-p nil))
    (pop-to-buffer buffer)
    buffer))

(defun bs-contacts--unregister-edit-buffer ()
  "Remove the current contact edit buffer from the writable registry."
  (when (and bs-contacts--edit-key
             (eq (gethash bs-contacts--edit-key
                          bs-contacts--edit-buffers)
                 (current-buffer)))
    (remhash bs-contacts--edit-key bs-contacts--edit-buffers))
  (setq bs-contacts--edit-key nil))

(defun bs-contacts--existing-edit-buffer (addressbook-id uid)
  "Return a live edit buffer for ADDRESSBOOK-ID and UID, or nil."
  (let* ((key (cons addressbook-id uid))
         (buffer (gethash key bs-contacts--edit-buffers)))
    (if (buffer-live-p buffer)
        buffer
      (remhash key bs-contacts--edit-buffers)
      nil)))

(defun bs-contacts--sync-running-p ()
  "Return non-nil while contact vdirsyncer is running."
  (and (processp bs-contacts--sync-process)
       (process-live-p bs-contacts--sync-process)))

(defun bs-contacts--sync-diagnostic (buffer)
  "Return a concise known-failure diagnosis from sync BUFFER, or nil."
  (with-current-buffer buffer
    (let ((case-fold-search t))
      (save-excursion
        (goto-char (point-min))
        (cond
         ((re-search-forward "server disconnected" nil t)
          "server disconnected")
         ((re-search-forward "\\bconflict\\(?:ed\\|ing\\|s\\)?\\b" nil t)
          "contact conflict")
         ((re-search-forward
           "\\(?:completely emptied\\|--force-delete\\)"
           nil t)
          "whole-address-book deletion protection"))))))

(defun bs-contacts--sync-sentinel (process _event)
  "Handle completion of contact sync PROCESS."
  (when (memq (process-status process) '(exit signal))
    (let* ((buffer (process-buffer process))
           (collections (process-get process 'bs-contacts-collections))
           (exit-status (process-exit-status process))
           (success (and (eq (process-status process) 'exit)
                         (zerop exit-status)))
           (diagnostic
            (when (and (not success)
                       (buffer-live-p buffer))
              (bs-contacts--sync-diagnostic buffer))))
      (when (eq process bs-contacts--sync-process)
        (setq bs-contacts--sync-process nil))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (goto-char (point-max))
            (insert
             "\n"
             (propertize
              (if success
                  (format "Contact sync succeeded: %s\n"
                          (string-join collections ", "))
                (format "Contact sync failed (status %s)%s.\n"
                        exit-status
                        (if diagnostic
                            (format ": %s" diagnostic)
                          "")))
              'face (if success 'success 'error))))))
      (if success
          (progn
            (bs-contacts--invalidate-cache)
            (message "Contact sync succeeded: %s"
                     (string-join collections ", ")))
        (when (buffer-live-p buffer)
          (display-buffer buffer))
        (message "Contact sync failed (status %s)%s; see %s"
                 exit-status
                 (if diagnostic
                     (format ": %s" diagnostic)
                   "")
                 (if (buffer-live-p buffer)
                     (buffer-name buffer)
                   bs-contacts-sync-buffer-name))))))

;;;###autoload
(defun bs-contacts-sync (&optional force)
  "Synchronize configured contact collections asynchronously.

With non-nil FORCE, pass `--force-delete' to vdirsyncer.  An
interactive prefix argument requests FORCE and requires an explicit
confirmation before the process starts.  Programmatic callers may use
`(bs-contacts-sync \='force)'.  This command synchronizes only
`bs-contacts-sync-collections', never calendar or undisclosed
collections.  Return the new process."
  (interactive "P")
  (when (bs-contacts--sync-running-p)
    (display-buffer (process-buffer bs-contacts--sync-process))
    (user-error "Contact synchronization is already running"))
  (unless bs-contacts-sync-collections
    (user-error "No contact sync collections are configured"))
  (when (and force
             (called-interactively-p 'any)
             (not
              (yes-or-no-p
               (format
                "Force deletion for contact collections %s? "
                (string-join bs-contacts-sync-collections ", ")))))
    (user-error "Forced contact synchronization canceled"))
  (let* ((collections
          (delete-dups (copy-sequence bs-contacts-sync-collections)))
         (command
          (append
           (list bs-contacts-vdirsyncer-command "sync")
           (when force (list "--force-delete"))
           collections))
         (buffer (get-buffer-create bs-contacts-sync-buffer-name))
         process)
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Command: %S\n\n" command))
        (special-mode)))
    (condition-case error-data
        (setq process
              (make-process
               :name "bs-contacts-sync"
               :buffer buffer
               :command command
               :connection-type 'pipe
               :coding 'utf-8-unix
               :noquery t
               :sentinel #'bs-contacts--sync-sentinel
               :stderr buffer))
      (file-missing
       (user-error "Cannot run vdirsyncer command %s: %s"
                   bs-contacts-vdirsyncer-command
                   (error-message-string error-data))))
    (process-put process 'bs-contacts-collections collections)
    (setq bs-contacts--sync-process process)
    (process-send-eof process)
    (display-buffer buffer)
    (message "Contact synchronization started: %s"
             (string-join collections ", "))
    process))

;;;###autoload
(defun bs-contacts-edit-submit ()
  "Submit the current contact YAML buffer through khard.

Creation targets `bs-contacts--edit-addressbook'.  Editing targets the
combination of that address book and `bs-contacts--edit-uid'.  On
success, invalidate the derived contact cache and kill this buffer.
On failure, preserve the buffer and its contents for correction."
  (interactive)
  (unless (derived-mode-p 'bs-contacts-edit-mode)
    (user-error "This is not a contact YAML edit buffer"))
  (when (bs-contacts--sync-running-p)
    (user-error "Cannot submit contact changes while synchronization is running"))
  (let ((operation bs-contacts--edit-operation)
        (addressbook-id bs-contacts--edit-addressbook)
        (uid bs-contacts--edit-uid)
        output)
    (setq output
          (bs-contacts--with-yaml-input-file
           (lambda (input-file)
             (pcase operation
               ('create
                (bs-contacts--khard-new addressbook-id input-file))
               ('edit
                (unless uid
                  (error "Contact edit buffer has no UID"))
                (bs-contacts--khard-edit addressbook-id uid input-file))
               (_
                (error "Unknown contact edit operation: %S" operation))))))
    (bs-contacts--invalidate-cache)
    (set-buffer-modified-p nil)
    (kill-buffer (current-buffer))
    (message "Khard contact %s succeeded%s"
             operation
             (if (string-empty-p (string-trim output))
                 ""
               (format ": %s" (string-trim output))))
    output))

;;;###autoload
(defun bs-contacts-edit-cancel ()
  "Cancel the current contact YAML edit and kill its buffer.

When the buffer is modified, ask for confirmation before discarding
the unsent YAML.  No local vCard file is changed."
  (interactive)
  (unless (derived-mode-p 'bs-contacts-edit-mode)
    (user-error "This is not a contact YAML edit buffer"))
  (when (or (not (buffer-modified-p))
            (yes-or-no-p "Discard unsent contact changes? "))
    (set-buffer-modified-p nil)
    (kill-buffer (current-buffer))))

;;;###autoload
(defun bs-contacts-create ()
  "Open a khard YAML buffer for a new local contact.

The target is the configured default writable address book.  This
command reads a template but does not create a vCard until the user
submits the buffer with `bs-contacts-edit-submit'.  Return the new edit
buffer."
  (interactive)
  (let ((addressbook-id (bs-contacts--default-addressbook-id)))
    (bs-contacts--ensure-writable-addressbook addressbook-id)
    (bs-contacts--open-edit-buffer
     'create
     addressbook-id
     nil
     (bs-contacts--khard-template))))

(defun bs-contacts--contact-writable-p (contact)
  "Return non-nil when CONTACT belongs to the default writable address book."
  (let* ((addressbook-id (bs-contacts-contact-addressbook contact))
         (addressbook (cdr (assoc addressbook-id bs-contacts-addressbooks)))
         (default-id
          (bs-contacts--metadata-get bs-contacts-default-addressbook 'id)))
    (and addressbook
         (equal addressbook-id default-id)
         (not (bs-contacts--metadata-get addressbook 'readOnly)))))

;;;###autoload
(defun bs-contacts-edit (&optional contact)
  "Open CONTACT in a controlled khard YAML edit buffer.

Interactively, select a contact from the default writable address
book.  CONTACT is located by its address book and UID, never by its
display name.  This command only reads YAML; changes reach the local
vCard when the user invokes `bs-contacts-edit-submit'.  Return the edit
buffer."
  (interactive)
  (let* ((selected-contact
          (or contact
              (bs-contacts--select-contact
               "Edit contact: "
               #'bs-contacts--contact-writable-p)))
         (addressbook-id
          (bs-contacts-contact-addressbook selected-contact))
         (uid (bs-contacts-contact-uid selected-contact)))
    (bs-contacts--ensure-writable-addressbook addressbook-id)
    (let ((existing
           (bs-contacts--existing-edit-buffer addressbook-id uid)))
      (if existing
          (progn
            (pop-to-buffer existing)
            (message "Reusing existing edit buffer for contact %s" uid)
            existing)
        (bs-contacts--open-edit-buffer
         'edit
         addressbook-id
         uid
         (bs-contacts--khard-show addressbook-id uid 'yaml))))))

;;;###autoload
(defun bs-contacts-delete (&optional contact)
  "Confirm and delete CONTACT from its local writable address book.

Interactively, select a contact from the default writable address
book.  The confirmation identifies the name, primary email, address
book, and UID.  A successful deletion invalidates the derived cache
but does not run vdirsyncer or delete anything remotely.  Return
non-nil only after a successful deletion."
  (interactive)
  (let* ((selected-contact
          (or contact
              (bs-contacts--select-contact
               "Delete contact: "
               #'bs-contacts--contact-writable-p)))
         (addressbook-id
          (bs-contacts-contact-addressbook selected-contact))
         (uid (bs-contacts-contact-uid selected-contact))
         (label (bs-contacts--contact-label selected-contact)))
    (bs-contacts--ensure-writable-addressbook addressbook-id)
    (if (not (yes-or-no-p
              (format "Delete %s locally? " label)))
        (progn
          (message "Contact deletion canceled")
          nil)
      (let ((output
             (bs-contacts--khard-remove addressbook-id uid)))
        (bs-contacts--invalidate-cache)
        (message "Deleted contact locally: %s%s"
                 label
                 (if (string-empty-p (string-trim output))
                     ""
                   (format " (%s)" (string-trim output))))
        t))))

(defun bs-contacts--contact-mail-candidates (contact)
  "Return one khard mail candidate per email address in CONTACT."
  (require 'bs-mu4e)
  (let ((name
         (bs-mu4e-trim-contact-name
          (bs-contacts-contact-name contact))))
    (mapcar
     (lambda (email)
       (let* ((display
               (if name
                   (format "%s <%s>" name email)
                 email))
              (clean-display
               (bs-mu4e-clean-mail-address display)))
         (bs-contacts-mail-candidate-create
          :email email
          :display clean-display
          :source 'khard
          :contact contact)))
     (bs-contacts-contact-emails contact))))

(defun bs-contacts--khard-mail-candidates ()
  "Return mail candidates from all enabled khard contacts.

Each contact email produces a distinct candidate.  Contacts without
email addresses produce none."
  (mapcan #'bs-contacts--contact-mail-candidates
          (bs-contacts--contacts)))

(defun bs-contacts--normalized-email (address)
  "Return the normalized email identity parsed from ADDRESS, or nil."
  (require 'bs-mu4e)
  (let* ((parsed (and (stringp address)
                      (mail-header-parse-address-lax address)))
         (email (if (consp parsed) (car parsed) parsed)))
    (when (and (stringp email)
               (bs-mu4e-email-address-p (string-trim email)))
      (downcase (string-trim email)))))

(defun bs-contacts--mu4e-mail-candidates (contacts-set)
  "Return cleaned mail candidates from mu4e CONTACTS-SET."
  (require 'bs-mu4e)
  (let (candidates)
    (when (hash-table-p contacts-set)
      (maphash
       (lambda (display _value)
         (when-let* ((clean-display
                      (bs-mu4e-completion-candidate display))
                     (email
                      (bs-contacts--normalized-email clean-display)))
           (push
            (bs-contacts-mail-candidate-create
             :email email
             :display clean-display
             :source 'mu4e)
            candidates)))
       contacts-set))
    (nreverse candidates)))

(defun bs-contacts-mail-completion-set (&optional mu4e-contacts-set)
  "Return merged khard and MU4E-CONTACTS-SET mail completions.

The return value is a hash table compatible with
`mu4e--contacts-set'.  Candidates are deduplicated by normalized email
address.  Khard is authoritative: when both sources contain the same
email, its cleaned display name replaces the mu4e history name.
Existing bs-mu4e automated-sender filters apply to both sources."
  (require 'bs-mu4e)
  (let ((by-email (make-hash-table :test #'equal))
        (completion-set (make-hash-table :test #'equal)))
    (dolist (candidate
             (bs-contacts--mu4e-mail-candidates mu4e-contacts-set))
      (puthash (bs-contacts-mail-candidate-email candidate)
               candidate
               by-email))
    (dolist (candidate (bs-contacts--khard-mail-candidates))
      (when-let* ((display
                   (bs-mu4e-completion-candidate
                    (bs-contacts-mail-candidate-display candidate)))
                  (email
                   (bs-contacts--normalized-email
                    (bs-contacts-mail-candidate-email candidate))))
        (setf (bs-contacts-mail-candidate-display candidate) display
              (bs-contacts-mail-candidate-email candidate) email)
        (puthash email candidate by-email)))
    (maphash
     (lambda (_email candidate)
       (puthash (bs-contacts-mail-candidate-display candidate)
                t
                completion-set))
     by-email)
    completion-set))

(provide 'bs-contacts)
;;; bs-contacts.el ends here
