# gptel-slim-tools

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Emacs](https://img.shields.io/badge/Emacs-%237F5AB6.svg?style=flat&logo=gnu-emacs&logoColor=white)

A collection of lightweight, high-performance utilities designed to extend [gptel](https://github.com/karthink/gptel) by providing **Lean Context Generation** for efficient codebase investigation and troubleshooting. 

This package transforms the Large Language Model (LLM) from a passive text-completion engine into an active, autonomous investigator (Agentic AI) capable of retrieving strictly necessary code definitions without polluting the context window.

## 🔬 The Philosophy: Bimodal Lean Context

Feeding entire projects or overly large files to an LLM is highly inefficient, consumes excessive tokens, and frequently leads to hallucinations. `gptel-slim-tools` implements a bimodal context strategy, ensuring the LLM extracts exactly what it needs, when it needs it:

1. **Global Project Scope (Static/Persisted):** Employs a deterministic extraction algorithm on project-wide TAGS files. It calculates exact structural boundaries to extract isolated code fragments from any file in the project with near-zero latency, completely bypassing the need to structurally parse external files.
2. **Local Buffer Scope (Dynamic/On-the-fly):** For files currently being edited (including unsaved buffers), it dynamically extracts structural metadata and function boundaries directly from the active buffer, enabling real-time, highly accurate coding assistance.

---

## 🏗 Core Architecture & Internal Workings

The package registers three highly specialized tools directly into the Emacs `gptel` ecosystem. The architecture follows a strict adapter pattern to isolate the complex parsing logic from the simplified interface consumed by the LLM.

![Function Call Topology](assets/images/function-call-topology.png)

### The Three Tools:
1. **`investigate_code_tag`** (Global Scope): Enables the LLM to autonomously explore external codebase dependencies by requesting specific tags from a standard TAGS file.
2. **`list_buffer_tags`** (Local Scope): Scans the current open buffer and returns a structured list of available definitions (functions, classes, variables).
3. **`read_tag_source`** (Local Scope): Extracts the exact source code of a specific tag directly from the live buffer.

### Graceful Degradation Engine
For local buffer operations, the extraction engine guarantees high resilience by attempting to parse the source code through a hierarchical fallback mechanism:
- **Tree-sitter (Primary):** Utilizes modern AST parsing for absolute precision (Requires Emacs 29+).
- **Semantic Mode (Secondary):** A robust fallback leveraging Emacs' native Semantic parser for older versions or missing grammars.
- **Imenu (Tertiary):** A universal, regular-expression-based fallback capable of handling virtually any major mode.

### Ephemeral Memory Management
Global extraction requires the creation of hidden temporary buffers (`*gptel-context:...*`) to securely isolate and format data before it reaches the LLM. To prevent buffer bloat, the package implements `gptel-thin-tags-cleanup`, a silent garbage collector hooked into `gptel-post-response-functions` that automatically destroys these buffers once the LLM finishes its transmission.

---

## 🛠 Workflow Strategies

The tools are designed to be used in three distinct workflow paradigms, depending on the complexity of the task at hand.

### Mode 1: Global Project Scope (Macro)
**Use Case:** The developer needs to understand the architecture or debug an issue involving multiple external files within a large repository.
**Execution:** The project's root TAGS file is added to the gptel context. The LLM is instructed to use `investigate_code_tag` to autonomously chase dependencies and retrieve definitions from distant files without hallucinating.

![Global Scope](assets/images/global-scope-macro.png)

### Mode 2: Local Buffer Scope (Micro / On-the-fly)
**Use Case:** The developer is writing a new feature in a large, unsaved file and requires immediate assistance with a local function or variable.
**Execution:** The developer informs the LLM of the active buffer's name. The LLM uses `list_buffer_tags` to map the file and `read_tag_source` to read the exact, uncommitted implementation directly from the Emacs memory.

![Local Scope](assets/images/local-buffer-scope-micro.png)

### Mode 3: Hybrid Scope (Macro + Micro)
**Use Case:** The most advanced scenario. The developer is editing a file and suspects their new code conflicts with a core infrastructure file located elsewhere in the project.
**Execution:** Both local tools and the global TAGS tool are enabled. The LLM inspects the unsaved changes locally, cross-references external function calls via the TAGS index, and resolves deep structural conflicts with minimal token usage.

![Hybrid Scope](assets/images/hibrid-socope-macro-micro.png)

---

## 📖 TAGS Generation Guide (For Global Scope)

To utilize `investigate_code_tag`, an Emacs-compatible TAGS file must be maintained at the project root.

### Primary Method: Native `etags` (Standard)
Provided natively with Emacs. Highly reliable and recommended.
```bash
# General recursive generation
find . -type f -not -path '*/.*' | xargs etags -a

# Force language parcing (arduino)
etags --language=c++ /.ino

# Language-specific examples (e.g., C/C++)
find . -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" \) -exec etags -a {} +
```

### Secondary Method: Universal Ctags
When advanced language parsing is required. The `-e` flag is **mandatory** for Emacs compatibility.
```bash
ctags -e -R -f TAGS .
``` 

---

## 🔧 Installation

### Prerequisites
- Emacs 28.1 or higher (Emacs 29+ recommended for Tree-sitter support).
- [gptel](https://github.com/karthink/gptel) installed and configured.

### Method 1: Quick Evaluation (Development / Testing)
Clone the repository to a source directory and load the files directly into the running Emacs session. This is the recommended method for testing without altering your primary configuration.

```bash
cd ~/src
git clone https://github.com/jeremias-a-queiroz/emacs-gptel-slim-tools.git
``` 
In Emacs, evaluate the following:
```elisp
(load "~/src/emacs-gptel-slim-tools/gptel-thin-buffer.el")
(load "~/src/emacs-gptel-slim-tools/gptel-thin-tags.el")
``` 

### Method 2: Permanent Setup
To install the package permanently, move or clone the repository into your personal Emacs Lisp directory (`~/.emacs.d/lisp/` or `~/.config/emacs/lisp/`).

```bash
mkdir -p ~/.emacs.d/lisp
cp -r ~/src/emacs-gptel-slim-tools ~/.emacs.d/lisp/
``` 

Then, add the directory to your `load-path` and require the features in your `init.el`:
```elisp
(add-to-list 'load-path (expand-file-name "~/.emacs.d/lisp/emacs-gptel-slim-tools"))

(require 'gptel-thin-buffer)
(require 'gptel-thin-tags)
```

---

## 💡 Suggested LLM System Prompt

To maximize the autonomy and efficiency of the LLM, it is highly recommended to provide a clear system prompt (or directive) detailing how it should utilize the tools:

> *"You are an expert developer assistant operating within Emacs. To understand the local file structure, use `list_buffer_tags` on the active buffer. If you need to read the exact, unsaved implementation of a local function, use `read_tag_source`. If the code references an external dependency belonging to this project, you must use `investigate_code_tag` along with the project's TAGS file (provided in your context) to autonomously extract its full definition before providing your final answer. Do not guess or hallucinate code implementations."*

---

## ⚖ License

This software is licensed under the **GPLv3 License**.

*"Simplicity is the soul of efficiency."*
