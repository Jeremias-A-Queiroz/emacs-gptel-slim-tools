;;; gptel-llm-cache.el --- LLM-managed ephemeral session cache -*- lexical-binding: t; -*-

(require 'gptel)

(defvar gptel-llm-session-cache (make-hash-table :test 'eq)
  "Hash table to store LLM-managed session cache data.
Keys are symbols representing cache names, values are arbitrary Elisp data.
This cache is ephemeral and cleared on Emacs restart.")

(defun gptel-llm-cache-set (cache-name-string elisp-data-string)
  "Sets or updates an Elisp data object in the LLM's in-memory session cache."
  (let* ((cache-symbol (intern cache-name-string))
         (data (read-from-string elisp-data-string)))
    (puthash cache-symbol data gptel-llm-session-cache)
    `((status . "success")
      (cache_name . ,cache-name-string)
      (data . ,(prin1-to-string data)))))

(defun gptel-llm-cache-get (cache-name-string)
  "Retrieves an Elisp data object from the LLM's in-memory session cache."
  (let* ((cache-symbol (intern cache-name-string))
         (data (gethash cache-symbol gptel-llm-session-cache)))
    (if data
        `((status . "success")
          (cache_name . ,cache-name-string)
          (data . ,(prin1-to-string data)))
      `((status . "error")
        (message . ,(format "LLM cache '%s' not found." cache-name-string))))))

(defun gptel-llm-cache-list-names ()
  "Lists the string names of all Elisp data objects currently stored.
Used internally for context injection."
  (let (names)
    (maphash (lambda (key _value) (push (symbol-name key) names)) gptel-llm-session-cache)
    `((status . "success")
      (names . ,(vconcat (nreverse names))))))

(defun gptel-llm-cache-clear (&optional cache-name-string)
  "Clears a specific Elisp data object from the LLM's in-memory session cache."
  (if cache-name-string
      (if (gethash (intern cache-name-string) gptel-llm-session-cache)
          (progn
            (remhash (intern cache-name-string) gptel-llm-session-cache)
            `((status . "success")
              (message . ,(format "LLM cache '%s' cleared." cache-name-string))))
        `((status . "error")
          (message . ,(format "LLM cache '%s' not found." cache-name-string))))
    (progn
      (clrhash gptel-llm-session-cache)
      `((status . "success")
        (message . "All LLM caches cleared.")))))

;; --- Context Injection ---

(defun gptel-slim-inject-cache-names (&optional _info)
  "Inject active LLM cache names into the gptel prompt buffer.
Intended to be used in `gptel-prompt-transform-functions'.
INFO is the request plist provided by gptel."
  (let* ((cache-result (gptel-llm-cache-list-names))
         (names-vector (alist-get 'names cache-result))
         (names-list (and names-vector (append names-vector nil))))
    (when names-list
      (goto-char (point-max))
      (insert "\n\n--- Available Caches ---\n")
      (dolist (name names-list)
        (insert (format "- %s\n" name))))))

;; Register the injection function in gptel's prompt transformation hook
(add-hook 'gptel-prompt-transform-functions #'gptel-slim-inject-cache-names)

;; --- Tool Declarations ---

(gptel-make-tool
 :name "llm_cache_set"
 :function #'gptel-llm-cache-set
 :description "Sets or updates an Elisp data object in the LLM's in-memory session cache. The LLM can define the name of the cache and store arbitrary Elisp data literals (lists, strings, numbers, hash tables). Use this for autonomous caching of relevant information. IMPORTANT: DO NOT provide executable code, only data literals (e.g., '(\"item1\" \"item2\"), \"a string\", 123, (make-hash-table :test 'equal))."
 :args (list '(:name "cache_name_string" :type string :description "The string name for the Elisp symbol to be used as a cache (e.g., \"my-relevant-tags\").")
             '(:name "elisp_data_string" :type string :description "A string containing an Elisp data literal to store (e.g., '(\"tag1\" \"tag2\"), \"a summary string\", 123, (make-hash-table :test 'equal)).")))

(gptel-make-tool
 :name "llm_cache_get"
 :function #'gptel-llm-cache-get
 :description "Retrieves the Elisp data object associated with a given name from the LLM's in-memory session cache. Returns the data as an Elisp string representation."
 :args (list '(:name "cache_name_string" :type string :description "The string name of the Elisp cache symbol to retrieve.")))

(gptel-make-tool
 :name "llm_cache_clear"
 :function #'gptel-llm-cache-clear
 :description "Clears a specific Elisp data object from the LLM's in-memory session cache, or clears all caches if no name is provided."
 :args (list '(:name "cache_name_string" :type string :optional t :description "The string name of the Elisp cache symbol to clear (optional, clears all if omitted).")))

(provide 'gptel-llm-cache)
;;; gptel-llm-cache.el ends here
