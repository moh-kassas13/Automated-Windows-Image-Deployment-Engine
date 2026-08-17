# Windows Image Files (WIM) Directory

**Author:** Mohammad Kassas  
**Project:** Automated WinPE Deployment Engine  

---

## Instructions

1. Place your Windows OS image files (`.wim`) inside this directory (e.g., `Win1125H2New.wim`).
2. The deployment engine (`Deploy2.ps1`) automatically scans this directory at runtime and displays all available `.wim` files in an interactive selection menu.

---

*Note: Large OS image files (`.wim`, `.esd`, `.iso`) are excluded from Git tracking via `.gitignore` due to GitHub's file size limits.*
