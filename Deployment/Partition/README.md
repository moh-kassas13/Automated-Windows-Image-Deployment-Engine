# Diskpart Partition Templates Directory

**Author:** Mohammad Kassas  
**Project:** Automated WinPE Deployment Engine  

---

## Important Notice

The included script (`SFF Dell CreatePartitions-SSD.txt`) is provided **as an example template only**. 

Organizations must replace or add custom `.txt` files in this directory that align with their enterprise partitioning standards and hardware specifications.

---

## Guidelines for Custom Partition Scripts

When authoring custom Diskpart configuration files for this engine, ensure you adhere to the following rules:

1. **File Format:** Save all partition configurations as plain text files (`.txt`).
2. **Dynamic Disk Assignment:** Write `select disk 0` in your text file. The deployment engine (`Deploy2.ps1`) dynamically detects the chosen target drive and replaces this line at runtime.
3. **Mandatory Drive Letter Standard:**
   * **`S:`** — System / EFI Partition (Required by `bcdboot` for bootloader creation)
   * **`W:`** — Primary Windows OS Partition (Required by DISM for OS image application)
   * **`R:`** — WinRE Recovery Partition (Required for Windows Recovery Environment setup)

---

## Standard GPT/UEFI Script Structure

```cmd
select disk 0
clean
convert gpt

:: 1. System Partition (EFI)
create partition efi size=300
format quick fs=fat32 label="System"
assign letter="S"

:: 2. Microsoft Reserved (MSR)
create partition msr size=16

:: 3. Primary OS Partition
create partition primary
format quick fs=ntfs label="Windows"
assign letter="W"

:: 4. Recovery Partition (WinRE)
create partition primary size=1000
format quick fs=ntfs label="Recovery"
assign letter="R"
set id="de94b820-9411-11df-69c6-001125a05b36"
gpt attributes=0x8000000000000001
exit
