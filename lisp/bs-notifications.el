;;; bs-notifications.el --- Shared desktop notification queue  -*- lexical-binding:t -*-

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

;; This package serializes desktop notifications from independent clients.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup bs-notifications nil
  "Shared desktop notification delivery."
  :group 'applications)

(defcustom bs-notifications-delivery-interval 1
  "Seconds between consecutive desktop notifications."
  :type 'number
  :group 'bs-notifications)

(defcustom bs-notifications-rate-limit-retry-delay 10
  "Retry delay after desktop notification rate limiting, in seconds."
  :type 'number
  :group 'bs-notifications)

(cl-defstruct
    (bs-notifications--client
     (:constructor bs-notifications--make-client))
  source
  key-function
  delivery-function
  error-function)

(cl-defstruct
    (bs-notifications--item
     (:constructor bs-notifications--make-item))
  client
  pending-key
  record)

(defvar bs-notifications--pending
  (make-hash-table :test #'equal)
  "Namespaced record keys awaiting desktop notification delivery.")

(defvar bs-notifications--queue nil
  "Notification records awaiting serial desktop delivery.")

(defvar bs-notifications--timer nil
  "Timer delivering queued desktop notifications serially.")

(defun bs-notifications-cache-file (directory key)
  "Return the persistent notification cache file for KEY in DIRECTORY."
  (expand-file-name (secure-hash 'sha256 key) directory))

(defun bs-notifications-cache-current-p (file expiry)
  "Return non-nil when cache FILE is nonempty and younger than EXPIRY.
EXPIRY is measured in seconds."
  (when-let* ((attributes (file-attributes file)))
    (and (> (file-attribute-size attributes) 0)
         (< (float-time
             (time-subtract
              (current-time)
              (file-attribute-modification-time attributes)))
            expiry))))

(defun bs-notifications-write-cache-data (file data &optional prefix)
  "Atomically write binary DATA to notification cache FILE.
Use PREFIX for the temporary file name and return FILE on success."
  (let ((directory (file-name-directory file)))
    (make-directory directory t)
    (let ((temporary
           (make-temp-file
            (expand-file-name (or prefix ".notification-") directory))))
      (unwind-protect
          (progn
            (with-temp-buffer
              (set-buffer-multibyte nil)
              (insert data)
              (let ((coding-system-for-write 'binary))
                (write-region (point-min) (point-max)
                              temporary nil 'silent)))
            (rename-file temporary file t)
            (setq temporary nil)
            file)
        (when (and temporary (file-exists-p temporary))
          (delete-file temporary))))))

(cl-defun bs-notifications-create-client
    (&key source key-function delivery-function error-function)
  "Create a shared notification queue client.
SOURCE is a unique symbol that namespaces record keys.  KEY-FUNCTION
returns a stable key for a record.  DELIVERY-FUNCTION attempts to
deliver a record.  ERROR-FUNCTION reports a record and its delivery
error."
  (dolist (function
           (list key-function delivery-function error-function))
    (unless (symbolp function)
      (error "Notification client callback must be a symbol: %S"
             function)))
  (unless (symbolp source)
    (error "Notification client source must be a symbol: %S" source))
  (bs-notifications--make-client
   :source source
   :key-function key-function
   :delivery-function delivery-function
   :error-function error-function))

(defun bs-notifications--rate-limit-error-p (error-data)
  "Return non-nil when ERROR-DATA reports desktop notification rate limiting."
  (string-match-p
   (regexp-quote
    "org.freedesktop.Notifications.Error.ExcessNotificationGeneration")
   (error-message-string error-data)))

(defun bs-notifications--report-error (item error-data)
  "Ask ITEM's client to report ERROR-DATA without failing the queue."
  (let* ((client (bs-notifications--item-client item))
         (function (bs-notifications--client-error-function client)))
    (condition-case report-error
        (funcall function
                 (bs-notifications--item-record item)
                 error-data)
      (error
       (message "Failed to report desktop notification error: %s; %s"
                (error-message-string error-data)
                (error-message-string report-error)))))
  'failed)

(defun bs-notifications--deliver (item)
  "Deliver ITEM and classify temporary notification service failures."
  (let* ((client (bs-notifications--item-client item))
         (function (bs-notifications--client-delivery-function client)))
    (condition-case error-data
        (funcall function (bs-notifications--item-record item))
      (dbus-error
       (if (bs-notifications--rate-limit-error-p error-data)
           'rate-limited
         (bs-notifications--report-error item error-data)))
      (error
       (bs-notifications--report-error item error-data)))))

(defun bs-notifications--schedule (delay)
  "Schedule the next queued notification after DELAY seconds."
  (unless (timerp bs-notifications--timer)
    (setq bs-notifications--timer
          (run-at-time
           (max 0 delay) nil #'bs-notifications--dispatch))))

(defun bs-notifications--dispatch ()
  "Deliver the next shared notification and schedule its successor."
  (setq bs-notifications--timer nil)
  (when-let* ((item (pop bs-notifications--queue)))
    (let ((result (bs-notifications--deliver item)))
      (if (eq result 'rate-limited)
          (progn
            (push item bs-notifications--queue)
            (bs-notifications--schedule
             bs-notifications-rate-limit-retry-delay))
        (remhash (bs-notifications--item-pending-key item)
                 bs-notifications--pending)
        (when bs-notifications--queue
          (bs-notifications--schedule
           bs-notifications-delivery-interval))))))

(defun bs-notifications-enqueue (client record)
  "Queue RECORD for serial delivery by CLIENT.
Return non-nil when RECORD was newly queued."
  (let* ((key-function
          (bs-notifications--client-key-function client))
         (key (funcall key-function record))
         (pending-key
          (cons (bs-notifications--client-source client) key)))
    (unless (gethash pending-key bs-notifications--pending)
      (puthash pending-key t bs-notifications--pending)
      (setq bs-notifications--queue
            (nconc
             bs-notifications--queue
             (list
              (bs-notifications--make-item
               :client client
               :pending-key pending-key
               :record record))))
      (bs-notifications--schedule 0)
      t)))

(defun bs-notifications-key-pending-p (client key)
  "Return non-nil when KEY from CLIENT is queued for delivery."
  (gethash
   (cons (bs-notifications--client-source client) key)
   bs-notifications--pending))

(defun bs-notifications-clear-client (client)
  "Remove every queued notification belonging to CLIENT."
  (let ((source (bs-notifications--client-source client))
        pending-keys)
    (setq bs-notifications--queue
          (cl-delete-if
           (lambda (item)
             (eq source
                 (bs-notifications--client-source
                  (bs-notifications--item-client item))))
           bs-notifications--queue))
    (maphash
     (lambda (key _value)
       (when (eq source (car key))
         (push key pending-keys)))
     bs-notifications--pending)
    (dolist (key pending-keys)
      (remhash key bs-notifications--pending))
    (cond
     ((null bs-notifications--queue)
      (when (timerp bs-notifications--timer)
        (cancel-timer bs-notifications--timer))
      (setq bs-notifications--timer nil))
     ((not (timerp bs-notifications--timer))
      (bs-notifications--schedule 0)))))

(provide 'bs-notifications)
;;; bs-notifications.el ends here
