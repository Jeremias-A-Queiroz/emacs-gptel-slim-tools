(defun gptel-tag-core-extractor (tags-file tag-name &optional mode add-to-context-p make-visible-p)
  "Core Cirúrgico Otimizado (v1.1): Localiza TAG-NAME usando apenas o TAGS-FILE.
O Emacs identifica o arquivo fonte automaticamente a partir da tabela de tags."
  (interactive
   (list (read-file-name "Arquivo de TAGS: ")
         (read-string "Nome da Tag (ex: repl): ")
         (let ((m (read-string "Major-mode (opcional, ex: c++-mode): ")))
           (if (string-empty-p m) nil (intern m)))
         (y-or-n-p "Adicionar ao contexto do gptel? ")
         (y-or-n-p "Tornar o buffer visível agora? ")))
  
  (let* ((tags-file-name (expand-file-name tags-file))
         (context-buf-name (format "*gptel-context:%s*" tag-name))
         content)
    
    (save-excursion
      ;; 1. Garante que a tabela de tags correta seja usada
      (visit-tags-table tags-file-name)
      (condition-case nil
          ;; find-tag-noselect abre o arquivo e posiciona o cursor na tag silenciosamente
          (let ((target-buf (find-tag-noselect tag-name)))
            (with-current-buffer target-buf
              (save-excursion
                (save-restriction
                  (widen)
                  ;; 2. Aplica o modo para garantir a navegação por defun
                  (when (and mode (not (eq major-mode mode))) (funcall mode))
                  ;; 3. Isola a função
                  (beginning-of-defun)
                  (let ((beg (point)))
                    (end-of-defun)
                    (setq content (buffer-substring-no-properties beg (point))))))))
        (error (error "Erro: Tag '%s' não encontrada em %s" tag-name tags-file-name))))

    ;; 4. Gerenciamento do Buffer de Resultado
    (if content
        (let ((res-buf (get-buffer-create context-buf-name)))
          (with-current-buffer res-buf
            (erase-buffer)
            (insert content)
            (set-buffer-modified-p nil)
            (when mode (funcall mode))
            (if add-to-context-p
                (progn (require 'gptel-context) (gptel-add))
              (when (featurep 'gptel-context) (gptel-context-remove res-buf))))
          (if make-visible-p (pop-to-buffer res-buf))
          (message "Tag '%s' processada com sucesso." tag-name)
          res-buf)
      (message "Erro: Falha ao capturar conteúdo da tag '%s'." tag-name))))


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
(remove-hook 'gptel-post-response-functions #'gptel-slim-context-cleanup)
(add-hook 'gptel-post-response-functions #'gptel-slim-context-cleanup)

;;--- Tool de investigação
(gptel-make-tool
 :name "investigate_code_tag"
 :function (lambda (tags_file tag_name &optional major_mode)
             (condition-case err
                 (let ((buffer (gptel-tag-core-extractor tags_file tag_name (when major_mode (intern major_mode)) t nil)))
                   (with-current-buffer buffer
                     (buffer-substring-no-properties (point-min) (point-max))))
               (error (format "Erro ao investigar tag '%s': %s" tag_name (error-message-string err)))))
 :description "Extract and analyze a specific code fragment (function/variable) from the source code using a TAGS file. 
Use this to investigate the implementation of a suspected cause-root without reading the whole file."
 :args (list '(:name "tags_file" :type string :description "Path to the TAGS file")
             '(:name "tag_name" :type string :description "The name of the function or definition to investigate")
             '(:name "major_mode" :type string :optional t :description "The major-mode to use (e.g., 'c++-mode')"))
 :category "investigation")
