# ADR 0001: Multi-Account Structure for Flowdesk

Status: Accepted   Date: 2026-10-10

## Context
Flowdesk runs in a single AWS account with a personal admin identity.
There is no boundary between environments, no org-wide guardrails, and
no audit trail that survives a compromised account.

## Decision
Adopt a 5-account AWS Organization:
- Management: billing, Organizations, SCPs only. No workloads.
- Security: security tooling and delegated admin (Config aggregator).
- Log Archive: immutable, centralized CloudTrail/Config logs.
- Shared Services: shared tooling (e.g. artifacts, DNS).
- Workloads (Flowdesk): VPC/ALB/ASG/RDS.

OUs: Security (Security, LogArchive), Infrastructure (SharedServices),
Workloads (Flowdesk).

## Alternatives rejected
1. Single account with tagging/IAM boundaries: no hard blast-radius limit.
2. Account per environment from day one (dev/stg/prod): correct end state,
   but too costly/complex for current scale; Workloads OU is built to
   accommodate it later.
3. AWS Control Tower: faster, but hides decisions in managed blueprints.
   Rejected here to demonstrate and fully codify each guardrail in Terraform.

## Consequences
+ Account boundary = blast-radius boundary
+ Guardrails are version-controlled and PR-reviewed
- More accounts to operate; cross-account roles add complexity
