# Fort Reign – SysAdmin Lab

## Overview
The Fort Reign SysAdmin Lab is a simulated enterprise infrastructure project built to demonstrate core system administration skills across virtualization, Windows Server administration, Active Directory, network services, segmentation, and automation.

This repository documents the foundational layer of the broader Fort Reign homelab, which supports future SOC, cloud, help desk, and compliance projects.

## Objectives
- Deploy and configure a Proxmox VE virtualization environment
- Build a Windows Server 2022 domain controller
- Configure Active Directory, DNS, and DHCP services
- Implement VLAN-based segmentation for management, lab, attack, and IoT networks
- Establish administrative baselines and automation with PowerShell
- Create repeatable documentation for rebuilds and troubleshooting

## Environment Summary
- Hypervisor platform: Proxmox VE
- Core server: Windows Server 2022
- Domain: `lab.local`
- Core infrastructure services:
  - Active Directory Domain Services
  - DNS
  - DHCP
  - Group Policy
- Network model:
  - Management VLAN
  - Lab VLAN
  - Attack VLAN
  - IoT VLAN

## Repository Structure
```text
fortreign-sysadmin-lab/
├── README.md
├── architecture/
├── setup/
├── services/
├── automation/
├── security/
├── troubleshooting/
└── screenshots/