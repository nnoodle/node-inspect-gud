;;; node-inspect.el --- Debug node programs with node inspect and GUD -*- lexical-binding:t -*-

;; Copyright © 2018 Noodles!

;; Author: Noodles!
;; URL: https://github.com/nnoodle/node-inspect-gud
;; Version: 0.1
;; Keywords: tools, debugger, node, javascript

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; This package provides bare-bones GUD support for `node inspect'

;;; Code:

(require 'gud)
(require 'ansi-color)

;; custom variables
(defcustom node-inspect-command-name "node inspect"
  "Command for executing the node inspector."
  :type 'string
  :group 'gud)

(defcustom node-inspect-mode-hook nil
  "Mode hook for ‘node-inspect’ debugger."
  :type 'hook
  :group 'gud)

;; Sample marker line:
;; Break on start in sample/test.js:10
;; break in test.js:8
(defvar node-inspect-marker-regexp
  "^\\([Bb]reak\\) .+ \\(.+\\):\\([0-9]+\\)$")
(defvar node-inspect-marker-regexp-file-group 2)
(defvar node-inspect-marker-regexp-line-group 3)
(defvar node-inspect-marker-regexp-start "^\\([Bb]reak\\) ")

(defvar node-inspect-history nil)

(defun node-inspect-marker-filter (string)
  (setq gud-marker-acc
        ;; filter out carriage returns and ansi-colors
        (replace-regexp-in-string (kbd "C-m") "" (ansi-color-apply (concat gud-marker-acc string))))

  (let ((output ""))
    ;; ignore "debug> " dups
    (unless (string-empty-p (setq gud-marker-acc (replace-regexp-in-string "debug> " "" gud-marker-acc)))
      ;; Process all the complete markers in this chunk.
      (while (string-match node-inspect-marker-regexp gud-marker-acc)
        (setq gud-last-frame
              ;; Extract the frame position from the marker.
              (cons (match-string node-inspect-marker-regexp-file-group gud-marker-acc) ;; file pos
                    (string-to-number (match-string node-inspect-marker-regexp-line-group gud-marker-acc)))) ;; line pos
        (setq output
              ;; Output everything instead of the below
              (concat output (substring gud-marker-acc 0 (match-end 0))))
        ;;	  ;; Append any text before the marker to the output we're going
        ;;	  ;; to return - we don't include the marker in this text.
        ;;	  output (concat output
        ;;		      (substring gud-marker-acc 0 (match-beginning 0)))
        ;; Set the accumulator to the remaining text.
        (setq gud-marker-acc (substring gud-marker-acc (match-end 0))))
      ;; Does the remaining text look like it might end with the
      ;; beginning of another marker?  If it does, then keep it in
      ;; gud-marker-acc until we receive the rest of it.  Since we
      ;; know the full marker regexp above failed, it's pretty simple to
      ;; test for marker starts.
      (if (string-match node-inspect-marker-regexp-start gud-marker-acc)
          (progn
            ;; Everything before the potential marker start can be output.
            (setq output (concat output (substring gud-marker-acc
                                                   0 (match-beginning 0))))
            ;; Everything after, we save, to combine with later input.
            (setq gud-marker-acc (substring gud-marker-acc (match-beginning 0))))
        ;; TODO: fix accidental "debug> " output on certain messages.
        (setq output (concat output gud-marker-acc "\ndebug> ")
              gud-marker-acc ""))
      output)))

(defun node-inspect--query-cmdline ()
  "A node-variant of `gud-query-cmdline'"
  (read-from-minibuffer
   "Run node-inspect (like this): "
   (or (car-safe node-inspect-history)
       (concat node-inspect-command-name " " (file-name-nondirectory buffer-file-name))
   gud-minibuffer-local-map nil 'node-inspect-history)))

;;;###autoload
(defun node-inspect (command-line)
  "Run COMMAND-LINE on program FILE in buffer `*gud-FILE*'.
The directory containing FILE becomes the initial working directory
and source-file directory for your debugger."
  (interactive
   (list (node-inspect--query-cmdline)))

  ;; node inspect doesn't respect this for some reason.
  (setenv "NODE_NO_READLINE" "1")

  (gud-common-init command-line nil #'node-inspect-marker-filter)

  (setq-local comint-input-ignoredups t)
  (setq-local gud-minor-mode 'node-inspect)

  (gud-def gud-break   "setBreakpoint('%d%f', %l)"   "\C-b" "Set breakpoint at current line.")
  (gud-def gud-remove  "clearBreakpoint('%d%f', %l)" "\C-d" "Remove breakpoint at current line.")
  (gud-def gud-cont    "cont"                        "\C-r" "Continue with display.")
  (gud-def gud-next    "next"                        "\C-n" "Step into function.")
  (gud-def gud-step    "step"                        "\C-s" "Step one source line with display.")
  (gud-def gud-stepout "out"                         nil    "Step out of function.")
  (gud-def gud-run     "run"                         nil    "Run or restart the program.")
  (gud-def gud-print   "exec('%e')"                  "\C-p" "Evaluate JavaScript expression at point.")
  (gud-def gud-watch   "watch('%e')"                 "\C-w" "Watch expression at point.")
  (gud-def gud-unwatch "unwatch('%e')"               "\C-u" "Unwatch expression at point.")

  (setq comint-prompt-regexp "\ndebug> ")
  (setq paragraph-start comint-prompt-regexp)
  (run-hooks 'node-inspect-mode-hook))

(provide 'node-inspect)
;;; node-inspect.el ends here
