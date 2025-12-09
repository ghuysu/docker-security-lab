#!/bin/bash

#=============================================================================
# Kali Container Setup Script
# Description: Install required tools for DVWA penetration testing
#=============================================================================

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║        Kali Container Setup - Installing Tools                 ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Update package list
echo "[1/6] Updating package list..."
apt update -qq

# Install basic tools
echo "[2/6] Installing basic utilities (curl, wget, nano)..."
apt install -y curl wget nano net-tools iputils-ping 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking"

# Install nmap
echo "[3/6] Installing nmap (network scanner)..."
apt install -y nmap 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking"

# Install sqlmap
echo "[4/6] Installing sqlmap (SQL injection tool)..."
apt install -y sqlmap 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking"

# Install hydra
echo "[5/6] Installing hydra (brute force tool)..."
apt install -y hydra 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking"

# Install netcat (usually pre-installed)
echo "[6/6] Verifying netcat availability..."
if ! command -v nc &> /dev/null; then
    apt install -y netcat-traditional 2>&1 | grep -v "^Selecting\|^Preparing\|^Unpacking"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ Setup completed successfully!"
echo ""
echo "Installed tools:"
echo "  • nmap: $(nmap --version | head -n1)"
echo "  • sqlmap: $(sqlmap --version 2>&1 | head -n1)"
echo "  • hydra: $(hydra -h 2>&1 | head -n1)"
echo "  • curl: $(curl --version | head -n1)"
echo "  • nc (netcat): $(nc -h 2>&1 | head -n1)"
echo ""
echo "You can now run: ./interactive_attack.sh"
echo "════════════════════════════════════════════════════════════════"
