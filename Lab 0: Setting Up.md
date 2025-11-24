# Lab 0: Setting Up

Welcome to the SRE Workshop! This guide (Lab 0) covers the prerequisites and installations needed before starting the hands-on labs. Installing these tools in advance will ensure a smooth experience. All tools are free, and the setup should take 15-30 minutes.

## Why This Setup?
These tools allow you to run the sample applications, monitoring systems (like Prometheus), and simulations locally without any cloud costs or dependencies. We'll use Docker to containerize everything, keeping your local machine clean.

## Required Installations

### 1. Docker
- **Purpose**: Containers the sample app and tools like Prometheus for easy deployment.
- **Installation Steps**:
  - Download and install Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop).
  - On macOS: Use Homebrew with `brew install --cask docker`.
  - On Linux: Follow distro-specific instructions (e.g., `sudo apt install docker.io` on Ubuntu).
  - On Windows: Enable WSL (Windows Subsystem for Linux) for better performance.
- **Verification**: Open a terminal and run `docker --version`. You should see the version number.
- **Tips**: Ensure virtualization is enabled in your BIOS/UEFI settings if you encounter errors.

### 2. Docker Compose
- **Purpose**: Manages multi-container setups (e.g., app + monitoring).
- **Installation Steps**:
  - Included with Docker Desktop on Windows and macOS.
  - On Linux: Install separately with `sudo apt install docker-compose` (or equivalent for your distro).
- **Verification**: Run `docker-compose --version` in your terminal.
- **Tips**: If not found, add it to your PATH or reinstall Docker.

### 3. Load Testing Tool (Apache Bench or Locust)
- **Purpose**: Simulates traffic to test the app and validate SLOs.
- **Option 1: Apache Bench (ab) - Recommended for Simplicity**
  - On macOS: Install via Homebrew with `brew install httpd` (ab is included).
  - On Linux: `sudo apt install apache2-utils`.
  - On Windows: Use WSL or download from the Apache website.
  - **Verification**: Run `ab -V`.
- **Option 2: Locust - For More Advanced Testing**
  - Requires Python 3.x (download from [python.org](https://www.python.org) if not installed).
  - Install with `pip install locust`.
  - **Verification**: Run `locust --version`.

## Recommended/Optional Installations

### 1. Git
- **Purpose**: Clone repositories if we provide one for the full workshop (optional for Lab 1).
- **Installation Steps**: Download from [git-scm.com](https://git-scm.com/downloads).
- **Verification**: Run `git --version`.

### 2. Text Editor or IDE (e.g., Visual Studio Code)
- **Purpose**: Edit code files, YAML configs, and documentation.
- **Installation Steps**: Download VS Code from [code.visualstudio.com](https://code.visualstudio.com). Install extensions for Python, YAML, and Docker for better support.
- **Alternatives**: Use Notepad++, Vim, or any preferred editor.

## Additional Notes
- **No Local Python or Other Runtimes Needed**: All lab code runs inside Docker containers.
- **OS Compatibility**: Tested on macOS, Linux, and Windows (use WSL on Windows for terminal commands).
- **Troubleshooting**:
  - Docker errors? Check system requirements and restart the Docker service.
  - Firewall issues? Ensure ports like 5000 and 9090 are open locally.
  - On corporate networks: You may need admin rights or VPN adjustments.
- **Alternative to Local Setup**: If installations are problematic, use GitHub Codespaces (free tier) for a browser-based environment—no local installs required.
- **Preparation Time**: Aim to complete this before the workshop starts.

Once set up, you're ready for Lab 1! If you run into issues, note them down for discussion during the workshop. Happy setting up! 🚀
