;;; gptel-thin-tags.el --- Minimalist TAGS context extraction for gptel -*- lexical-binding: t; -*-

;;; Commentary:

;; Provides a deterministic, GOFAI-style tool for gptel to extract
;; complete function/variable definitions from a project using TAGS files.
;; It creates temporary, isolated buffers for context that are automatically
;; cleaned up after the LLM responds.

;;; Code:

(require 'gptel)

(defun gptel-thin-tags--locate (tag-name tags-file)
  "Locate TAG-NAME in TAGS-FILE, returning a list of (file line next-line).
Searches for the pattern (tag-name  line,offset) within the TAGS file."
  (with-current-buffer (find-file-noselect tags-file)
    (save-excursion
      (goto-char (point-min))
      ;; Search for the tag name followed by two spaces or the control character 127
      (if (re-search-forward (format "%s[\177\001 ]+\\([0-9]+\\)," (regexp-quote tag-name)) nil t)
          (let* ((line-num (string-to-number (match-string 1)))
                 (curr-pt (point))
                 ;; Find the boundary of the current file in TAGS (next Form Feed \\f or EOF)
                 (file-end (save-excursion (if (search-forward "\f" nil t) (point) (point-max))))
                 ;; Find the line of the next tag within this same file
                 (next-line (save-excursion
                              (goto-char curr-pt)
                              (if (re-search-forward "[\177 ]+\\([0-9]+\\)," file-end t)
                                  (string-to-number (match-string 1))
                                nil))))
            (re-search-backward "\f\n\\([^,\n]+\\)," nil t)
            (list (expand-file-name (match-string 1) (file-name-directory tags-file))
                  line-num
                  next-line))
        (error "Tag '%s' not found in %s" tag-name tags-file)))))

(defun gptel-thin-tags--fetch-full (tag-name tags-file &optional make-visible-p)
  "Precisely locate TAG-NAME and extract its complete definition.
Creates a temporary buffer prefixed with '*gptel-context:*'.
If MAKE-VISIBLE-P is non-nil, pop to the created buffer."
  (interactive
   (list (read-string "Tag: " (thing-at-point 'symbol))
         (read-file-name "TAGS file: ")))
  (let* ((loc (gptel-thin-tags--locate tag-name tags-file))
         (file (nth 0 loc))
         (line (nth 1 loc))
         (next-line (nth 2 loc))
         (buf-name (format "*gptel-context:%s*" tag-name))
         content)
    
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (forward-line (1- line))
          (let ((beg (point)))
            ;; Advance mathematically to the next neighbor or capture 100 lines as a fallback
            (if next-line
                (forward-line (- next-line line))
              (forward-line 100))
            (setq content (buffer-substring-no-properties beg (point)))))))

    (let ((res-buf (get-buffer-create buf-name)))
      (with-current-buffer res-buf
        (erase-buffer)
        (insert content)
        (set-buffer-modified-p nil))
      (if make-visible-p
          (pop-to-buffer res-buf)
        res-buf))))

(defun gptel-thin-tags-cleanup (&rest _args)
  "Silently remove '*gptel-context:*' buffers without polluting the message area.
The '&rest _args' signature ensures compatibility with 'gptel-post-response-functions'."
  (interactive)
  (let ((count 0))
    (dolist (buf (buffer-list))
      (let ((name (buffer-name buf)))
        (when (string-prefix-p "*gptel-context:" name)
          (kill-buffer buf)
          (setq count (1+ count)))))
    ;; Only display a message if executed interactively and cleanup occurred
    (when (and (called-interactively-p 'any) (> count 0))
      (message "Thin Tags Cleaner: %d buffer(s) removed." count))))

;; Add cleanup to the gptel hook safely
(add-hook 'gptel-post-response-functions #'gptel-thin-tags-cleanup)

(defun gptel-thin-tags--investigate-adapter (tag-name tags-file)
  "Adapter for the LLM tool to extract the source code of TAG-NAME.
Returns the exact string content of the temporary context buffer."
  (let ((buffer (gptel-thin-tags--fetch-full tag-name tags-file nil)))
    (with-current-buffer buffer
      (buffer-substring-no-properties (point-min) (point-max)))))

;;--- Tool Definition
(gptel-make-tool
 :name "investigate_code_tag"
 :function #'gptel-thin-tags--investigate-adapter
 :description "Extract and analyze a specific code fragment (function/variable) from the source code using a TAGS file. Use this to investigate the implementation of a suspected root-cause without reading the whole file."
 :args (list '(:name "tag_name" :type string :description "The name of the function or definition to investigate")
             '(:name "tags_file" :type string :description "Path to the TAGS file"))
 :category "investigation")

(provide 'gptel-thin-tags)
;;; gptel-thin-tags.el ends here
