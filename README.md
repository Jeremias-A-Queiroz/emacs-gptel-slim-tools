# gptel-slim-tools

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Emacs](https://img.shields.io/badge/Emacs-%237F5AB6.svg?style=flat&logo=gnu-emacs&logoColor=white)

A collection of lightweight, high-performance utilities for Emacs and gptel. This repository serves as a personal 
knowledge base and toolset shared with the community, focused on providing **Lean Context Generation** for 
efficient code investigation and troubleshooting.

## 🔬 The Philosophy: Bimodal Lean Context

Feeding entire projects or huge files to an LLM is inefficient. `gptel-slim-tools` implements a bimodal context 
strategy, ensuring the LLM gets exactly what it needs, when it needs it, minimizing token usage and latency:

1. **Global Project Scope (Static/Persisted):** Uses a **Geometric Slicing Strategy** on TAGS files. It calculates 
   the "Next Neighbor" in the index to extract precise code fragments from any file in the project with near-zero 
   latency, completely bypassing the need to open or parse those files structurally.
2. **Local Buffer Scope (Dynamic/On-the-fly):** For files currently being edited (even unsaved ones), it extracts 
   structural metadata and function boundaries directly from the active buffer, enabling real-time coding assistance.

## 🛠 Core Components & Tools

The package registers three highly specialized tools directly into `gptel`:

- **`investigate_code_tag`** (Global): Enables the LLM to autonomously explore codebases by requesting specific tags 
  from a project-wide TAGS file. Perfect for understanding external dependencies or full project architecture.
- **`list_buffer_tags`** (Local): Allows the LLM to scan the current open buffer and list all available structures 
  (functions, classes, keys) to understand the local context.
- **`read_tag_source`** (Local): Extracts the exact source code of a specific tag/function directly from the live 
  buffer, allowing the LLM to read your unsaved implementations on-the-fly.

### 🧹 Ephemeral Buffers & Memory Management
The global extraction engine uses temporary buffers (`*gptel-context:...*`) to securely pass raw text to the LLM. 
To prevent your buffer list from becoming cluttered, the package includes `gptel-slim-context-cleanup`, a silent 
garbage collector that hooks into `gptel-post-response-functions` and automatically destroys these buffers once 
the LLM completes its response.

---

## ⚙️ How the Magic Works (Graceful Degradation)

For the local buffer tools (`list_buffer_tags` and `read_tag_source`), the extraction engine is highly resilient 
and language-agnostic. It attempts to read your code using a smart hierarchy:

1. **Tree-sitter (Primary):** If available (Emacs 29+), it uses modern, high-precision AST parsing.
2. **Semantic Mode (Secondary):** If Tree-sitter is unavailable, the system falls back to Emacs' Semantic parser. 
   **Note:** If you are on Emacs 28 or older, or lacking Tree-sitter grammars, we highly recommend enabling 
   `semantic-mode` to ensure accurate extraction.
3. **Imenu (Tertiary):** The universal, regex-based fallback. It works out-of-the-box for almost any major mode 
   but may lack the precise boundary detection of the first two methods.

---

## 📖 TAGS Generation Guide (For Global Scope)

For optimal project-wide results using `investigate_code_tag`, maintain an Emacs-compatible TAGS file in your root.

### Primary Method: Native `etags` (Standard)
Provided natively with Emacs. Highly reliable and recommended.
```bash
* General recursive generation
find . -type f -not -path '*/.*' | xargs etags -a

* Language-specific examples
find . -name "*.py" | xargs etags -a
find . -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" \) -exec etags -a {} +
```
Forcing Language Parsing (e.g., Arduino/C++):
```bash
etags --language=c++ /.ino
```

### Secondary Method: Universal Ctags
When advanced detection is needed. The `-e` flag is **mandatory** for Emacs compatibility.
```bash
ctags -e -R -f TAGS .
``` 

---

## 🔧 Installation

### Method 1: Quick Evaluation (Recommended for testing)
Clone the repository to your source directory and load it directly into your running Emacs session to test it 
without polluting your configuration.

```bash
cd ~/src
git clone https://github.com/jeremias-a-queiroz/emacs-gptel-slim-tools.git
``` 
In Emacs, evaluate:
```lisp
(load "~/src/emacs-gptel-slim-tools/gptel-slim-tools.el")
``` 

### Method 2: Permanent Setup
Once you are satisfied with the tools, move the file to your Emacs Lisp directory and require it in your `init.el`.

```bash
cp ~/src/emacs-gptel-slim-tools/gptel-slim-tools.el ~/.emacs.d/lisp/
``` 
```lisp
(add-to-list 'load-path "~/.emacs.d/lisp/")
(require 'gptel-slim-tools)
```
*(Ensure you add `(provide 'gptel-slim-tools)` to the very end of your `.el` file for the require to work).*

---

## 💡 Suggested Workflow / LLM Prompt

To maximize the efficiency of these tools, you can instruct your LLM with a prompt similar to this:

> *"Analyze the current buffer using `list_buffer_tags` to understand its structure. If you need to read the 
> exact implementation of a local function, use `read_tag_source`. If the code references an external function 
> or dependency belonging to this project, use `investigate_code_tag` along with the project's TAGS file to 
> extract its full definition before providing your final answer."*

## ⚖ License

This software is licensed under the **GPLv3 License**.

---
*"Simplicity is the soul of efficiency."* - Developed for personal use and shared for the Emacs community.
