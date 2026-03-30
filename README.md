# Fort Reign – SysAdmin Lab

## Overview
The Fort Reign SysAdmin Lab is a simulated federal contractor IT environment designed to replicate real-world system administration, identity management, and enterprise infrastructure operations.

Modeled after a garrison-style operations center, Fort Reign was built using a structured implementation blueprint that defines its Active Directory architecture, departmental organization, file share design, and baseline user activity simulation.

This repository documents the foundational infrastructure layer supporting downstream SOC, cloud, help desk, and compliance-focused projects.

---

## 🏗️ Implementation Blueprint

Fort Reign was developed using a structured implementation plan to ensure consistency, scalability, and realism.

The blueprint defines:

- A 6-department organizational structure:
  - Command  
  - IT Operations  
  - Security Operations  
  - Human Resources  
  - Finance  
  - Logistics  

- 25–30 simulated employee accounts aligned to departments  
- Department-based Organizational Units (OUs)  
- Role-based security groups for access control  
- Departmental file shares with realistic business data  
- Automated user activity simulation for baseline telemetry  

This structured approach enables realistic system administration, auditing, and future SIEM-driven detection scenarios.

---

## 🏢 Enterprise Simulation

Fort Reign reflects a real-world enterprise network with structured identity and access management.

- Users are organized by department and role  
- Access is controlled using security groups and least-privilege principles  
- File shares are segmented by department with controlled permissions  
- The environment supports realistic operational and security workflows  

This design mirrors enterprise and government IT environments.

---

## 🗂️ Active Directory Architecture

The Active Directory environment was designed to support scalable and audit-friendly identity management.

### Organizational Units (OUs)
- Top-level Fort Reign OU  
- Department-based OUs:
  - Command  
  - IT Operations  
  - Security Operations  
  - Human Resources  
  - Finance  
  - Logistics  
- Supporting OUs:
  - Computers  
  - Groups  
  - Service Accounts  

### Security Groups
- Department-based access groups  
- Administrative privilege groups  
- Help desk and support groups  
- Remote access groups  

### Identity Design Goals
- Enable role-based access control (RBAC)  
- Support scalable user and group management  
- Provide audit-ready structure for monitoring  
- Simulate enterprise identity systems  

---

## 🎯 Objectives

- Deploy and configure a Proxmox VE virtualization environment  
- Build and configure a Windows Server 2022 domain controller  
- Implement Active Directory, DNS, and DHCP services  
- Design VLAN-based network segmentation  
- Enforce role-based access control using AD security groups  
- Automate administrative workflows using PowerShell  
- Create repeatable deployment and troubleshooting documentation  

---

## 🏗️ Environment Summary

- **Hypervisor Platform:** Proxmox VE  
- **Core Server:** Windows Server 2022  
- **Domain:** `lab.local`  

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

## ⚙️ Automation

This lab incorporates PowerShell automation to standardize deployment, enforce consistency, and simulate real-world enterprise activity.

### Capabilities
- Full Active Directory environment build and teardown  
- Department-aligned user provisioning  
- Automated group membership and access assignment  
- Simulated user and file activity for behavioral realism  
- Domain controller auditing and validation  

### Purpose
These scripts enable repeatable infrastructure deployment, reduce manual configuration, and generate realistic enterprise telemetry to support SOC monitoring and detection engineering workflows.

### Automation Structure
```text
automation/
├── ad/
├── simulation/
├── audit/
└── utils/
---

### 🧠 Skills Demonstrated

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

This project demonstrates practical, job-relevant experience in:

- System Administration  
- IT Infrastructure Operations  
- Identity and Access Management (IAM)  
- Security-focused enterprise environments  

Fort Reign reflects real-world enterprise design patterns, including centralized identity management, segmented networks, controlled access to resources, and structured user environments suitable for monitoring and compliance.
---

## 📁 Repository Structure

fortreign-sysadmin-lab/
├── README.md
├── architecture/
├── setup/
├── services/
├── automation/
├── security/
├── troubleshooting/
└── screenshots/