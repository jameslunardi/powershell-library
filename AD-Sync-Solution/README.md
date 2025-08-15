# AD-Sync-Solution

## Overview
This solution was designed to synchronise users between an Enterprise Domain used for End User Computing services and a Production domain used for securing access to production services that had much stricter security and audit and compliance requirements. It initially synchronised around 1,500 accounts but over the years this doubled to around 3,000. We utilised PowerShell and its Active Directory module to achieve this. The service was run via scheduled task every hour for over 5 years. With only very minor issues related to data consistency on the source domain.  

I've split the code here into three folders.

### [original-sanitised](./original-sanitised)
This is the original code I wrote back in 2019. The code was meant to be a temporary solution while an IAM service was implemented. The temporary solution was finally replaced by IAM in 2024, 5 years later. While I created the framework and the majority of the code, other colleagues have contributed to small fixes and improvements over the years. This code represents what was the final state. I have utilised AI to sanitise the code and improve the documentation of it, but the heart of the code is unchanged. 

### [ai-experimental](./ai-experimental) 
This is where I let Claude and Claude Code loose on the code. I asked it for critical feedback and suggestions of what should be done to improve it. I got these suggestions and feedback and gave Claude Code free reign to go off and implement them. It promises me that the code passes the tests it created. I'm not sure though. I found myself being more and more detached from the code and from my understanding of how it worked. I've left it here as a reminder of how not to code with AI. At some point I will test it in a test environment and see how well or not it's done. Use at your own risk. This did though represent some good lessons learned on how not to work with Claude Code and AI in general. It's very important to stay in control, understand the changes that will be made, and to make small changes a step at a time. Otherwise you can lose the understanding of the code very quickly.

### [controlled-rewrite](./controlled-rewrite)
So nothing here at the moment but the plan is to take the learnings from my AI experiment and rewrite my original code into something more polished and modern. Hopefully I can work in combination with the AI to truly understand the process and produce something I understand and has real value. 

---

**Part of my PowerShell Library:** Visit the [main repository](../README.md) to explore other solutions and tools.

## Disclaimer
Always validate and test scripts thoroughly in your own environment before taking them into production use. The author assumes no responsibility for any data loss, security issues, or operational problems resulting from the use of this code.
