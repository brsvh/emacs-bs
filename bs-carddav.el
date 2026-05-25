;;; bs-carddav.el --- CardDAV bridge  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Bingshan Chang

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

;; This package provides a small CardDAV bridge for the personal
;; contact workflow.  It reads addressbook configuration from
;; `bs-carddav-addressbooks' and performs explicit, user-invoked
;; CardDAV requests.  It does not enable background synchronization on
;; load.

;;; Code:

(require 'auth-source)
(require 'cl-lib)
(require 'eieio)
(require 'subr-x)
(require 'url)
(require 'url-http)
(require 'url-parse)
(require 'xml)

(defvar url-http-end-of-headers)
(defvar url-http-response-status)

(declare-function ebdb-db-add-record "ebdb" (db record))
(declare-function ebdb-gethash "ebdb" (key &optional predicate))
(declare-function ebdb-init-record "ebdb" (record))
(declare-function ebdb-load "ebdb" ())
(declare-function ebdb-parse "ebdb" (class str &optional slots))
(declare-function ebdb-record-delete-field "ebdb" (record field &optional slot))
(declare-function ebdb-record-field "ebdb" (record field))
(declare-function ebdb-record-insert-field "ebdb" (record field &optional slot))
(declare-function ebdb-record-mail "ebdb" (record &optional no-roles label defunct))
(declare-function ebdb-save "ebdb" (&optional interactive))
(declare-function org-vcard-import-parse "org-vcard" (source &optional filename))

(defvar ebdb-after-change-hook)
(defvar ebdb-change-hook)
(defvar ebdb-create-hook)
(defvar ebdb-db-list)
(defvar ebdb-default-name-class)
(defvar org-vcard-active-version)

(defgroup bs-carddav nil
  "Personal CardDAV bridge."
  :group 'applications)

(defcustom bs-carddav-addressbooks nil
  "Configured CardDAV addressbooks.

Each entry is an alist.  Expected fields include `id', `name',
`addressbook-id', `url', `readOnly', `source', `accountName' and
`default'."
  :type 'alist
  :group 'bs-carddav)

(defcustom bs-carddav-writable-addressbooks nil
  "Configured CardDAV addressbooks that can be written to."
  :type 'alist
  :group 'bs-carddav)

(defcustom bs-carddav-read-only-addressbooks nil
  "Configured CardDAV addressbooks that should not be written to."
  :type 'alist
  :group 'bs-carddav)

(defcustom bs-carddav-request-timeout 60
  "Maximum seconds to wait for a synchronous CardDAV request."
  :type 'number
  :group 'bs-carddav)

(cl-defstruct bs-carddav-card
  addressbook-id href etag data)

(cl-defstruct bs-carddav-import-result
  created updated skipped records)

(defconst bs-carddav--metadata-labels
  '((addressbook-id . "BINGSHAN_ADDRESSBOOK_ID")
    (href . "BINGSHAN_CARDDAV_HREF")
    (etag . "BINGSHAN_CARDDAV_ETAG")
    (uid . "BINGSHAN_VCARD_UID")
    (last-synced-at . "BINGSHAN_LAST_SYNCED_AT"))
  "EBDB user field labels used to store CardDAV sync metadata.")

(defun bs-carddav--key (key)
  "Return KEY as a symbol suitable for configuration alists."
  (if (symbolp key)
      key
    (intern key)))

(defun bs-carddav--get (alist key &optional default)
  "Return KEY from ALIST, or DEFAULT when missing."
  (alist-get (bs-carddav--key key) alist default nil #'eq))

(defun bs-carddav--addressbook-id (entry)
  "Return the stable id for addressbook ENTRY."
  (or (bs-carddav--get (cdr entry) 'id)
      (symbol-name (car entry))))

(defun bs-carddav--addressbook-name (entry)
  "Return the display name for addressbook ENTRY."
  (or (bs-carddav--get (cdr entry) 'name)
      (bs-carddav--addressbook-id entry)))

(defun bs-carddav--addressbook-url (entry)
  "Return the collection URL for addressbook ENTRY."
  (or (bs-carddav--get (cdr entry) 'url)
      (user-error "Addressbook %s has no URL"
                  (bs-carddav--addressbook-id entry))))

(defun bs-carddav--addressbook-default-p (entry)
  "Return non-nil when ENTRY is the default addressbook."
  (bs-carddav--get (cdr entry) 'default))

(defun bs-carddav--addressbook-candidates ()
  "Return configured addressbook candidates for completion."
  (mapcar (lambda (entry)
            (cons (format "%s <%s>"
                          (bs-carddav--addressbook-name entry)
                          (bs-carddav--addressbook-id entry))
                  entry))
          bs-carddav-addressbooks))

(defun bs-carddav-default-addressbook ()
  "Return the configured default CardDAV addressbook entry."
  (or (cl-find-if #'bs-carddav--addressbook-default-p
                  bs-carddav-addressbooks)
      (car bs-carddav-writable-addressbooks)
      (car bs-carddav-addressbooks)
      (user-error "No CardDAV addressbook is configured")))

(defun bs-carddav-read-addressbook ()
  "Read and return a configured addressbook entry."
  (let* ((candidates (bs-carddav--addressbook-candidates))
         (default-entry (bs-carddav-default-addressbook))
         (default (car (cl-find-if
                        (lambda (candidate)
                          (eq (cdr candidate) default-entry))
                        candidates)))
         (choice (completing-read "Addressbook: "
                                  candidates nil t nil nil default)))
    (cdr (assoc choice candidates))))

(defun bs-carddav--url-user (url)
  "Return the CardDAV user parsed from URL."
  (when (string-match "/addressbooks/users/\\([^/]+\\)/" url)
    (match-string 1 url)))

(defun bs-carddav--auth-source-password (host user)
  "Return password for HOST and USER via auth-source."
  (let* ((match (car (auth-source-search :host host
                                         :user user
                                         :require '(:secret)
                                         :max 1)))
         (secret (plist-get match :secret)))
    (unless secret
      (user-error "No auth-source secret found for %s@%s" user host))
    (if (functionp secret)
        (funcall secret)
      secret)))

(defun bs-carddav--auth-header (url)
  "Return an Authorization header alist for URL."
  (let* ((parsed (url-generic-parse-url url))
         (host (url-host parsed))
         (user (or (url-user parsed)
                   (bs-carddav--url-user url))))
    (unless user
      (user-error "Cannot infer CardDAV user from URL: %s" url))
    (list (cons "Authorization"
                (concat "Basic "
                        (base64-encode-string
                         (format "%s:%s"
                                 user
                                 (bs-carddav--auth-source-password host user))
                         t))))))

(defun bs-carddav--request (method url &optional body headers)
  "Synchronously request METHOD URL with BODY and HEADERS.

Return the decoded response body as a string.  This function uses
Emacs' built-in URL library because WebDAV methods such as REPORT
and PROPFIND are first-class CardDAV requests."
  (let ((url-request-method method)
        (url-request-data body)
        (url-request-extra-headers
         (append headers (bs-carddav--auth-header url))))
    (with-current-buffer
        (or (url-retrieve-synchronously url t t
                                        bs-carddav-request-timeout)
            (user-error "No response from %s" url))
      (unwind-protect
          (let ((status url-http-response-status)
                (body-start url-http-end-of-headers))
            (unless (and status (<= 200 status 299))
              (user-error "CardDAV %s %s failed with HTTP %s"
                          method url status))
            (unless body-start
              (user-error "CardDAV %s %s returned no body" method url))
            (decode-coding-string
             (buffer-substring-no-properties body-start (point-max))
             'utf-8))
        (kill-buffer (current-buffer))))))

(defun bs-carddav--addressbook-query-body ()
  "Return a CardDAV addressbook-query REPORT body."
  "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<C:addressbook-query xmlns:D=\"DAV:\"
                     xmlns:C=\"urn:ietf:params:xml:ns:carddav\">
  <D:prop>
    <D:getetag />
    <C:address-data />
  </D:prop>
</C:addressbook-query>")

(defun bs-carddav--report-addressbook (entry)
  "Run an addressbook-query REPORT for ENTRY."
  (bs-carddav--request
   "REPORT"
   (bs-carddav--addressbook-url entry)
   (bs-carddav--addressbook-query-body)
   '(("Content-Type" . "application/xml; charset=utf-8")
     ("Depth" . "1"))))

(defun bs-carddav--xml-name (node)
  "Return NODE's local XML name as a string."
  (when (consp node)
    (let ((name (symbol-name (car node))))
      (if (string-match "\\([^:]+\\)\\'" name)
          (match-string 1 name)
        name))))

(defun bs-carddav--xml-children (node name)
  "Return NODE children whose local XML name is NAME."
  (cl-loop for child in (cddr node)
           when (and (consp child)
                     (string= (bs-carddav--xml-name child) name))
           collect child))

(defun bs-carddav--xml-first-child (node name)
  "Return NODE's first child whose local XML name is NAME."
  (car (bs-carddav--xml-children node name)))

(defun bs-carddav--xml-text (node)
  "Return concatenated text under XML NODE."
  (string-trim
   (apply #'concat
          (cl-loop for child in (cddr node)
                   if (stringp child)
                   collect child
                   else if (consp child)
                   collect (bs-carddav--xml-text child)))))

(defun bs-carddav--parse-multistatus (xml addressbook-id)
  "Parse XML multistatus and return cards for ADDRESSBOOK-ID."
  (cl-loop
   with root = (car xml)
   for response in (bs-carddav--xml-children root "response")
   for href = (bs-carddav--xml-text
               (bs-carddav--xml-first-child response "href"))
   for propstat = (bs-carddav--xml-first-child response "propstat")
   for prop = (and propstat
                   (bs-carddav--xml-first-child propstat "prop"))
   for etag = (and prop
                   (bs-carddav--xml-text
                    (bs-carddav--xml-first-child prop "getetag")))
   for data = (and prop
                   (bs-carddav--xml-text
                    (bs-carddav--xml-first-child prop "address-data")))
   when (and href data (not (string-empty-p data)))
   collect (make-bs-carddav-card :addressbook-id addressbook-id
                                 :href href
                                 :etag etag
                                 :data data)))

(defun bs-carddav--parse-addressbook-query (body entry)
  "Parse addressbook-query BODY for addressbook ENTRY."
  (with-temp-buffer
    (insert body)
    (let ((xml (xml-parse-region (point-min) (point-max))))
      (bs-carddav--parse-multistatus
       xml
       (bs-carddav--addressbook-id entry)))))

(defun bs-carddav-pull (&optional addressbook)
  "Pull vCards from ADDRESSBOOK and return `bs-carddav-card' objects."
  (let* ((entry (or addressbook (bs-carddav-default-addressbook)))
         (body (bs-carddav--report-addressbook entry)))
    (bs-carddav--parse-addressbook-query body entry)))

