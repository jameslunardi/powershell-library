# Active Directory User Synchronisation - Rewrite Project

## Current Service Summary

The existing PowerShell-based solution synchronises user accounts between an Enterprise Domain and a Production domain with stricter security requirements. Originally designed as a temporary solution in 2019, it successfully operated for 5 years, scaling from around 1,500 to over 3,000 synchronised accounts.

**Current Architecture:**
- 5 PowerShell files with operation-based separation (Add, Remove, Update, General functions, Main orchestrator)
- Hourly execution via scheduled task
- Built-in safety thresholds and comprehensive logging
- Cross-domain service account with encrypted credentials
- Unix/Linux integration with automatic UID/GID assignment

The solution proved reliable in production with minimal issues, primarily related to source domain data consistency.

## Rewrite Project Summary

This rewrite aims to modernise and improve the maintainability of the existing solution while preserving its proven functionality. The focus is on industry-standard practices, better code organisation, and enhanced reliability through proper testing and error handling.

**Learning & Development Focus:** This project serves as a professional development opportunity to explore modern development practices, including leveraging AI assistance for code development and establishing expertise in Pester testing frameworks. The rewrite provides a practical environment for developing skills in AI-assisted programming workflows.

The rewrite will maintain the successful hourly batch processing approach and core business logic whilst addressing architectural limitations and technical debt accumulated over 5 years of production use.

## Rewrite Objectives

### 1. Configuration Management
- **JSON configuration file** with basic settings (domains, thresholds, paths)
- Externalise hardcoded values (GID numbers, Unix paths, etc.)
- Centralised configuration loading and validation

### 2. Code Organisation
- **Reorganised file structure**: 
  - `ADSync-Core.ps1` - Main orchestration and comparison logic
  - `ADSync-UserOperations.ps1` - Add/Remove/Update functions
  - `ADSync-Utilities.ps1` - Export, email, logging, configuration functions
  - `ADSync-Config.json` - Configuration file
  - `Start-ADSync.ps1` - Simple entry point
- Reduce code duplication between similar operations
- Clear separation of concerns

### 3. Documentation & Maintainability
- **Comment-based help** for all functions (Synopsis, Description, Parameters, Examples)
- **Strategic inline comments** explaining business logic and decisions
- Professional PowerShell documentation standards

### 4. Error Handling & Reliability
- **Unified error handling** strategy across all functions
- Consistent exception handling and recovery approaches
- Improved error reporting and diagnostics

### 5. Logging & Monitoring
- **Structured logging** framework replacing mixed logging approaches
- Consistent, searchable log format
- Better operational visibility

### 6. Testing Framework
- **Pester unit testing** implementation
- Test coverage for core business logic
- Mock AD operations for safe testing
- Regression testing capability

### 7. Code Quality Improvements
- **Separate password generation** function for better testability
- **Input validation** enhancements
- Remove embedded business logic from operational functions

## Success Criteria

- Maintain 100% functional compatibility with existing solution
- Improve code maintainability and readability
- Establish testing framework for future changes
- Create foundation for potential future enhancements
- Preserve proven reliability and performance characteristics

## Development Approach

This rewrite will be developed incrementally, with each component thoroughly tested before integration. A dedicated test lab environment will be established to safely develop and validate the solution without impacting production systems.

**Test Environment:** The development process will utilise a controlled lab setup with test Active Directory domains, allowing for comprehensive testing of all synchronisation scenarios, error conditions, and edge cases before any production deployment.

The existing solution will continue operating in production until the rewrite is fully validated and ready for deployment.

---

**Part of my PowerShell Library:** Visit the [main repository](../../README.md) to explore other solutions and tools.

## Disclaimer
Always validate and test scripts thoroughly in your own environment before taking them into production use. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.
