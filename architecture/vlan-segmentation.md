# VLAN Segmentation

## Purpose
The Fort Reign lab uses VLAN segmentation to separate infrastructure management, enterprise-style workloads, attacker simulation, and untrusted devices. This improves security, visibility, and realism.

## VLAN Layout
- VLAN 10 – Management
- VLAN 20 – Lab
- VLAN 30 – Attack
- VLAN 40 – IoT

## Design Goals
- Restrict administrative access to the management network
- Reduce unnecessary east-west traffic
- Prevent attacker tooling from freely reaching infrastructure assets
- Create realistic network boundaries for future SOC monitoring and firewall validation

## Security Model
Default inter-VLAN communication should be denied unless explicitly required.

Examples:
- Management VLAN may access infrastructure administration interfaces
- Lab VLAN may access approved shared services
- Attack VLAN should only reach approved test targets
- IoT VLAN should remain constrained and isolated by default

## Operational Value
This design supports:
- Safer testing
- Better troubleshooting
- Stronger documentation
- More realistic incident detection scenarios