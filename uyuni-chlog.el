;;; uyuni-chlog.el --- Uyuni Changlog Helper -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2023 Alexander Graul
;;
;; Author: Alexander Graul <agraul@suse.com>
;; Maintainer: Alexander Graul <agraul@suse.com>
;; Created: July 04, 2023
;; Modified: July 04, 2023
;; Version: 0.9
;; Keywords: convenience tools
;; Homepage: https://github.com/agraul/uyuni-chlog
;; Package-Requires: ((emacs "27.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Description
;;  uyuni-chlog is a helper that makes filling Uyuni changelog entries easy.
;;  Uyuni is developed in a monorepo and distributed as many RPM packages. As a
;;  result, there are many different .changes tracked in the repository.
;;  Nowadays, these changes files are not updated directly. In each Pull
;;  Request, one new .changes file is added for each original .changes file.
;;  Later on, all these .changes files are merged into the main ones.
;;
;;  uyuni-chlog automatically finds the correct changelog to update and shows a
;;  prompt for the changelog entry.
;;
;;; Code:
(require 'magit-git)
(require 'magit-apply)
(require 'projectile)

(defgroup uyuni-chlog nil
  "Customize uyuni-chlog."
  :group 'tools)

(defcustom uyuni-chlog-user ""
  "The username (no spaces) that's used for the changelog file name."
  :type 'string
  :group 'uyuni-chlog)

(defun uyuni-chlog-add (feature message)
  "Re-implementation of Uyuni's rel-eng/bin/mkchlog.

Prompt for FEATURE (part of the changelog name) and MESSAGE,
which is the changelog message that's written to a new changlog file."
  (interactive "sFeature: \nsMessage: ")
  (uyuni-chlog default-directory feature message))

(defun uyuni-chlog-rm ()
  (interactive)
  (let ((changes (completing-read "Delete: " (uyuni-chlog-list))))
    (magit-unstage-file changes)
    (delete-file (expand-file-name changes (projectile-project-root)))))

(defun uyuni-chlog-list ()
  "List staged changelog parts."
  (let ((regex (format "\\.changes\\.%s\\.\\w+$" uyuni-chlog-user)))
    (seq-filter (lambda (f) (string-match-p regex f)) (magit-staged-files))))

(defun uyuni-chlog (dir feature message)
  "Re-implementation of Uyuni's rel-eng/bin/mkchlog.

DIR is normally the 'default-directory',
FEATURE is a slug to make .changes files unique,
MESSAGE is the changelog entry itself."
  (let ((new-changelog-file (uyuni-chlog--new-changes-name
                             (uyuni-chlog--find-changelog-file dir)
                             feature uyuni-chlog-user)))
    (with-temp-file new-changelog-file
      (insert (format "- %s\n" message))
      (when (file-readable-p new-changelog-file)
        (insert-file-contents new-changelog-file)))
    (magit-stage-file new-changelog-file)))

(defun uyuni-chlog--new-changes-name (changes feature user)
  "Append .USER.FEATURE to the CHANGES file."
  (format "%s.%s.%s" changes user feature))

(defun uyuni-chlog--find-changelog-file (&optional dir)
  "Find the correct changelog file for DIR.

DIR defaults to current directory."
  (let ((dir (or dir default-directory)))
    (car (directory-files
          (expand-file-name (uyuni-chlog--find-package-dir dir) (projectile-project-root dir))
          t
          "\\.changes$"))))

(defun uyuni-chlog--read-package-mapping (mapping-file-name)
  "Read the RPM package root from the file passed as MAPPING-FILE-NAME."
  (with-temp-buffer
    (insert-file-contents mapping-file-name)
    (let ((contents (buffer-string)))
      (cdr (split-string contents)))))

(defun uyuni-chlog--list-tracked-dirs (project-root-dir)
  "Find all RPM package root directories in PROJECT-ROOT-DIR."
  (flatten-tree (mapcar #'uyuni-chlog--read-package-mapping
                        (directory-files
                         (expand-file-name "rel-eng/packages" project-root-dir)
                         t
                         "^[^.]"))))

(defun uyuni-chlog--tracked-dir-for-current-p (dir tracked-candidate)
  "Evaluate TRACKED-CANDIDATE as a package directory for DIR."
  (string-prefix-p tracked-candidate (file-name-as-directory (magit-file-relative-name dir))))

(defun uyuni-chlog--find-package-dir (dir)
  "Find the directory that is the root for the RPM package for DIR.

The resulting directory contains meta files, e.g. foo.spec and foo.changes."
  (car (seq-filter (apply-partially #'uyuni-chlog--tracked-dir-for-current-p dir)
                   (uyuni-chlog--list-tracked-dirs (projectile-project-root dir)))))


(provide 'uyuni-chlog)
;;; uyuni-chlog.el ends here
