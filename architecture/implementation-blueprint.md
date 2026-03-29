# Fort Reign Implementation Blueprint

## Overview
This document defines the structured implementation plan used to design and build the Fort Reign enterprise lab environment.

The blueprint outlines the architecture, identity design, organizational structure, access control model, and phased deployment approach used to simulate a realistic federal contractor IT environment.

## Implementation Phases

### Phase 1 – Core Infrastructure
- Proxmox VE deployment
- Virtual networking configuration
- Windows Server 2022 installation

### Phase 2 – Identity & Directory Services
- Active Directory Domain Services (AD DS)
- Organizational Unit (OU) design
- User and group creation
- DNS and DHCP configuration

### Phase 3 – Access Control & File Services
- Department-based security groups
- File share creation
- NTFS permissions aligned to least privilege

### Phase 4 – Network Segmentation
- VLAN configuration (Management, Lab, Attack, IoT)
- Traffic separation for security and monitoring

### Phase 5 – Automation & Baseline Activity
- PowerShell automation scripts
- Simulated user activity
- Baseline behavior generation for monitoring

### Phase 6 – Security & Monitoring (Future Integration)
- SIEM (Wazuh) integration
- Detection rule development
- Incident response workflows

## Design Principles

- Least Privilege: Users only have access required for their role
- Role-Based Access Control (RBAC): Permissions managed through security groups
- Segmentation: Network isolation across VLANs
- Scalability: Structured OU and group design for growth
- Auditability: Environment supports logging and monitoring use cases
- Realism: Simulated departments, users, and business workflows