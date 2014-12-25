;;; elscreen-revive.el --- srestore elscreen tabs to each frames using revive.el

;; Copyright (C) 2014 momomo5717 <momomosute_at_gmail.com>

;; Keywords: elscreen revive
;; Version: 0.1
;; Package-Requires: ((emacs "24") (cl-lib "1.0") (elscreen "20140421.414") (revive "2.22"))
;; URL: https://github.com/momomo5717/elscreen-revive

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
;; Tested on Emacs 24.4.1 (emacs-mac-app 5.2_0)
;;
;; elscreen-revive (elsc-r)
;;
;; Usage :
;;
;;  After (elscreen-start) , add to your init file
;;  (require 'elscreen-revive)
;;  (elsc-r:add-kill-emacs-hook)
;;
;;
;;  If you want to restore elscreen tabs,
;;  M-x elsc-r:restore
;;  or
;;  M-x elsc-r:restore-to-new-frame
;;  If .revive.el file exists,
;;  M-x elsc-r:resume-and-restore
;;
;;  .revive.el file is outputted by save-current-configuration written in revive.el.
;;
;;  If you want to use elsc-r:resume-and-restore command at the next session,
;;  add to your init file.
;;  (add-hook 'kill-emacs-hook 'save-current-configuration 'append)
;;
;;
;;  If you want to remove elsc-r:store function from kill-emacs-hook,
;;  M-x elsc-r:remove-kill-emacs-hook
;;
;;  If you want to automatically restore elscreen tabs after loading init files,
;;  (add-hook 'after-init-hook 'elsc-r:restore)
;;  If .revive.el file exists,
;;  (add-hook 'after-init-hook 'elsc-r:resume-and-restore)
;;
;;  If you want to restore elscreen tabs with just top and left frame parameters,
;;  (custom-set-variables ('elsc-r:store-frame-keys '(top left))
;;
;;
;; Inspired by
;; http://stackoverflow.com/questions/22445670/save-and-restore-elscreen-tabs-and-split-frames
;; https://github.com/robario/elscreen-persist
;;

;;; Code:

(require 'cl-lib)
(require 'revive)
(require 'elscreen)

(defgroup elscreen-revive nil
  "ElScreen Restore -- ElScreen store and restore all frame"
  :tag "ElScreen Restore"
  :group 'elscreen)

(defconst elscreen-revive-version "0.1.0")

;; Coustom Variables

(defcustom elsc-r:config-file
  (locate-user-emacs-file ".elscreen-revive")
  "The file where all frame elscreen tabs configuration is stored."
  :type 'file
  :group 'elscreen-revive)

(defcustom elsc-r:store-frame-keys t
  "Store all frame parameters without buffer, if t.
Store particular frame parameters without buffer, if key list.
   ex) '(top left width height)"
  :type 'sexp
  :group 'elscreen-revive)

(defcustom elsc-r:max-frame-num 5
  "Maximum frame number to avoid making too many frames"
  :type 'integer
  :group 'elscreen-revive)

;; Helper Functions

(defun elsc-r:make-new-frame-list (n)
  (cl-loop repeat n collect (make-frame)))

(defun elsc-r:force-n-frame-list (n)
  (when (> n 0)
    (delete-other-frames)
    (cl-loop repeat (1- n) do (make-frame)))
  (frame-list))


;; Data Structure :
;;   frame-configs  = (list frame-config ...)
;;   frame-config   = (list frame-params screen-configs)
;;   screen-configs = (list screen-config ...)
;;   screen-config  = (list (screen-num window-config focus) ...)
;;   frame-params   = filtered-frame-parameters
;;   screen-num     = 0 | 1 | ... | 9
;;   window-config  = current-window-configuration-printable from revive.el or revive+.el
;;   focus          = 'focus | . nil

;; Functions to Store

(defun elsc-r:frame-parameters-without-bffer (&optional frame)
  "frame-obj -> frame-params"
  (cl-remove-if
   (lambda (key) (memq key '(buffer-list buried-buffer-list minibuffer)))
   (frame-parameters frame) :key #'car))

(defun elsc-r:filtered-frame-parameters (&optional frame)
  "frame-obj -> frame-params"
  (cond
   ((null elsc-r:store-frame-keys) '())
   ((listp elsc-r:store-frame-keys)
    (cl-remove-if-not (lambda (key) (memq key elsc-r:store-frame-keys))
      (elsc-r:frame-parameters-without-bffer frame) :key #'car))
   (t (elsc-r:frame-parameters-without-bffer frame))))

(defun elsc-r:screen-configs (&optional frame)
  "frame-obj -> (list (screen-num window-config focus) ...)"
  (let ((now-fr (selected-frame))
        (focus-s (progn (when (framep frame) (select-frame frame))
                               (elscreen-get-current-screen))))
    (prog1
      (mapcar (lambda (i) (elscreen-goto i)
                (list* i (current-window-configuration-printable)
                       (if (= i focus-s) '(focus) nil)))
              (sort (elscreen-get-screen-list) '<))
      (elscreen-goto focus-s)
      (select-frame now-fr))))

(defun elsc-r:frame-config (&optional frame)
  "frame-obj -> (list frame-params screen-configs)"
  (list (elsc-r:filtered-frame-parameters frame)
        (elsc-r:screen-configs frame)))

(defun elsc-r:frame-configs ()
  "Return (list frame-config ...)"
  (let* ((now-fr (selected-frame))
         (othre-fr (delq now-fr (frame-list))))
    (cons (elsc-r:frame-config now-fr)
          (mapcar #'elsc-r:frame-config othre-fr))))

(defun elsc-r:write-frame-configs (file)
  "Write frame-configs to file."
  (let ((fr-configs (elsc-r:frame-configs)))
    (with-temp-file file (insert (prin1-to-string fr-configs)))
    (message (format "Wrote elsc-r:frame-configs :%s" file))))

;;;###autoload
(defun elsc-r:store ()
  "Store frame-configs to elsc-r:config-file."
  (interactive)
  (elsc-r:write-frame-configs elsc-r:config-file))

;; Functions to Restore

(defun elsc-r:restore-screen-configs (screen-configs)
  "Restore from (list screen- config ...)"
  (let ((ls screen-configs) focus res-ls (c 0))
    (while (and (not (null ls)) (< c 19))
      (cl-incf c)
      (if (elscreen-screen-live-p (cl-first (car ls)))
          (let* ((s-config     (car ls))
                 (s-num        (cl-first  s-config))
                 (s-win-config (cl-second s-config))
                 (s-focus      (cl-third  s-config)))
            (elscreen-goto s-num)
            (restore-window-configuration s-win-config)
            (pop ls) (setq focus (if s-focus s-num focus)) (push s-num res-ls))
        (elscreen-create-internal)))
    (when (elscreen-screen-live-p focus) (elscreen-goto focus))
    (when (not (null res-ls))
      (cl-mapc #'elscreen-kill-internal
               (cl-set-difference (elscreen-get-screen-list) res-ls)))))

(defun elsc-r:restore-frame-config (frame-config &optional frame)
  "Restore elscreen tabs from (list frame-params screen-configs) and frame-obj."
  (unless (null frame-config)
    (let ((frame-params (cl-first  frame-config))
          (s-configs    (cl-second frame-config ))
          focus-num)
      (when (framep frame) (select-frame frame))
      (modify-frame-parameters frame frame-params)
      (elsc-r:restore-screen-configs s-configs))))

(defun elsc-r:restore-frame-configs (frame-configs &optional add)
  "Restore frames from (list frame-config ...).
  Add frame-configs to new frames, if add is not nil."
  (unless (null frame-configs)
    (let ((fr-ls (if add (elsc-r:make-new-frame-list
                          (min (length frame-configs) elsc-r:max-frame-num))
                   (elsc-r:force-n-frame-list
                    (min (length frame-configs) elsc-r:max-frame-num)))))
     (cl-mapc #'elsc-r:restore-frame-config frame-configs fr-ls)
     (select-frame-set-input-focus (cl-first fr-ls)))))

(defun elsc-r:restore-file (file &optional add)
  "Restore elscreen tabs from a config file.
   Restore elscreen tabs to new frames, if add is not nil."
  (if (not (file-exists-p file))
      (message (format "File not found : %s" file))
    (elsc-r:restore-frame-configs
     (read (with-temp-buffer (insert-file-contents file) (buffer-string)))
     add)
    (message "Done elsc-r:restore")))

;;;###autoload
(defun elsc-r:restore (&optional add)
  "Restore elscreen tabs from elsc-r:config-file."
  (interactive)
  (elsc-r:restore-file elsc-r:config-file add))

;; Wrapper Functions

;;;###autoload
(defun elsc-r:restore-to-new-frame ()
  "Restore elscreen tabs from elsc-r:config-file to new frames."
  (interactive)
  (elsc-r:restore t))
;;;###autoload
(defun elsc-r:resume-and-restore ()
  "Resume and Restore elscreen tabs."
  (interactive)
  (resume)
  (elsc-r:restore))
;;;###autoload
(defun elsc-r:add-kill-emacs-hook ()
  (interactive)
  (add-hook 'kill-emacs-hook 'elsc-r:store 'append))
;;;###autoload
(defun elsc-r:remove-kill-emacs-hook ()
  (interactive)
  (remove-hook 'kill-emacs-hook 'elsc-r:store))

(provide 'elscreen-revive)
;;; elscreen-revive.el ends here