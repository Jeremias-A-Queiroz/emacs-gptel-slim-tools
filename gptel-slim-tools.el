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
