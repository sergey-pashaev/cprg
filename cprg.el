;;; cprg.el --- Custom Projectile RipGrep search

;; Copyright (C) 2020  Sergey Pashaev

;; Author: Sergey Pashaev <sergey.pashaev@gmail.com>
;; Maintainer: Sergey Pashaev <sergey.pashaev@gmail.com>
;; Created: 26th April 2020
;; Keywords: ripgrep rpojectile hydra
;; Homepage: https://github.com/sergey-pashaev/cprg
;; Package-Requires: ((ripgrep "0.3.0") (projectile "0.14.0") (hydra "0.15.0"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package allows user to setup his own filetype search filters for
;; projectile-ripgrep and select and run them form convenient ui (via hydra).

;;; Usage:
;;
;; For example one might work on project with a lot of files and one don't want
;; to grep over all of them each time if you need only grep over c++ files and
;; not over some c++ test files, for example.
;; So he adds two search types in his config like this:
;;
;;     (require 'cprg)
;;     (cprg-set-globs "_c_++"    '("*.h" "*.c" "*.cc"))
;;     (cprg-set-globs "_p_ython" '("*py"))
;;     (cprg-set-globs "_t_ests"  '("*test.cc" "*tests.cc"))
;;     (cprg-load-hydra)
;;
;; Now one can run hydra ui with "M-x cprg-hydra" and see that he can add
;; defined c++ globs to "Include" glob set with 'c' key and test files globs
;; with 't' key. Once globs in a "Include" set one can move them to "Exclude"
;; set by repeating appropriate key and remove it from exclude set with one more
;; key press.
;;
;; Once user setup globs he can press:
;; - 's' - to search.
;; - 'r' - to reset "Include"/"Exclude" sets.
;; - 'q' - to quit.

;;; Code:

(require 'projectile)
(require 'ripgrep)
(require 'hydra)
(require 'thingatpt)
(require 'subr-x) ; for hash-table-keys

(defvar cprg-globs (make-hash-table :test 'equal)
  "Hash table of globs. string key -> list of string/globs.")

(defun cprg-set-globs (key globs)
  "Set list of `GLOBS' for `KEY'."
  (when (and (stringp key)
             (listp globs))
    (puthash key globs cprg-globs)))

(defun cprg-get-globs (key)
  "Return list of globs for `KEY'."
  (gethash key cprg-globs))

(defvar cprg-included-globs nil)
(defvar cprg-excluded-globs nil)

(defmacro cprg-toggle (set globs)
  "Add or remove `GLOBS' into `SET' list."
  `(dolist (glob ,globs)
     (if (member glob ,set)
         (setq ,set (delete glob ,set))
       (setq ,set (append (list glob) ,set)))))

(defmacro cprg-check (set globs)
  "Return t if all of `GLOBS' exists in `SET' list."
  `(let ((match 0))
    (dolist (glob ,globs)
      (if (member glob ,set)
           (setq match (+ match 1))))
    (equal match (length ,globs))))

(defun cprg-toggle-smart (globs)
  "Toggle `GLOBS'.
If `GLOBS' not in any set - add them into included set.
If `GLOBS' in included set - move then into excluded set.
If `GLOBS' in exclided set - remove them from it."
  (let ((included (cprg-check cprg-included-globs globs))
        (excluded (cprg-check cprg-excluded-globs globs)))
    (cond ((and included (not excluded)) ; included -> excluded
           (progn
             (cprg-toggle cprg-included-globs globs)
             (cprg-toggle cprg-excluded-globs globs)))
          ((and excluded (not included)) ; excluded -> not in a set
           (progn
             (cprg-toggle cprg-excluded-globs globs)))
          (t                            ; not in a set -> included
           (progn
             (cprg-toggle cprg-included-globs globs))))))

(defun cprg-reset-globs ()
  "Reset cprg include, exclude lists."
  (setq cprg-included-globs '())
  (setq cprg-excluded-globs '()))

(defun cprg-get-key (str)
  "Extract key from `STR' (\"_j_ava\" -> \"j\")."
  (when (string-match "_\\(.\\)_" str)
    (match-string 1 str)))

(defun cprg-make-head (name)
  "Generate hydra head for `NAME' key in `cprg-globs' hash table."
  (let ((key (cprg-get-key name)))
    (when key
      (list
       `(,key (cprg-toggle-smart (cprg-get-globs ,name)))))))

(defun cprg-make-heads ()
  "Generate hydra heads for all keys in `cprg-globs'."
  (let ((heads))
    (dolist (key (hash-table-keys cprg-globs))
      (let ((head (cprg-make-head key)))
        (when head
          (push (car head) heads))))
    heads))

(defun cprg-make-docstring ()
  "Generate hydra docstring for all keys in `cprg-globs'."
  (format "
%s
[_s_earch _r_eset _q_uit]
Include: %%`cprg-included-globs
Exclude: %%`cprg-excluded-globs
"
          (string-join (hash-table-keys cprg-globs) " ")))

(defmacro cprg-load-hydra ()
  "Cprg hydra definition."
  `(defhydra cprg-hydra (:hint none)
     ,(cprg-make-docstring)
     ,@(cprg-make-heads)
     ("s" cprg-search :exit t)
     ("r" (cprg-reset-globs))
     ("q" nil :exit t)))

(defun cprg-hydra ()
  "Run cprg hydra."
  (interactive)
  (cprg-hydra/body))

(defun cprg-search (search-term &optional arg)
  "Run a Ripgrep search with `SEARCH-TERM' rooted at the current projectile project root.

With an optional prefix argument `ARG' `SEARCH-TERM' is interpreted as a
regular expression."
  (interactive
   (list
    (read-from-minibuffer (projectile-prepend-project-name (format "Ripgrep %ssearch for: "
                                                                   (if current-prefix-arg
                                                                       "regexp "
                                                                     "")))
                          (projectile-symbol-or-selection-at-point))
    current-prefix-arg))
  (let ((args (append
               (mapcar (lambda (val) (format "--glob !\"%s\"" val))
                       (append cprg-excluded-globs
                               (projectile-ignored-files-rel)
                               (projectile-ignored-directories-rel))
                       )
               (mapcar (lambda (val) (format "--glob \"%s\"" val))
                       cprg-included-globs))))
    (ripgrep-regexp search-term
                    (projectile-project-root)
                    (if current-prefix-arg
                        args
                      (cons "--fixed-strings" args)))))

(provide 'cprg)
;;; cprg.el ends here