(defun bs-carddav--vcard-version (vcard)
  "Return VCARD's VERSION value, defaulting to 4.0."
  (if (string-match "^VERSION:\\([0-9.]+\\)\r?$" vcard)
      (match-string 1 vcard)
    "4.0"))

(defun bs-carddav--parse-vcard (vcard)
  "Parse VCARD using `org-vcard' and return its first card alist."
  (require 'org-vcard)
  (let ((org-vcard-active-version (bs-carddav--vcard-version vcard)))
    (with-temp-buffer
      (insert vcard)
      (car (org-vcard-import-parse "buffer")))))

(defun bs-carddav--vcard-property-base (property)
  "Return PROPERTY's base name without group or parameters."
  (let ((base (upcase (car (split-string property ";")))))
    (if (string-match "\\.\\([^.]+\\)\\'" base)
        (match-string 1 base)
      base)))

(defun bs-carddav--vcard-values (parsed property)
  "Return values for PROPERTY from PARSED vCard data."
  (let ((property (upcase property)))
    (cl-loop for entry in parsed
             when (string= (bs-carddav--vcard-property-base (car entry))
                           property)
             collect (bs-carddav--vcard-unescape (cdr entry)))))

(defun bs-carddav--vcard-value (parsed property)
  "Return the first value for PROPERTY from PARSED vCard data."
  (car (bs-carddav--vcard-values parsed property)))

(defun bs-carddav--vcard-unescape (value)
  "Unescape a vCard VALUE."
  (when value
    (replace-regexp-in-string
     "\\\\[nN]" "\n"
     (replace-regexp-in-string
      "\\\\\\([,;:\\\\]\\)" "\\1" value))))

(defun bs-carddav--vcard-n-name (value)
  "Return a display name derived from an N property VALUE."
  (when value
    (let* ((parts (split-string value ";"))
           (surname (nth 0 parts))
           (given (nth 1 parts))
           (additional (nth 2 parts))
           (prefix (nth 3 parts))
           (suffix (nth 4 parts))
           (name (string-join
                  (delq nil
                        (mapcar (lambda (part)
                                  (unless (string-empty-p part)
                                    part))
                                (list prefix given additional surname suffix)))
                  " ")))
      (unless (string-empty-p name)
        name))))

(defun bs-carddav--parsed-card-name (parsed)
  "Return the display name for PARSED vCard data."
  (or (bs-carddav--vcard-value parsed "FN")
      (bs-carddav--vcard-n-name (bs-carddav--vcard-value parsed "N"))
      (car (bs-carddav--parsed-card-emails parsed))
      "Unnamed contact"))

(defun bs-carddav--normalize-email (email)
  "Return normalized EMAIL used for deduplication."
  (downcase (string-trim (or email ""))))

(defun bs-carddav--parsed-card-emails (parsed)
  "Return normalized email addresses from PARSED vCard data."
  (delete-dups
   (cl-loop for email in (bs-carddav--vcard-values parsed "EMAIL")
            for normalized = (bs-carddav--normalize-email email)
            unless (string-empty-p normalized)
            collect normalized)))

(defun bs-carddav--slot (object slot)
  "Return OBJECT's SLOT value when it exists and is bound."
  (when (and (slot-exists-p object slot)
             (slot-boundp object slot))
    (eieio-oref object slot)))

(defun bs-carddav--metadata-label (key)
  "Return the EBDB metadata label for KEY."
  (or (alist-get key bs-carddav--metadata-labels)
      (error "Unknown bs-carddav metadata key: %S" key)))

(defun bs-carddav--card-metadata (card parsed)
  "Return sync metadata alist for CARD and PARSED vCard data."
  `((addressbook-id . ,(bs-carddav-card-addressbook-id card))
    (href . ,(bs-carddav-card-href card))
    (etag . ,(bs-carddav-card-etag card))
    (uid . ,(bs-carddav--vcard-value parsed "UID"))
    (last-synced-at . ,(format-time-string "%Y-%m-%dT%H:%M:%S%z"))))

(defun bs-carddav--require-ebdb ()
  "Load EBDB and return the first configured database."
  (require 'ebdb)
  (unless ebdb-db-list
    (ebdb-load))
  (or (car ebdb-db-list)
      (user-error "No EBDB database is configured")))

(defun bs-carddav--ebdb-record-by-email (emails)
  "Return the first EBDB record matching one of EMAILS."
  (cl-loop for email in emails
           for records = (ebdb-gethash email '(mail))
           when records
           return (car records)))

(defun bs-carddav--ebdb-record-emails (record)
  "Return normalized email addresses already present in RECORD."
  (mapcar (lambda (field)
            (bs-carddav--normalize-email (bs-carddav--slot field 'mail)))
          (ebdb-record-mail record nil nil t)))

(defun bs-carddav--ebdb-add-email (record email)
  "Add EMAIL to EBDB RECORD unless it is already present."
  (unless (member (bs-carddav--normalize-email email)
                  (bs-carddav--ebdb-record-emails record))
    (ebdb-record-insert-field
     record
     (make-instance 'ebdb-field-mail
                    :mail email
                    :priority 'normal)
     'mail)))

(defun bs-carddav--ebdb-create-record (db name emails)
  "Create an EBDB record in DB with NAME and EMAILS."
  (let* ((mail-fields
          (cl-loop for email in emails
                   for first = t then nil
                   collect (make-instance 'ebdb-field-mail
                                          :mail email
                                          :priority (if first
                                                        'primary
                                                      'normal))))
         (record (make-instance
                  'ebdb-record-person
                  :name (ebdb-parse ebdb-default-name-class name)
                  :mail mail-fields)))
    (ebdb-db-add-record db record)
    (ebdb-init-record record)
    (run-hook-with-args 'ebdb-create-hook record)
    (run-hook-with-args 'ebdb-change-hook record)
    (run-hook-with-args 'ebdb-after-change-hook record)
    record))

(defun bs-carddav--ebdb-user-field (record label)
  "Return RECORD's EBDB user field named LABEL."
  (cl-find-if (lambda (field)
                (and (object-of-class-p field 'ebdb-field-user-simple)
                     (equal (bs-carddav--slot field 'label) label)))
              (ebdb-record-field record 'fields)))

(defun bs-carddav--ebdb-user-field-value (record label)
  "Return RECORD's EBDB user field value named LABEL."
  (when-let* ((field (bs-carddav--ebdb-user-field record label)))
    (bs-carddav--slot field 'value)))

(defun bs-carddav--ebdb-set-user-field (record label value)
  "Set RECORD's EBDB user field LABEL to VALUE."
  (when value
    (let ((field (bs-carddav--ebdb-user-field record label)))
      (unless (and field (equal (bs-carddav--slot field 'value) value))
        (when field
          (ebdb-record-delete-field record field))
        (ebdb-record-insert-field
         record
         (make-instance 'ebdb-field-user-simple
                        :label label
                        :value value))))))

(defun bs-carddav--set-sync-metadata (record card parsed)
  "Store CardDAV metadata for RECORD from CARD and PARSED vCard."
  (dolist (entry (bs-carddav--card-metadata card parsed))
    (bs-carddav--ebdb-set-user-field
     record
     (bs-carddav--metadata-label (car entry))
     (cdr entry))))

(defun bs-carddav--import-card-to-ebdb (card db)
  "Import CARD into EBDB database DB.

Return a cons of status and message or record.  Status is one of
`created', `updated' or `skipped'."
  (let* ((parsed (bs-carddav--parse-vcard (bs-carddav-card-data card)))
         (emails (bs-carddav--parsed-card-emails parsed))
         (name (bs-carddav--parsed-card-name parsed))
         (record (and emails
                      (bs-carddav--ebdb-record-by-email emails))))
    (cond
     ((null emails)
      (cons 'skipped
            (format "Skipped %s: no email address"
                    (or (bs-carddav-card-href card) name))))
     ((let ((href (and record
                       (bs-carddav--ebdb-user-field-value
                        record (bs-carddav--metadata-label 'href)))))
        (and href
             (not (string-empty-p href))
             (not (equal href (bs-carddav-card-href card)))))
      (cons 'skipped
            (format "Skipped %s: email already belongs to another CardDAV href"
                    (bs-carddav-card-href card))))
     (record
      (dolist (email emails)
        (bs-carddav--ebdb-add-email record email))
      (bs-carddav--set-sync-metadata record card parsed)
      (cons 'updated record))
     (t
      (let ((record (bs-carddav--ebdb-create-record db name emails)))
        (bs-carddav--set-sync-metadata record card parsed)
        (cons 'created record))))))

(defun bs-carddav-import-cards-to-ebdb (cards)
  "Import CARDS into EBDB and return a `bs-carddav-import-result'."
  (let ((db (bs-carddav--require-ebdb))
        created
        updated
        skipped
        records)
    (dolist (card cards)
      (pcase (bs-carddav--import-card-to-ebdb card db)
        (`(created . ,record)
         (push record created)
         (push record records))
        (`(updated . ,record)
         (push record updated)
         (push record records))
        (`(skipped . ,message)
         (push message skipped))))
    (make-bs-carddav-import-result
     :created (nreverse created)
     :updated (nreverse updated)
     :skipped (nreverse skipped)
     :records (nreverse records))))

(defun bs-carddav--card-name (card)
  "Return a display name for CARD."
  (condition-case nil
      (bs-carddav--parsed-card-name
       (bs-carddav--parse-vcard (bs-carddav-card-data card)))
    (error (or (bs-carddav-card-href card) "Unreadable contact"))))

(defun bs-carddav--insert-card-line (card)
  "Insert one summary line for CARD."
  (insert (format "%-40s %s\n"
                  (bs-carddav--card-name card)
                  (or (bs-carddav-card-etag card) "")))
  (insert (format "  %s\n" (bs-carddav-card-href card))))

;;;###autoload
(defun bs-carddav-pull-preview (&optional addressbook)
  "Pull contacts from ADDRESSBOOK and show a read-only summary buffer.

This command only reads CardDAV data.  It does not import into EBDB
and does not write remote contacts."
  (interactive (list (bs-carddav-read-addressbook)))
  (let* ((entry (or addressbook (bs-carddav-default-addressbook)))
         (cards (bs-carddav-pull entry))
         (buffer (get-buffer-create "*bs-carddav-pull*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Addressbook: %s\n"
                        (bs-carddav--addressbook-id entry)))
        (insert (format "Contacts: %d\n\n" (length cards)))
        (dolist (card cards)
          (bs-carddav--insert-card-line card))
        (goto-char (point-min))
        (view-mode 1)))
    (pop-to-buffer buffer)))

;;;###autoload
(defun bs-carddav-import-to-ebdb (&optional addressbook save)
  "Pull ADDRESSBOOK and import contacts into EBDB.

With prefix argument SAVE, save EBDB after importing."
  (interactive (list (bs-carddav-read-addressbook)
                     current-prefix-arg))
  (let* ((entry (or addressbook (bs-carddav-default-addressbook)))
         (cards (bs-carddav-pull entry))
         (result (bs-carddav-import-cards-to-ebdb cards))
         (created (length (bs-carddav-import-result-created result)))
         (updated (length (bs-carddav-import-result-updated result)))
         (skipped (length (bs-carddav-import-result-skipped result))))
    (when save
      (ebdb-save t))
    (message "Imported contacts: %d created, %d updated, %d skipped"
             created updated skipped)
    result))

;;;###autoload
(defun bs-carddav-sync ()
  "Synchronize contacts.

Full synchronization is not implemented yet.  Use
`bs-carddav-pull-preview' to preview CardDAV data or
`bs-carddav-import-to-ebdb' for the current read-only remote import
path."
  (interactive)
  (user-error "Full contact sync is not implemented yet"))

;;;###autoload
(defun bs-carddav-push ()
  "Push local contacts to CardDAV.

Write-back is not implemented yet."
  (interactive)
  (user-error "Contact push is not implemented yet"))

;;;###autoload
(defun bs-carddav-sync-current ()
  "Synchronize the current contact.

Per-contact synchronization is not implemented yet."
  (interactive)
  (user-error "Current contact sync is not implemented yet"))


(provide 'bs-carddav)
;;; bs-carddav.el ends here
