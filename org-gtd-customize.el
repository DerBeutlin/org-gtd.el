;;; org-gtd-customize.el --- Custom variables for org-gtd -*- lexical-binding: t; coding: utf-8 -*-
;;
;; Copyright © 2019-2023 Aldric Giacomoni

;; Author: Aldric Giacomoni <trevoke@gmail.com>
;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; User-customizable options for org-gtd.
;;
;;; Code:

(require 'subr-x)

(defgroup org-gtd nil
  "Customize the org-gtd package."
  :link '(url-link "https://github.com/Trevoke/org-gtd.el")
  :package-version '(org-gtd . "0.1")
  :group 'org)

(defcustom org-gtd-directory "~/gtd/"
  "Directory for org-gtd.

The package will use this directory for all its functionality, whether it is
building the agenda or refiling items.  This is the directory where you will
find the default org-gtd file, and it is the directory where you should place
your own files if you want multiple refile targets (projects, etc.)."
  :group 'org-gtd
  :package-version '(org-gtd . "0.1")
  :type 'directory)

(defcustom org-gtd-process-item-hooks '(org-set-tags-command)
  "Enhancements to add to each item as they get processed from the inbox.

This is a list of functions that modify an org element.  The default value has
one function: setting org tags on the item.  Some built-in examples are
provided as options here.  You can create your own functions to enhance/decorate
the items once they have been processed and add them to that list."
  :group 'org-gtd
  :package-version '(org-gtd . "1.0.4")
  :type 'hook
  :options '(org-set-tags-command org-set-effort org-priority))

(defcustom org-gtd-archive-location
  (lambda ()
    (let ((year (number-to-string (caddr (calendar-current-date)))))
      (string-join `("gtd_archive_" ,year "::datetree/"))))
  "Function to generate archive location for org gtd.

That is to say, when items get cleaned up from the active files, they will go
to whatever file/tree is generated by this function.  See `org-archive-location'
to learn more about the valid values generated.  Note that this will only be
the file used by the standard `org-archive' functions if you
enable command `org-gtd-mode'.  If not, this will be used only by
org-gtd's archive behavior.

This function has an arity of zero.  By default this generates a file
called gtd_archive_<currentyear> in `org-gtd-directory' and puts the entries
into a datetree."
  :group 'org-gtd
  :type 'sexp
  :package-version '(org-gtd . "2.0.0"))

(defcustom org-gtd-capture-templates
  '(("i" "Inbox" "* %?\n%U\n\n  %i")
    ("l" "Inbox with link" "* %?\n%U\n\n  %i\n  %a"))
  "Capture templates to be used when adding something to the inbox.

This is a list of lists.  Each list is composed of three elements:

\(KEYS DESCRIPTION TEMPLATE)
see `org-capture-templates' for the definition of each of those items.
Make the sure the template string starts with a single asterisk to denote a
top level heading, or the behavior of org-gtd will be undefined."
  :group 'org-gtd
  :type 'sexp
  :package-version '(org-gtd . "2.0.0"))

(defcustom org-gtd-agenda-custom-commands
  '(("g" "Scheduled today and all NEXT items"
     (
      (agenda "" ((org-agenda-span 1)
                  (org-agenda-start-day nil)))
      (todo "NEXT" ((org-agenda-overriding-header "All NEXT items")
                    (org-agenda-prefix-format '((todo . " %i %-12:(org-gtd--agenda-prefix-format)")))))
      (todo "WAIT" ((org-agenda-todo-ignore-with-date t)
                    (org-agenda-overriding-header "Delegated/Blocked items")
                    (org-agenda-prefix-format '((todo . " %i %-12 (org-gtd--agenda-prefix-format)"))))))))
  "Agenda custom commands to be used for org-gtd.

The provided default is to show the agenda for today and all TODOs marked as
NEXT or WAIT.  See documentation for `org-agenda-custom-commands' to customize
this further.

NOTE! The function `org-gtd-engage' assumes the 'g' shortcut exists.
It's recommended you add to this list without modifying this first entry.  You
can leverage this customization feature with command `org-gtd-mode'
or by wrapping your own custom functions with `with-org-gtd-context'."
  :group 'org-gtd
  :type 'sexp
  :package-version '(org-gtd . "2.0.0"))

(defcustom org-gtd-refile-to-any-target t
  "Set to true if you do not need to choose where to refile processed items.

When this is true, org-gtd will refile to the first target it finds, or creates
if necessary, without confirmation.  When this is false, it will ask for
confirmation regardless of the number of options.  Note that setting this to
false does not mean you can safely create new targets.  See the documentation
to create new refile targets.

Defaults to true to carry over pre-2.0 behavior.  You will need to change this
setting if you follow the instructions to add your own refile targets."
  :group 'org-gtd
  :type 'boolean
  :package-version '(org-gtd . "2.0.0"))

;; this was added in emacs 28.1
(unless (fboundp 'string-pad)
  (defun string-pad (string length &optional padding start)
    "Pad STRING to LENGTH using PADDING.
If PADDING is nil, the space character is used.  If not nil, it
should be a character.

If STRING is longer than the absolute value of LENGTH, no padding
is done.

If START is nil (or not present), the padding is done to the end
of the string, and if non-nil, padding is done to the start of
the string."
    (unless (natnump length)
      (signal 'wrong-type-argument (list 'natnump length)))
    (let ((pad-length (- length (length string))))
      (cond ((<= pad-length 0) string)
            (start (concat (make-string pad-length (or padding ?\s)) string))
            (t (concat string (make-string pad-length (or padding ?\s))))))))



(defun org-gtd--agenda-prefix-format ()
  "format prefix for items in buffer"
  (let* ((elt (org-element-at-point))
         (level (org-element-property :level elt))
         (category (org-entry-get (point) "CATEGORY" t))
         (parent-title (org-element-property :raw-value (org-element-property :parent elt))))

    (cond
     ((eq level 3) (concat
                    (substring (string-pad (replace-regexp-in-string
                                            "\[[[:digit:]]+/[[:digit:]]+\][[:space:]]*"
                                            ""
                                            parent-title)
                                           11)
                               0 10)
                    "…"))
     (category (concat (substring (string-pad category 11) 0 10) "…"))
     "Simple task")))

(defcustom org-gtd-delegate-read-func (lambda () (read-string "Who will do this? "))
  "Function that is called to read in the Person the task is delegated to.

Needs to return a string thet will be used as the persons name."
  :group 'org-gtd
  :package-version '(org-gtd . "2.0.0")
  :type 'function )

(provide 'org-gtd-customize)
;;; org-gtd-customize.el ends here
