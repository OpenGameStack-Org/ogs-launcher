# Open Game Stack (OGS)

![Status](https://img.shields.io/badge/Status-Prototype-orange)
![Engine](https://img.shields.io/badge/Godot-4.3-blue)
![License](https://img.shields.io/badge/License-MIT-green)

> **The "Studio-in-a-Box" for Sovereign Game Development.**

## 🎮 What is Open Game Stack?
Open Game Stack (OGS) is a **portable, pre-configured development environment** that bundles the best open-source tools into a single, version-controlled workflow.

Instead of installing Godot, Blender, Krita, and Audacity separately—and hoping their versions match your team's—OGS gives you a **"Frozen Stack."** 

### One Download. Zero Install.
* **The Engine:** Godot 4.3 (Stable / Hardened)
* **The Pipeline:** Blender LTS, Krita, Audacity
* **The Promise:** Everything runs from a single folder. No registry keys, no `%APPDATA%`, no installers.

---

## 🚀 Why Use OGS?

### For Indie Devs & Studios: "It Just Works"
* **Onboarding in Seconds:** Clone the repo, click "Launch," and you have the exact same tools as the rest of your team.
* **USB Portable:** Run your entire studio from a flash drive. Move between Windows and Linux without breaking your project.
* **No "Update Shock":** We freeze the tool versions. Your project won't break because Blender auto-updated overnight.

### For Enterprise & Defense: "Sovereign Simulation"
* **Air-Gap Native:** Designed for secure environments. The OGS Launcher can enforce a strict **Offline Mode**, disabling all network sockets and "phone home" telemetry.
* **Environment as the Artifact:** Don't just archive your source code; archive the *factory* that built it. Ensure you can rebuild your project in 20 years, even if the vendors disappear.
* **Supply Chain Security:** Eliminate reliance on subscription servers and proprietary license validation.

---

## 🛠️ The OGS Launcher
The heart of the stack is the **OGS Launcher**, a custom application (built in Godot!) that manages your development environment.



### Core Features
* **Manifest System (`stack.json`):** A simple text file that defines exactly which version of Godot or Blender your project requires.
* **Dual-Mode Operation:**
    * **Provisioning Mode:** For connected workstations. Downloads and sets up tools automatically.
    * **Sovereign Mode:** For secure labs. Locks the environment to "Read-Only" and blocks internet access.
* **Project "Sealing":** An automated workflow to clean, sanitize, and lock a project for delivery or long-term archival.

---

## 📂 Documentation
* **[Technical Design Document](docs/DESIGN_DOC.md):** Deep dive into the "Frozen Stack" architecture, directory structure, and `stack.json` schema.
* **[Sample Projects](samples/README.txt):** Quick launcher test inputs for both development/linked mode and sealed-style mode.

## 🏁 Getting Started

### Prerequisites
* Windows 10/11 or Linux (Ubuntu 22.04+)
* [Godot 4.3](https://godotengine.org) (To run the Launcher source)

### Quick Start
1.  **Clone the Repo:**
    ```bash
    git clone [https://github.com/open-game-stack/open-game-stack.git](https://github.com/open-game-stack/open-game-stack.git)
    ```
2.  **Open in Godot:** Import the `project.godot` file into the Godot Editor.
3.  **Run:** Press F5 to start the OGS Launcher.
4.  **Create a Stack:** Click "New Project" to generate a `stack.json` and download the default toolset.

---

## 🤝 Contributing
We are building the standard for open, portable, and sovereign game development. 
Whether you are an indie dev fixing a UI bug or a systems engineer hardening the build pipeline, we want your help.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---
**Open Game Stack** | *Owned by the Community. Sustained by the Code.*