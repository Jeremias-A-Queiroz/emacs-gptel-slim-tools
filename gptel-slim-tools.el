(defun gptel-slim-locate (tag-name tags-file)
  "Localiza TAG-NAME no TAGS-FILE buscando o padrão (tag-name  linha,offset)."
  (with-current-buffer (find-file-noselect tags-file)
    (save-excursion
      (goto-char (point-min))
      ;; Buscamos o nome da tag seguido de dois espaços ou o caractere de controle 127
      (if (re-search-forward (format "%s[\177\001 ]+\\([0-9]+\\)," (regexp-quote tag-name)) nil t)
          (let* ((line-num (string-to-number (match-string 1)))
		(curr-pt (point))
		;; Encontra o limite do arquivo atual no TAGS (próximo Form Feed \f ou EOF)
                (file-end (save-excursion (if (search-forward "\f" nil t) (point) (point-max))))
                ;; Busca a linha da próxima tag dentro deste mesmo arquivo
                (next-line (save-excursion
                             (goto-char curr-pt)
                             (if (re-search-forward "[\177 ]+\\([0-9]+\\)," file-end t)
                                 (string-to-number (match-string 1))
                               nil))))
            (re-search-backward "\f\n\\([^,\n]+\\)," nil t)
            (list (expand-file-name (match-string 1) (file-name-directory tags-file))
                  line-num
		  next-line))
        (error "Tag '%s' não encontrada em %s" tag-name tags-file)))))

