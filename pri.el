;;; pri.el --- Automatic package installation -*- coding: utf-8;
;;; lexical-binding: t -*-

;; Copyright (C) 2018 by Stanislav Arnaudov

;; Version: 1.0.0
;; Author: Stanislav Arnaudov URL:
;; https://github.com/palikar/python-requirements-installer Created:
;; Oct 27 2018 Keywords: python pip requirements
;;Package-Requires: ((ov))

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;;; Commentary:

;; Simple way to install the packages in your requirements.txt.  More
;; information is in README.md or
;; https://github.com/palikar/python-requirements-installer

;;; Code:

(require 'ov)
(require 'subr-x)

(defgroup pri nil
  "Group for pvi.el"
  :prefix "pri-"
  :group 'convenience)


(defcustom pip-command "pip"
  "A command that will be executed on the shell to call pip.
It could also be something that has 'pip-like' iterface."
  :group 'pri
  :type 'string)

(defcustom pri-prefix-key "C-c -"
  "A prefix for the command in the keymap.
It should be in the form of kbd."
  :group 'pri
  :type 'string)

(defvar pip-packages (downcase (shell-command-to-string (format "%s freeze" pip-command)))
  "List of all isntalled packages.")

(defvar install-buffer-banner
  "############################################################
##############      PIP INSTALLTION        #################
############################################################
############################################################"
  "Just something to cathc atention in the buffer.")



(defun pri--check-buffer--and--file ()
  "Check if the mode and the file name are 'right'."
  (and
   (string= (file-name-nondirectory (buffer-file-name)) "requirements.txt")
   (bound-and-true-p pri-mode)))

(defun pri--package-exists (package)
  "Check if the given package is available.
The package can be available either globally in the system or in
the current virtuealenv.
PACKAGE - the name of the package to check"
  (when (string-match "\\(\\w+\\)\\(==\\|>=\\|>\\|<=\\|<\\)\\(.*\\)" package)
    (let ((name (match-string 1 package))
          (ver-req (match-string 2 package))
          (ver (match-string 3 package))
          )
      (if (string-match (format "\\(%s\\)==\\(.*\\)" name) pip-packages)
          (let* ((cur-ver (match-string 2 pip-packages)))
            (cond
             ((string= ver-req "==") (string= ver cur-ver))
             ((string= ver-req ">=") (or (string> cur-ver ver) (string= ver cur-ver)))
             ((string= ver-req ">") (string> cur-ver ver))
             ((string= ver-req "<=") (or (string< cur-ver ver) (string= ver cur-ver)))
             ((string= ver-req "<") (string< cur-ver ver))))
        nil))))


(defun pri-check-packages ()
  "Cheks the packages in the buffer."
  (interactive)
  (when (pri--check-buffer--and--file)
    (save-excursion
      (goto-char (point-min))
      (while (/= (point) (point-max))
        (beginning-of-line)
        (let* ((line (buffer-substring (point) (line-end-position))))
          (unless (or (string-match "^\s*#.*" line)
                      (= (length (string-trim line)) 0))
            (if (not (pri--package-exists line))
                (ov-set (ov-line) 'face 'warning)
              (ov-set (ov-line) 'face 'success))))
        (forward-line)
        (end-of-line)))))

(defun pri-clear-checks()
  "Cheks the packages in the buffer."
  (interactive)
  (ov-clear))


(defun pri-install-packages ()
  "Install packages in the buffer."
  (interactive)
  (when (pri--check-buffer--and--file)
    (let* ((buf-content (buffer-substring (point-min) (point-max)))
           (lines (split-string buf-content "\n"))
           (pip-buffer (get-buffer-create "*pip-install*"))
           (cur-buf (current-buffer))
           )
      (with-current-buffer pip-buffer
        (erase-buffer)
        (insert install-buffer-banner))
      (dolist (line lines)
        (if (and (not (= (length line) 0))
                 (not (pri--package-exists line))
                 (yes-or-no-p (format "%s is not installed. Install it?" line)))
            (progn
              (display-buffer pip-buffer t)
              (with-current-buffer pip-buffer
                (insert (format "\n\nInstalling %s:\n" line))
                (display-buffer pip-buffer t)
                (fit-window-to-buffer (get-buffer-window pip-buffer))
                (start-process "pip-installing" pip-buffer pip-command "install" "--user" "--progress-bar" "off"  "--no-color" line)))))
      (message ""))))

(defconst pri-mode-map
  (let
      (
       (map (make-keymap))
       )
    (define-key map (kbd (format "%s i" pri-prefix-key)) 'pri-install-packages)
    (define-key map (kbd (format "%s c" pri-prefix-key)) 'pri-clear-checks)
    (define-key map (kbd (format "%s v" pri-prefix-key)) 'pri-check-packages)
    map)
  "Keymap for pir minor mode.")

(define-minor-mode pri-mode
  "Minor mode for python requirements installer.
If the mode is active and the 'requirements.txt' file
is buing updated, the packages in it will be checked.
The mode will be automatically activated if the opend file
has name 'requirements.txt'"
  :lighter ""
  :keymap pri-mode-map
  :group 'pri
  
  (add-hook 'after-save-hook
            '(lambda ()
               (when (pri--check-buffer--and--file)
                 (pri-check-packages)
                 ))))
(add-to-list 'auto-mode-alist '("\\requirements.txt\\'" . pri-mode))


(provide 'ov)
;;; pri.el ends here
