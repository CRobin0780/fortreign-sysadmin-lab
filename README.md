# Fort Reign – SysAdmin Lab

## Overview
The Fort Reign SysAdmin Lab is a simulated enterprise IT environment designed to replicate real-world system administration, identity management, and infrastructure operations.

This lab models a federal contractor-style garrison operations environment and serves as the foundational layer for SOC monitoring, cloud integration, help desk operations, and compliance workflows.

---

## 🏢 Enterprise Simulation

Fort Reign is structured to reflect a realistic organizational environment with:

- 27 user accounts across 6 departments:
  - Finance
  - IT Operations
  - Security Operations
  - Human Resources
  - Logistics
  - Command

This structure enables realistic identity management, access control, and auditing scenarios similar to those found in enterprise and government environments.

---

## 🗂️ Active Directory Architecture

A full Active Directory environment was designed and deployed to simulate enterprise identity and access management.

### Organizational Units (OUs)
- Department-based OUs for logical separation
- Administrative OUs for servers, users, and privileged accounts

### Security Groups
- Role-based access control aligned to departments
- Group membership used to manage permissions and delegation

### File Shares & Permissions
- Department-specific shared folders
- NTFS permissions aligned with least-privilege principles
- Access restricted based on job function and role

---

## 🎯 Objectives

- Deploy and configure a Proxmox VE virtualization environment  
- Build a Windows Server 2022 domain controller  
- Configure Active Directory, DNS, and DHCP services  
- Implement VLAN-based segmentation (Management, Lab, Attack, IoT)  
- Establish role-based access control using AD security groups  
- Automate administrative tasks using PowerShell  
- Create repeatable documentation for deployment and troubleshooting  

---

## 🏗️ Environment Summary

- Hypervisor Platform: Proxmox VE  
- Core Server: Windows Server 2022  
- Domain: `lab.local`  

### Core Services
- Active Directory Domain Services (AD DS)  
- DNS  
- DHCP  
- Group Policy  

### Network Segmentation
- Management VLAN  
- Lab VLAN  
- Attack VLAN  
- IoT VLAN  

---

## 🧠 Skills Demonstrated

- Windows Server administration  
- Active Directory design and management  
- DNS and DHCP configuration  
- Group Policy implementation  
- Network segmentation (VLANs)  
- Role-Based Access Control (RBAC)  
- PowerShell automation  
- Enterprise infrastructure design  

---

## 🎯 Why This Project Matters

This project demonstrates the practical skills required for:

- System Administration roles  
- IT Support and infrastructure operations  
- Identity and Access Management (IAM)  
- SOC and security monitoring environments  

It reflects real-world enterprise design patterns, including centralized identity, segmented networks, and controlled access to resources.

---

## 📁 Repository Structure

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

## 📸 Screenshots (Coming Soon)
- Proxmox dashboard
- Active Directory Users & Computers
- DHCP scope configuration
- VLAN configuration on switch
