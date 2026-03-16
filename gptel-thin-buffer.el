;;; gptel-thin-buffer.el --- Thin Context Buffer Tools for gptel -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides JIT (Just-In-Time) buffer inspection tools for gptel.
;; Extracts tags and source code using Tree-sitter, Semantic, or Imenu.

;;; Code:

(require 'cl-lib)
(require 'gptel)

;; --- 1. Routing Engine ---

(defun gptel-thin-buffer--detect-engine ()
  "Detect the most appropriate parsing engine for the current buffer.
Returns one of 'treesit, 'semantic, or 'imenu."
  (cond
   ((and (fboundp 'treesit-parser-list) (treesit-parser-list))
    'treesit)
   ((and (bound-and-true-p semantic-mode) (fboundp 'semantic-fetch-tags))
    'semantic)
   (t 'imenu)))

;; --- 2. List Workers ---

(defun gptel-thin-buffer--list-treesit ()
  "List tags using Tree-sitter."
  (let ((root (treesit-buffer-root-node (treesit-language-at (point-min))))
        (node-filter "\\(class\\|function\\|method\\)_definition$\\|tag$\\|assignment$")
        (flat-tags nil))
    (cl-labels ((flatten-tree (tree)
                  (let ((node (car tree))
                        (children (cdr tree)))
                    (when (and node (not (equal node root)))
                      (let ((type (treesit-node-type node)))
                        (when (or (not (string-match-p "assignment" type))
                                  (not (treesit-parent-until 
                                        node 
                                        (lambda (p) (string-match-p "class\\|function\\|method" (treesit-node-type p))))))
                              (let ((name-node (or (treesit-node-child-by-field-name node "name")
                                                   (treesit-node-child-by-field-name node "key")
                                                   (treesit-node-child node 0))))
                                (push (list (treesit-node-text name-node t)
                                            :class (cond
                                                    ((string-match-p "function\\|method" type) "function")
                                                    ((string-match-p "class" type) "class")
                                                    ((string-match-p "assignment" type) "variable")
                                                    (t type)))
                                      flat-tags)))))
                    (dolist (child children)
                      (flatten-tree child)))))
      (flatten-tree (treesit-induce-sparse-tree root node-filter))
      (reverse flat-tags))))

(defun gptel-thin-buffer--list-semantic ()
  "Extract structural tags from the current buffer using Semantic."
  (mapcar (lambda (tag)
            (list (semantic-tag-name tag)
                  :class (semantic-tag-class tag)))
          (semantic-fetch-tags)))

(defun gptel-thin-buffer--list-imenu ()
  "Extract structural tags from the current buffer using Imenu."
  (imenu--make-index-alist))

;; --- 3. Extract Workers ---
(defun gptel-thin-buffer--extract-treesit (tag-name)
  "Extract tag boundaries using Tree-sitter."
  (let* ((lang (treesit-language-at (point-min)))
         (node (treesit-search-subtree
                (treesit-buffer-root-node lang)
                (lambda (n)
                  (let ((nn (or (treesit-node-child-by-field-name n "name")
                                (treesit-node-child-by-field-name n "declarator")
                                (treesit-node-child-by-field-name n "key")
                                (treesit-node-child n 0))))
                    (and nn 
                         (string= (treesit-node-text nn t) tag-name)
                         (let ((type (treesit-node-type n)))
                           (and (string-match-p "definition$\\|tag$\\|assignment$" type)
                                (or (not (string-match-p "assignment" type))
                                    (not (treesit-parent-until 
                                          n 
                                          (lambda (p) (string-match-p "class\\|function\\|method" (treesit-node-type p))))))))))))))                                    
    (when node
      (cons (treesit-node-start node) (treesit-node-end node)))))

(defun gptel-thin-buffer--extract-semantic (tag-name)
  "Extract the bounds of TAG-NAME using Semantic.
Returns a cons cell (START . END) or nil."
  (let ((tag (semantic-find-first-tag-by-name tag-name (semantic-fetch-tags))))
    (when tag
      (cons (semantic-tag-start tag) (semantic-tag-end tag)))))

(defun gptel-thin-buffer--extract-imenu (tag-name)
  "Extract the bounds of TAG-NAME using Imenu.
Returns a cons cell (START . END) or nil."
  (let* ((index (imenu--make-index-alist))
         (flat-index nil))
    (cl-labels ((flatten (alist)
                  (dolist (item alist)
                    (cond
                     ((and (consp item) (stringp (car item)) (markerp (cdr item)))
                      (push (cons (car item) (marker-position (cdr item))) flat-index))
                     ((and (consp item) (stringp (car item)) (integerp (cdr item)))
                      (push item flat-index))
                     ((and (consp item) (listp (cdr item)))
                      (flatten (cdr item)))))))
      (flatten index))
    (setq flat-index (sort flat-index (lambda (a b) (< (cdr a) (cdr b)))))
    (let ((item (assoc tag-name flat-index)))
      (when item
        (let* ((beg (cdr item))
               (rest (cdr (member item flat-index)))
               (end (if rest (cdar rest) (point-max))))
          (cons beg end))))))

;; --- 4. Facades / Adapters ---

(defun gptel-thin-buffer--list-adapter (buffer-name)
  "Adapter for gptel: List tags in BUFFER-NAME.
Detects the appropriate parsing engine, extracts the tags, and returns
a formatted string including engine metadata."
  (with-current-buffer (or (get-buffer buffer-name)
                           (error "Buffer '%s' not found" buffer-name))
    (let* ((engine (gptel-thin-buffer--detect-engine))
           (tags (pcase engine
                   ('treesit (gptel-thin-buffer--list-treesit))
                   ('semantic (gptel-thin-buffer--list-semantic))
                   ('imenu (gptel-thin-buffer--list-imenu)))))
      (format "[Engine: %s]\n\n%s" engine (pp-to-string tags)))))

(defun gptel-thin-buffer--extract-adapter (buffer-name tag-name)
  "Adapter for gptel: Extract TAG-NAME source code from BUFFER-NAME.
Detects the appropriate parsing engine, extracts the bounding coordinates,
and returns the exact source code string with engine metadata."
  (with-current-buffer (or (get-buffer buffer-name)
                           (error "Buffer '%s' not found" buffer-name))
    (let* ((engine (gptel-thin-buffer--detect-engine))
           (bounds (pcase engine
                     ('treesit (gptel-thin-buffer--extract-treesit tag-name))
                     ('semantic (gptel-thin-buffer--extract-semantic tag-name))
                     ('imenu (gptel-thin-buffer--extract-imenu tag-name)))))
      (if (and bounds (car bounds) (cdr bounds))
          (format "[Engine: %s]\n\n%s"
                  engine
                  (buffer-substring-no-properties (car bounds) (cdr bounds)))
        (error "Tag '%s' not found in buffer '%s' using engine '%s'"
               tag-name buffer-name engine)))))

;; --- 5. Tool Declarations ---

(gptel-make-tool
 :name "list_buffer_tags"
 :function #'gptel-thin-buffer--list-adapter
 :description "Lists tags (functions, classes, keys) from an active buffer using structural parsing. Works for C/C++, Elisp, YAML, Python, Ansible, etc."
 :args (list '(:name "buffer_name" :type string :description "Name of the open buffer to analyze"))
 :category "investigation")

(gptel-make-tool
 :name "read_tag_source"
 :function #'gptel-thin-buffer--extract-adapter
 :description "Extracts the exact source code of a specified tag/function/key from a buffer using structural bounds."
 :args (list '(:name "buffer_name" :type string :description "Name of the buffer")
             '(:name "tag_name" :type string :description "Name of the tag/key to extract"))
 :category "investigation")

(provide 'gptel-thin-buffer)
;;; gptel-thin-buffer.el ends here