(defun gptel-slim-fetch-tag-full (tag-name tags-file &optional make-visible-p)
  "Localiza a TAG-NAME de forma precisa e extrai a definição completa."
  (interactive
   (list (read-string "Tag: " (thing-at-point 'symbol))
         (read-file-name "Arquivo TAGS: ")))
  (let* ((loc (gptel-slim-locate tag-name tags-file))
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
            ;; Avança matematicamente para o Próximo Vizinho ou captura 100 linhas por segurança
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


(defun gptel-slim-context-cleanup (&rest _args)
  "Limpeza Silenciosa: Remove buffers '*gptel-context:*' sem poluir o *Messages*.
O uso de &rest _args garante compatibilidade com os argumentos do gptel-post-response-functions."
  (interactive)
  (let ((count 0))
    (dolist (buf (buffer-list))
      (let ((name (buffer-name buf)))
        (when (string-prefix-p "*gptel-context:" name)
          (kill-buffer buf)
          (setq count (1+ count)))))
    ;; Só exibe mensagem se houver uma limpeza real efetuada manualmente
    (when (and (called-interactively-p 'any) (> count 0))
      (message "Limpador Slim: %d buffer(s) removido(s)." count))))

;; Re-adicionando ao hook de forma limpa
(add-hook 'gptel-post-response-functions #'gptel-slim-context-cleanup)

;;--- Tool de investigação
(gptel-make-tool
 :name "investigate_code_tag"
 :function (lambda (tag_name tags_file)
             (condition-case err
		 ;;Args: tag_name, tags_file, add-to-context=t make-visible=nil
                 (let ((buffer (gptel-slim-fetch-tag-full tag_name tags_file nil)))
                   (with-current-buffer buffer
                     (buffer-substring-no-properties (point-min) (point-max))))
               (error (format "Erro ao investigar tag '%s': %s" tag_name (error-message-string err)))))
 :description "Extract and analyze a specific code fragment (function/variable) from the source code using a TAGS file. 
Use this to investigate the implementation of a suspected cause-root without reading the whole file."
 :args (list '(:name "tag_name" :type string :description "The name of the function or definition to investigate")
             '(:name "tags_file" :type string :description "Path to the TAGS file"))
 :category "investigation")

;;--- Tool de investigação JIT de buffer
(gptel-make-tool
 :name "list_buffer_tags"
 :function (lambda (buffer_name)
             (condition-case err
                 (with-current-buffer (or (get-buffer buffer_name)
                                          (error "Buffer '%s' não encontrado" buffer_name))
                   (let (tags)
                     (setq tags
                           (cond
                            ;; 1. Tree-sitter: Precisão moderna
                            ((and (fboundp 'treesit-parser-list) (treesit-parser-list))
			     (let ((root (treesit-buffer-root-node (treesit-language-at (point-min))))
                                     ;; Filtro expandido para incluir atribuições
                                     (node-filter "\\(class\\|function\\|method\\)_definition$\\|tag$\\|assignment$")
                                   (flat-tags nil))
                               (cl-labels ((flatten-tree (tree)
                                             (let ((node (car tree))
                                                   (children (cdr tree)))
                                                 (when (and node (not (equal node root))
                                                            (or (not (string-match-p "assignment" (treesit-node-type node)))
                                                                (equal (treesit-node-parent node) root)))
                                                 (let ((name-node (or (treesit-node-child-by-field-name node "name")
                                                                      (treesit-node-child-by-field-name node "key")
                                                                      (treesit-node-child node 0))))
                                                   (push (list (treesit-node-text name-node t)
                                                               :class (treesit-node-type node))
                                                         flat-tags)))
                                               (dolist (child children)
                                                 (flatten-tree child)))))
                                 (flatten-tree (treesit-induce-sparse-tree root node-filter))
                                 (reverse flat-tags))))
                            ;; 2. Semantic: Fallback clássico
                            ((and (bound-and-true-p semantic-mode) (fboundp 'semantic-fetch-tags))
                             (mapcar (lambda (tag)
                                       (list (semantic-tag-name tag)
                                             :class (semantic-tag-class tag)))
                                     (semantic-fetch-tags)))
                            ;; 3. Imenu: Fallback universal
                            (t (imenu--make-index-alist))))
                     (pp-to-string tags)))
               (error (format "Erro ao listar tags no buffer '%s': %s" 
                              buffer_name (error-message-string err)))))
 :description "Lists tags (functions, classes, keys) using Semantic or Imenu. Works for C/C++, Elisp, YAML, Python, Ansible, etc."
 :args (list '(:name "buffer_name" :type string :description "Name of the open buffer to analyze"))
 :category "investigation")

;;--- Tool de investigação JIT  de elementos de buffer
(gptel-make-tool
 :name "read_tag_source"
 :function (lambda (buffer_name tag_name)
             (condition-case err
                 (with-current-buffer (or (get-buffer buffer_name)
                                          (error "Buffer '%s' não encontrado" buffer_name))
                   (let (beg end)
                     (cond
		      ;; --- CENÁRIO 0: TREE-SITTER (Primário) ---
                      ((and (fboundp 'treesit-parser-list) (treesit-parser-list))
                       (let* ((lang (treesit-language-at (point-min)))
                              (node (treesit-search-subtree
                                     (treesit-buffer-root-node lang)
                                     (lambda (n)
                                       (let ((nn (or (treesit-node-child-by-field-name n "name")
                                                     (treesit-node-child-by-field-name n "declarator")
                                                     (treesit-node-child-by-field-name n "key")
                                                     (treesit-node-child n 0))))
                                         (and nn 
                                              (string= (treesit-node-text nn t) tag_name)
                                              (let ((type (treesit-node-type n)))
                                                (and (string-match-p "definition$\\|tag$\\|assignment$" type)
                                                     (or (not (string-match-p "assignment" type))
                                                         (equal (treesit-node-parent n) (treesit-buffer-root-node lang)))))))))))
                       (when node (setq beg (treesit-node-start node) end (treesit-node-end node)))))
                      ;; --- CENÁRIO 1: SEMANTIC ---
                      ((and (bound-and-true-p semantic-mode)
                            (fboundp 'semantic-fetch-tags)
                            (fboundp 'semantic-find-first-tag-by-name))
                       (let ((tag (semantic-find-first-tag-by-name tag_name (semantic-fetch-tags))))
                         (when tag
                           (setq beg (semantic-tag-start tag)
                                 end (semantic-tag-end tag)))))

                      ;; --- CENÁRIO 2: IMENU ---
                      (t
                       (let* ((index (imenu--make-index-alist))
                              (flat-index nil))
                         ;; Achata a árvore do imenu resolvendo markers e submenus
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
                         ;; Ordena as tags por posição no arquivo
                         (setq flat-index (sort flat-index (lambda (a b) (< (cdr a) (cdr b)))))
                         ;; Encontra os limites da tag
                         (let ((item (assoc tag_name flat-index)))
                           (when item
                             (setq beg (cdr item))
                             (let ((rest (cdr (member item flat-index))))
                               (setq end (if rest (cdar rest) (point-max)))))))))

                     ;; --- RETORNO PARA O LLM ---
                     (if (and beg end)
                         (buffer-substring-no-properties beg end)
                       (format "Tag '%s' não encontrada no buffer '%s'." tag_name buffer_name))))
               (error (format "Erro ao ler tag '%s' do buffer '%s': %s" 
                              tag_name buffer_name (error-message-string err)))))
 :description "Extracts the exact source code of a specified tag/function/key from a buffer."
 :args (list '(:name "buffer_name" :type string :description "Name of the buffer")
             '(:name "tag_name" :type string :description "Name of the tag/key to extract"))
 :category "investigation")

