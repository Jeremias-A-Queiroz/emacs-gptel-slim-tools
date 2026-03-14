# ROADMAP: gptel-copilot-mode & JIT Context Intelligence 🚀

This document outlines the strategic evolution of the gptel-slim-tools ecosystem, 
moving from static file-based indexing to active, buffer-aware contextual 
intelligence.

## 🎯 Vision Statement
Create a seamless, non-intrusive minor mode that maintains a "Thin Context" 
awareness of the developer's current focus, enabling the LLM to autonomously 
investigate the active buffer's structure (AST or Imenu) without manual 
copy-pasting or context bloating.

---

## 🛠 Phase 1: The Copilot Minor Mode (The Sentinel)
The objective is to create =gptel-copilot-mode=, a lightweight observer that 
prepares the "Map of the Moment" whenever a query is triggered.

- [ ] **Dynamic Dispatcher:** Implement logic to detect the best available 
      indexing engine (Tree-sitter > Imenu > Regex).
- [ ] **Idle-Triggered Indexing:** Use =run-with-idle-timer= or =post-command-hook= 
      to update a local "Lean Buffer Map" (LBM) in the background.
- [ ] **Context Injection:** Hook into =gptel-request= to automatically append 
      the LBM to the outgoing prompt.
      - *Format:* A compact list of top-level nodes: =((type name start-line end-line) ...)=.

---

## 🌲 Phase 2: AST Deep Investigation (The X-Ray Tool)
Develop a specialized tool for buffers using the Tree-sitter engine to allow 
granular, structural code exploration.

- [ ] **Tool: =investigate_ast_node=**:
      - **Input:** Node ID or Function Name.
      - **Capability:** Perform structural queries (e.g., "List all 'if' 
        conditions inside this function").
      - **Benefit:** Allows the LLM to analyze logic flow without requesting 
        the entire 500-line body of a function.
- [ ] **Sub-Slicing Logic:** Extract specific code "branches" (e.g., just the 
      =switch= block) based on AST node coordinates.

---

## ⚡ Phase 3: Polyfill & Fallback (The Universal Bridge)
Ensure the toolset remains functional in legacy environments (non-TS modes).

- [ ] **Imenu Integration:** Map =imenu--index-alist= to the same "Lean Index" 
      format used by the AST engine.
- [ ] **Geometric Slicing Integration:** Use the existing =gptel-slim-tools= 
      logic to fetch code segments when structural AST data is unavailable.
- [ ] **Hybrid Navigation:** Allow the LLM to cross-reference the active 
      buffer's AST with the project-wide =TAGS= file for out-of-buffer calls.

---

## 📈 Performance & Suckless Principles

1. **Lazy Loading:** Code content is only fetched when the LLM explicitly 
   calls the tool. The initial prompt contains only the *Names* and *Maps*.
2. **Zero-Noise Syntax:** No =font-lock= or faces processed during 
   investigation.
3. **Async Awareness:** Ensure Tree-sitter queries do not block the 
   Emacs UI during heavy buffer edits.

---

## 📅 Future Milestones
- **Cross-File Awareness:** LLM suggests opening a specific file based on 
  detected calls in the AST.
- **Refactoring Proposals:** LLM returns targeted AST node replacements 
  instead of full-buffer diffs.

---
*"Building a bridge between the editor's syntax and the model's reason."*
