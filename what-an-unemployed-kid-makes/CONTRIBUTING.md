# Contributing to Windows Auto-Install System

**Important Notice: This is proprietary software owned by vixnz.**

## Copyright and Ownership

This project is proprietary software created and owned by **vixnz**. All code, documentation, and related materials are protected under copyright law and the project's custom license.

## Contribution Policy

### Before Contributing

1. **Contact First**: Always open an issue to discuss your proposed changes before starting any work
2. **Permission Required**: All contributions require explicit permission from vixnz
3. **Rights Transfer**: By contributing, you agree to transfer all rights to your contribution to vixnz
4. **No Redistribution**: Contributors may not redistribute or create derivative works

### What We Accept

- 🐛 **Bug Reports**: Detailed reports with reproduction steps
- 💡 **Feature Suggestions**: Well-thought-out enhancement proposals  
- 🔧 **Bug Fixes**: Solutions to existing issues (with permission)
- 📚 **Documentation**: Improvements to README, comments, or guides
- 🧪 **Testing**: Reports on different hardware/software configurations

### What We Don't Accept

- ❌ Unsolicited major rewrites or refactoring
- ❌ Changes to licensing or ownership
- ❌ Competing implementations or forks
- ❌ Commercial modifications

## How to Contribute

### 1. Report Issues

When reporting bugs, please include:

```
**System Information:**
- Linux Distribution: 
- Kernel Version: 
- Hardware: 
- UEFI/BIOS: 

**Windows ISO:**
- Version: 
- Edition: 
- Source: 

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**


**Actual Behavior:**


**Error Messages:**
```

### 2. Suggest Features

Feature requests should include:
- **Use Case**: Why is this feature needed?
- **Proposed Solution**: How should it work?
- **Alternatives**: Other ways to achieve the goal
- **Impact**: Who would benefit from this feature?

### 3. Code Contributions

**STOP: Do not submit code without prior permission!**

If you have permission to contribute code:

1. **Fork** the repository (with permission)
2. **Create** a feature branch: `git checkout -b feature-name`
3. **Follow** the coding standards below
4. **Test** thoroughly on multiple systems
5. **Document** your changes
6. **Submit** a pull request referencing the approved issue

## Coding Standards

### Shell Scripts

```bash
#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - [Component Name]

set -euo pipefail

# Use consistent function naming
function_name() {
    local param="$1"
    
    # Clear, descriptive variable names
    local meaningful_name="value"
    
    # Proper error handling
    if ! command_that_might_fail; then
        error "Descriptive error message"
        return 1
    fi
    
    return 0
}
```

### Documentation

- Use clear, concise language
- Include examples for complex procedures
- Update README.md for user-facing changes
- Add inline comments for complex logic

### Testing Requirements

All contributions must be tested on:

- ✅ Ubuntu/Debian (latest LTS)
- ✅ Arch Linux (current)
- ✅ Fedora (latest stable)
- ✅ UEFI and BIOS systems
- ✅ Multiple Windows versions (10, 11)

## Legal Requirements

### Contributor Agreement

By contributing to this project, you acknowledge and agree that:

1. **Ownership Transfer**: You transfer all rights, title, and interest in your contribution to vixnz
2. **Original Work**: Your contribution is your original work or you have permission to contribute it
3. **No Competing Use**: You will not use your contribution for competing projects
4. **License Compliance**: Your contribution complies with the project license

### Copyright Headers

All new files must include:

```bash
#!/bin/bash
# Copyright (c) 2025 vixnz. All rights reserved.
# Windows Auto-Install System - [File Description]
#
# This file is part of the Windows Auto-Install System.
# Unauthorized distribution is prohibited.
```

## Code Review Process

1. **Automated Checks**: All submissions undergo automated testing
2. **Manual Review**: vixnz reviews all code changes
3. **Testing Verification**: Contributors must provide test results
4. **Documentation Check**: Ensure all changes are properly documented
5. **Legal Review**: Verify compliance with project license

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file (if created)
- Git commit history
- Release notes for significant contributions

**Note**: Recognition does not imply ownership or rights to the codebase.

## Questions?

- 📧 **Contact**: Open an issue for questions
- 💬 **Discussion**: Use GitHub Discussions for general questions
- 🚨 **Security**: Report security issues privately through GitHub Security

## Final Notes

This project exists to provide value to the community while maintaining the creator's rights. By contributing, you help improve a tool that benefits users worldwide while respecting intellectual property rights.

Thank you for your interest in contributing to Windows Auto-Install System!

---

**Windows Auto-Install System** - Proprietary software by vixnz  
Copyright (c) 2025. All rights reserved.