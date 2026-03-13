(defun gptel-slim-locate (tag-name tags-file)
  "Localiza TAG-NAME no TAGS-FILE buscando o padrão (tag-name  linha,offset)."
  (with-current-buffer (find-file-noselect tags-file)
    (save-excursion
      (goto-char (point-min))
      ;; Buscamos o nome da tag seguido de dois espaços ou o caractere de controle 127
      (if (re-search-forward (format "%s[\177 ]+\\([0-9]+\\)," (regexp-quote tag-name)) nil t)
          (let ((line-num (string-to-number (match-string 1))))
            (re-search-backward "\f\n\\([^,\n]+\\)," nil t)
            (list (expand-file-name (match-string 1) (file-name-directory tags-file))
                  line-num))
        (error "Tag '%s' não encontrada em %s" tag-name tags-file)))))

(defun gptel-slim-fetch-tag-full (tag-name tags-file &optional add-to-context-p make-visible-p)
  "Localiza a TAG-NAME de forma precisa e extrai a definição completa (defun). Opcionalmente adciona ao contexto do gptel"
  (interactive
   (list (read-string "Tag: " (thing-at-point 'symbol))
         (read-file-name "Arquivo TAGS: ")
         t))
  (let* ((loc (gptel-slim-locate tag-name tags-file))
         (file (nth 0 loc))
         (line (nth 1 loc))
         (buf-name (format "*gptel-context:%s*" tag-name))
         content)
    
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (forward-line (1- line))
          ;; AJUSTE: Move o cursor para o fim da linha para garantir que 
          ;; o Emacs entenda que estamos 'dentro' da função alvo.
          (end-of-line)
          (beginning-of-defun)
          (let ((beg (point)))
            (end-of-defun)
            (setq content (buffer-substring-no-properties beg (point)))))))

    (let ((res-buf (get-buffer-create buf-name)))
      (with-current-buffer res-buf
        (erase-buffer)
        (insert content)
        (set-buffer-modified-p nil)
        ;; Aplica o modo baseado no arquivo original para realce e indentação
        (let ((default-directory (file-name-directory file)))
          (set-auto-mode t))
	;; context management
	(if add-to-context-p
	    (progn (require 'gptel-context) (gptel-add)
		   (when (featurep 'gptel-context) (gptel-context-remove res-buf))))
      (if make-visible-p
          (pop-to-buffer res-buf)
        res-buf)))))


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
                 (let ((buffer (gptel-slim-fetch-tag-full tag_name tags_file t nil)))
                   (with-current-buffer buffer
                     (buffer-substring-no-properties (point-min) (point-max))))
               (error (format "Erro ao investigar tag '%s': %s" tag_name (error-message-string err)))))
 :description "Extract and analyze a specific code fragment (function/variable) from the source code using a TAGS file. 
Use this to investigate the implementation of a suspected cause-root without reading the whole file."
 :args (list '(:name "tag_name" :type string :description "The name of the function or definition to investigate")
             '(:name "tags_file" :type string :description "Path to the TAGS file"))
 :category "investigation")
