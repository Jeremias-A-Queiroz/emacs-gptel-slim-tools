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
    ;; CORREÇÃO: Como 'data' pode ser uma lista Elisp arbitrária, passá-la
    ;; diretamente vai quebrar o `json-serialize`. Retornamos como string.
    `((status . "success")
      (cache_name . ,cache-name-string)
      (data . ,(prin1-to-string data)))))

(defun gptel-llm-cache-get (cache-name-string)
  "Retrieves an Elisp data object from the LLM's in-memory session cache."
  (let* ((cache-symbol (intern cache-name-string))
         (data (gethash cache-symbol gptel-llm-session-cache)))
    (if data
        ;; CORREÇÃO: Retorna a representação em string para evitar crash no JSON.
        `((status . "success")
          (cache_name . ,cache-name-string)
          (data . ,(prin1-to-string data)))
      `((status . "error")
        (message . ,(format "LLM cache '%s' not found." cache-name-string))))))

(defun gptel-llm-cache-list-names ()
  "Lists the string names of all Elisp data objects currently stored."
  (let (names)
    (maphash (lambda (key _value) (push (symbol-name key) names)) gptel-llm-session-cache)
    ;; CORREÇÃO: O Emacs json-serialize EXIGE vetores para arrays JSON.
    ;; Uma lista causaria um erro `plistp` ou corrupção de dados.
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
 :name "llm_cache_list_names"
 :function #'gptel-llm-cache-list-names
 :description "Lists the string names of all Elisp data objects currently stored in the LLM's in-memory session cache."
 :args nil)

(gptel-make-tool
 :name "llm_cache_clear"
 :function #'gptel-llm-cache-clear
 :description "Clears a specific Elisp data object from the LLM's in-memory session cache, or clears all caches if no name is provided."
 ;; CORREÇÃO: Removido `(or string null)`. Usamos `:type string` com `:optional t`.
 :args (list '(:name "cache_name_string" :type string :optional t :description "The string name of the Elisp cache symbol to clear (optional, clears all if omitted).")))

(provide 'gptel-llm-cache)
;;; gptel-llm-cache.el ends here
