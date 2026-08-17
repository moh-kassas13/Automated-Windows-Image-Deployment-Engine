# Automated WinPE Deployment Engine

**Author & System Architect:** Mohammad Kassas  
**Platform:** Windows Preinstallation Environment (WinPE) / PowerShell / Diskpart / DISM  

---

## Overview
An automated, production-ready Windows imaging framework designed for rapid enterprise PC deployment. The engine automates target drive selection, GPT/UEFI disk partitioning, DISM image application, BCD bootloader setup, and unattended OOBE configuration.

## Key Features
* **Smart Drive Auto-Detection:** Automatically prioritizes NVMe and SSD storage over secondary HDDs.
* **Dual-Partition Media Support:** Bypasses FAT32 file size limits by splitting WinPE boot files and WIM payload storage.
* **Dynamic Partitioning:** Injects drive indices into modular Diskpart scripts at runtime.
* **Single-Pass Answer File:** Applies zero-touch `unattend.xml` setup without OOBE or parsing errors.

## Directory Structure
```text
USB Payload Partition
├── mk.cmd                           <-- Batch launcher script
└── Deployment/
    ├── Deploy2.ps1                  <-- Main PowerShell engine
    ├── unattend.xml                 <-- Consolidated answer file
    ├── Image/                       <-- Place .wim image files here
    └── Partition/                   <-- Diskpart script templates (.txt)
