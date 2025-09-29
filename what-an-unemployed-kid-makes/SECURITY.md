# Security Policy

## Reporting Security Vulnerabilities

**Windows Auto-Install System** takes security seriously. If you discover a security vulnerability, please report it responsibly.

### Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest  | ✅       |

### How to Report

**🚨 DO NOT create public GitHub issues for security vulnerabilities**

Instead, please report security issues through:

1. **GitHub Security Advisories** (Recommended)
   - Go to the repository's Security tab
   - Click "Report a vulnerability" 
   - Fill out the private vulnerability report

2. **Direct Contact**
   - Contact vixnz through GitHub private message
   - Include "SECURITY:" in the subject line

### What to Include

Please include the following information:

- **Vulnerability Description**: Clear explanation of the issue
- **Impact**: Potential security impact and affected components
- **Reproduction Steps**: Step-by-step instructions to reproduce
- **Environment**: OS, version, and hardware details
- **Proof of Concept**: Code or screenshots (if applicable)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week  
- **Status Updates**: Every 2 weeks until resolved
- **Resolution**: Depends on severity and complexity

### Security Considerations

This software:

- ✅ **Requires root/administrator privileges** for legitimate system modifications
- ✅ **Modifies boot configuration** - this is by design
- ✅ **Creates bootable media** - erases USB device data  
- ✅ **Uses unattended installation** - installs with default credentials

### Known Security Aspects

#### By Design (Not Vulnerabilities)
- **Root Access Required**: Needed for USB creation and boot configuration
- **Boot Modification**: Necessary for automated installation
- **Default Credentials**: Creates predictable admin account (documented)
- **Unattended Mode**: Skips security prompts during Windows installation

#### Potential Risk Areas
- **USB Device Selection**: Could target wrong device if multiple USB drives connected
- **ISO Validation**: Limited verification of Windows ISO integrity  
- **Network Access**: VM testing may use network interfaces
- **Temporary Files**: May contain sensitive configuration data

### Mitigation Recommendations

For users:
1. **Verify USB devices** before running scripts
2. **Change default credentials** immediately after Windows installation
3. **Use on isolated systems** for testing
4. **Backup important data** before use
5. **Review autounattend.xml** for custom configurations

For administrators:
1. **Audit script execution** in enterprise environments
2. **Monitor boot configuration changes**
3. **Validate Windows ISO sources**
4. **Implement post-installation hardening**

### Security Updates

Security updates will be:
- Released as quickly as possible after verification
- Announced in repository releases
- Documented in CHANGELOG.md
- Communicated to known users when possible

### Responsible Disclosure

We follow responsible disclosure principles:

- **Coordinated**: Work together to understand and fix issues
- **Transparent**: Provide clear timelines and status updates  
- **Fair**: Credit researchers appropriately
- **Educational**: Share lessons learned (when appropriate)

### Bug Bounty

Currently, this is an open-source project without a formal bug bounty program. However:

- Security researchers will be credited in releases
- Significant findings may be recognized in project documentation
- We appreciate responsible disclosure and professional communication

### Legal Protection

Researchers acting in good faith will not face legal action from vixnz for:

- Security research on their own systems
- Responsible disclosure of vulnerabilities
- Reasonable testing activities

However:
- **Do not test on systems you don't own**
- **Do not access or modify others' data**
- **Follow all applicable laws**

### Questions?

For non-security questions about the security policy:
- Open a public GitHub issue
- Tag it with "security-question"
- Ask general questions about security practices

---

**Windows Auto-Install System Security Policy**  
Copyright (c) 2025 vixnz. All rights reserved.