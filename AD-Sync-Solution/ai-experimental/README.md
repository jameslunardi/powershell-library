# AD-Sync-Solution

## Overview
This solution was designed to synchronise users between an Enterprise Domain used for End User Computing services and a Production domain used for securing access to production services that had much stricter security and audit and compliance requirements. It initially synchronised around 1,500 accounts but over the years this doubled to over 3,000. We utilised PowerShell and its Active Directory module to achieve this. The service was run via scheduled task every hour for over 5 years. With only very minor issues related to data consistency on the source domain.

### ai-experimental
This version of the code has had Claude and Claude Code updates. I asked it for critical feedback and suggestions of what should be done to improve it. I got these suggestions and gave Claude Code free reign to go off and implement them. It promises me that the code passes the tests it created. I'm not sure though. I found myself being more and more detached from the code and from my understanding of how it worked. I've left it here as a reminder of how not to code with AI. At some point I will test it in a test environment and see how well or not it's done. Use at your own risk. This did though represent some good lessons learned on how not to work with Claude Code and AI in general. It's very important to stay in control, understand the changes that will be made, and to make small changes a step at a time. Otherwise you can lose the understanding of the code very quickly.

---

**Part of my PowerShell Library:** Visit the [main repository](../README.md) to explore other solutions and tools.

## Disclaimer
Always validate and test scripts thoroughly in your own environment before taking them into production use. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.
