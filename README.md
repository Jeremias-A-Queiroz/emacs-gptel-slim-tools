# gptel-slim-tools 🚀

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Emacs](https://img.shields.io/badge/Emacs-%237F5AB6.svg?style=flat&logo=gnu-emacs&logoColor=white)

A collection of lightweight, high-performance utilities for Emacs and gptel. This repository serves as a personal 
knowledge base and toolset shared with the community, focused on providing **Lean Context Generation** for 
efficient code investigation and troubleshooting.

## 🔬 The Philosophy: Lean Context

Traditional methods of feeding code to LLMs often involve heavy AST parsing, LSP overhead, or loading complex 
major modes. `gptel-slim-tools` implements a **Geometric Slicing Strategy** that operates purely on coordinate 
metadata from TAGS files.

By calculating the "Next Neighbor" in the index, the tool extracts precise code fragments with near-zero latency. 
It is language-agnostic, Suckless-compliant, and avoids the computational cost of syntax highlighting or structural 
navigation within the source buffer.

## 🛠 Core Components

- **`gptel-slim-locate`**: A high-performance engine that identifies tag coordinates and determines code boundaries 
  by predicting the next entry in the TAGS file.
- **`gptel-slim-fetch-tag-full`**: An automated extractor that retrieves complete definitions into ephemeral 
  buffers, ensuring the LLM receives clean, raw text for analysis.
- **`investigate_code_tag`**: A specialized gptel tool wrapper that enables the LLM to autonomously explore 
  codebases by requesting specific tags.

---

## 📖 TAGS Generation Guide

For optimal results, project indices must be maintained in an Emacs-compatible TAGS format.

### 1. Primary Method: Native `etags` (Standard)
The `etags` utility is the recommended approach for native Emacs integration. It is reliable and provided 
with the GNU Emacs distribution.

**Recursive Generation (General):**
```bash
find . -type f -not -path '*/.*' | xargs etags -a
``` 

**Language-Specific Examples:**
- **Python:** `find . -name "*.py" | xargs etags -a`
- **C/C++:** `find . -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" \) -exec etags -a {} +`
- **PHP:** `find . -name "*.php" | xargs etags -a`

**Forcing Language Parsing (e.g., Arduino/C++):**
```bash
etags --language=c++ /.ino
```

### 2. Secondary Method: Universal Ctags / Exuberant Ctags
When advanced regex-based detection is necessary, Ctags can be employed. The `-e` flag is **mandatory** for 
compatibility with the gptel-slim-tools engine.

**General Generation:**
```bash
ctags -e -R -f TAGS .
```

**Excluding Heavy Directories:**
```bash
find . -type d \( -path "./.*" -o -path "./node_modules" \) -prune -o -type f -print | xargs ctags -e -a -f TAGS
```

---

## 🔧 Installation and Tool Integration

1. Load `gptel-slim-tools.el` into your Emacs session.
2. Ensure a valid `TAGS` file exists in the project root.
3. Register the investigation tool within `gptel`:

```elisp
(gptel-make-tool
 :name "investigate_code_tag"
 :description "Extract the full definition of a code tag using the project TAGS file."
 :arguments '(tag_name tags_file)
 :handler (lambda (tag_name tags_file)
            (condition-case err
                (let ((buffer (gptel-slim-fetch-tag-full tag_name tags_file nil)))
                  (with-current-buffer buffer
                    (buffer-substring-no-properties (point-min) (point-max))))
              (error (format "Error: %s" (error-message-string err))))))
``` 

## ⚖ License

This software is licensed under the **GPLv3 License**.

---
*"Simplicity is the soul of efficiency."* - Developed for personal use and shared for the Emacs community.
