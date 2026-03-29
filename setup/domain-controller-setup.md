# Domain Controller Setup

## Overview
This document covers the deployment of the primary Windows Server 2022 domain controller for the Fort Reign lab.

## Server Role
- Hostname: LAB-DC01
- Operating System: Windows Server 2022
- Domain: `lab.local`

## Deployment Steps

### 1. Install Windows Server 2022
Deploy the server as a VM in Proxmox with appropriate CPU, RAM, disk, and network settings.

### 2. Assign Static IP Configuration
Set a static IP address appropriate for the server VLAN.
Configure:
- IP address
- Subnet mask
- Default gateway
- Preferred DNS server

### 3. Rename the Server
Rename the host to `LAB-DC01` and reboot if required.

### 4. Install Required Roles
Using Server Manager, install:
- Active Directory Domain Services
- DNS Server

### 5. Promote to Domain Controller
Promote the server to a new forest:
- Root domain name: `lab.local`

During promotion:
- Configure the Directory Services Restore Mode password
- Accept DNS installation if prompted
- Reboot after promotion completes

### 6. Validate Deployment
After reboot:
- Sign in with the domain administrator account
- Open Active Directory Users and Computers
- Open DNS Manager
- Confirm the domain and DNS zones were created successfully

## Notes
Active Directory depends heavily on DNS. Incorrect DNS settings are one of the most common causes of domain join and authentication issues.