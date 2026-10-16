# Flowdesk Landing Zone

A governed multi-account AWS foundation for Flowdesk, built entirely with Terraform. The original single-account Flowdesk stack was refactored into a reusable module and deployed into a dedicated Workloads account, inside an AWS Organization with codified guardrails (Service Control Policies), organization-wide CloudTrail, AWS Config in every account, and a least-privilege deployment role.

**Stack:** AWS Organizations, SCPs, CloudTrail, AWS Config, IAM, S3, Terraform (S3 remote state with native locking), GitHub (PR-only changes to `main`).

## The problem

Flowdesk was built and proven in a single AWS account with a personal admin identity: no account boundary between environments, no organization-wide guardrails, and no audit trail that survives a compromised account. That works for a demo and becomes a liability at scale.

## The solution

A 5-account AWS Organization where the account boundary is the blast-radius boundary, guardrails are code, and logs are written somewhere the workload account cannot erase.


## Architecture

```mermaid
flowchart TB
    MGMT["Management Account<br/>Organizations, SCPs, Terraform State"]
    SEC["Security Account<br/>Security OU"]
    LOG["Log Archive Account<br/>Centralized S3 Logs"]
    SHARED["Shared Services Account<br/>Infrastructure OU"]
    WORK["Workloads Account<br/>FlowDesk Application"]

    MGMT -->|"Organization CloudTrail"| LOG
    MGMT -->|"Assumes deployment role"| WORK
    SEC -->|"AWS Config delivery"| LOG
    SHARED -->|"AWS Config delivery"| LOG
    WORK -->|"AWS Config delivery"| LOG
```
  

## Technologies Used

- **Cloud Platform:** Amazon Web Services (AWS)
- **Infrastructure as Code:** Terraform
- **Organization & Governance:** AWS Organizations, Service Control Policies (SCPs)
- **Security & Identity:** AWS IAM, least-privilege access, cross-account IAM roles
- **Audit & Compliance:** AWS CloudTrail, AWS Config
- **Storage & Logging:** Amazon S3, centralized log archive
- **Validation:** Terraform validation and AWS configuration testing

## Key Capabilities

- Five-account AWS Organization with separated responsibilities
- Six Service Control Policies for organizational guardrails
- Centralized, organization-wide CloudTrail logging
- AWS Config for resource configuration visibility
- Least-privilege cross-account deployment role
- Terraform-based infrastructure deployment and management

## Project Status

The landing-zone configuration and workload deployment were implemented and tested in AWS. The workload stack was subsequently destroyed to control ongoing costs. The repository retains the implementation and documentation, with screenshots and validation evidence used to demonstrate the project.

| Account | OU | Purpose |
|---|---|---|
| Management | Root | Organizations, SCPs, organization CloudTrail, Terraform state bucket. No workloads. |
| Security | Security | Reserved for security tooling. Currently holds only its AWS Config recorder. |
| Log Archive | Security | Central, deletion-protected S3 bucket for CloudTrail and Config logs. |
| Shared Services | Infrastructure | Reserved for shared tooling. Currently holds only its AWS Config recorder. |
| Workloads | Workloads | Flowdesk: VPC, ALB, Auto Scaling Group, RDS, S3 static site, CloudWatch. |

The reasoning, including the alternatives rejected (single account, account-per-environment, AWS Control Tower), is in [ADR 0001](docs/adr/0001-account-structure.md).

## Guardrails (Service Control Policies)

Six SCPs, defined in `organization/scps.tf` and attached to the Workloads OU:

| SCP | What it prevents |
|---|---|
| `flowdesk-deny-root-user` | Any action by the root user of a member account |
| `flowdesk-restrict-regions` | Activity outside eu-west-1, eu-central-1 and us-east-1 (global services exempt) |
| `flowdesk-protect-logging` | Stopping, deleting or modifying CloudTrail and AWS Config |
| `flowdesk-deny-leave-org` | Leaving the organization |
| `flowdesk-require-encryption` | Creating unencrypted RDS instances and EBS volumes, or uploading S3 objects with an invalid encryption header |
| `flowdesk-deny-public-s3` | Changing S3 Block Public Access settings, bucket policies or bucket ACLs |

SCPs never apply to the management account, so all validation was run from the Workloads account.

## Centralized logging

- One organization-wide, multi-region CloudTrail with log file validation, delivering to the Log Archive account.
- The log bucket policy denies `DeleteObject`, `DeleteObjectVersion`, `DeleteBucket` and `DeleteBucketPolicy` to everyone, enforces TLS, and blocks public access.
- An AWS Config recorder and delivery channel in all five accounts, writing to the same bucket.

## Flowdesk, refactored

The original Terraform (six modules: network, security, storage, compute, database, monitoring) now lives in `modules/flowdesk/` as a reusable module with no provider block of its own. It is deployed from `workloads/flowdesk-prod/`, whose provider assumes a role in the Workloads account instead of using a personal admin identity.

Deploying it into the governed account exposed code that the guardrails correctly rejected or that needed changing:

| Finding | Fix |
|---|---|
| RDS created without `storage_encrypted` was denied by the encryption SCP | Added `storage_encrypted = true` |
| Explicit S3 Block Public Access resource conflicts with the public-S3 SCP | Removed it. New buckets have Block Public Access on by default and the SCP prevents anyone turning it off |
| Launch template had no encrypted root volume | Added an encrypted gp3 root volume (30 GB, the minimum for the AL2023 image) and required IMDSv2 |
| Hardcoded EC2 key pair | Made optional. Instances are in private subnets with no SSH |
| Windows line endings corrupted the user data script | Strip carriage returns in Terraform before encoding |

## Least-privilege deployer role

Flowdesk is deployed through `flowdesk-terraform-deployer` in the Workloads account, not through `OrganizationAccountAccessRole` (effectively administrator). Defined in `iam/main.tf`:

- Trust is limited to the management-account Terraform user.
- EC2, ELB, Auto Scaling, RDS, CloudWatch and S3 are allowed in eu-west-1 only.
- IAM is limited to `flowdesk-*` roles and instance profiles, and the only managed policy it can attach is `AmazonS3ReadOnlyAccess`. `PassRole` is limited to EC2.
- KMS is usable only through RDS and EC2.
- An explicit deny blocks creating IAM users or access keys, and using Organizations, CloudTrail and Config.
- An explicit deny stops the role editing itself, which prevents privilege escalation.

The full Flowdesk stack (35 resources) was created and destroyed through this role.

## Validation

Guardrails were tested by attempting the forbidden actions from the Workloads account. Results and notes, including a mistake I made by testing from the wrong account first, are in [docs/guardrail-validation.md](docs/guardrail-validation.md).


## Repository Structure

```text
bootstrap/          Terraform state bucket setup
organization/       AWS Organization, OUs, accounts, SCPs
logging/            Log Archive bucket and organization CloudTrail
config/             AWS Config recorders
iam/                Least-privilege deployment role
modules/
  config-recorder/  Reusable Config recorder module
  flowdesk/         Reusable application infrastructure module
workloads/
  flowdesk-prod/    Workload deployment configuration
docs/
  ADRs, runbooks, validation results and screenshots
```

All changes to `main` go through pull requests (enforced by a GitHub ruleset).

## Cost

Organizations, SCPs and IAM are free. The first copy of management events in CloudTrail is free. The Flowdesk stack (ALB, two small instances, one small RDS instance, no NAT Gateway) cost roughly $0.15 per hour and was destroyed after testing. The organization, logging, config and iam stacks were left in place.

## Known limitations and next steps

- The deployer role is scoped by service, not by individual action (for example `ec2:*` limited to eu-west-1). Tightening it to an action-by-action list, for instance from CloudTrail data, is the next step. The role itself was created through `OrganizationAccountAccessRole`, which remains available for break-glass use.
- SCPs are attached to the Workloads OU only. Extending them to the Security and Infrastructure OUs is planned.
- The deny-root SCP is codified and attached but not tested, because testing requires signing in as the member account's root user.
- The Security and Shared Services accounts are provisioned but empty. A Config aggregator and security tooling would live in Security.
- The Terraform state bucket lives in the management account. A production setup would move it to a dedicated account.
- Dev, staging and prod are not yet separate accounts. The Workloads OU is designed to hold them.

## Runbook

How to onboard a new workload account: [docs/runbook-onboard-workload-account.md](docs/runbook-onboard-workload-account.md).

<img width="1361" height="761" alt="Screenshot 2026-10-10 180559" src="https://github.com/user-attachments/assets/30f8050c-8238-4d20-9a5b-3b9cf692931b" />
<img width="1361" height="760" alt="Screenshot 2026-10-10 183427" src="https://github.com/user-attachments/assets/a8d104be-92fe-43f3-b52d-2f0ae5eeb09f" />
<img width="1360" height="760" alt="Screenshot 2026-10-10 183903" src="https://github.com/user-attachments/assets/b49c1204-5055-4ed6-bb26-39e8eb7e05ba" />
<img width="1365" height="767" alt="Screenshot 2026-10-10 184502" src="https://github.com/user-attachments/assets/e23d7d64-b0e8-43a2-a387-8fce6816e8f3" />

<img width="1364" height="767" alt="Screenshot 2026-10-10 190231" src="https://github.com/user-attachments/assets/4523ac4f-a9cb-4619-9be5-c69be560176c" />
<img width="1365" height="767" alt="Screenshot 2026-10-10 191027" src="https://github.com/user-attachments/assets/43e3d3d8-f22d-4ef8-ba85-c8dc75682ddd" />

<img width="1365" height="766" alt="Screenshot 2026-10-10 192255" src="https://github.com/user-attachments/assets/4dc398f5-cbdb-4b99-8cbf-6d48b6dd5f22" /> <img width="1365" height="767" alt="Screenshot 2026-10-10 202013" src="https://github.com/user-attachments/assets/552f25ed-36f3-4b18-b00d-67f02a6196f4" />
<img width="1362" height="763" alt="Screenshot 2026-10-10 202135" src="https://github.com/user-attachments/assets/96ff1492-9ace-4ab1-b740-f20879e4a4ee" />
<img width="1365" height="767" alt="Screenshot 2026-10-10 202306" src="https://github.com/user-attachments/assets/4d653d08-cad5-4bdf-866b-50af22dc2e6a" />
<img width="1365" height="766" alt="Screenshot 2026-10-10 202643" src="https://github.com/user-attachments/assets/d58df565-e63c-4c19-9f1d-9b008df11e40" />
<img width="1365" height="764" alt="Screenshot 2026-10-10 202739" src="https://github.com/user-attachments/assets/2a26cade-9c9a-4f6a-955c-ab7999b5ee5d" />
<img width="1362" height="754" alt="Screenshot 2026-10-10 202949" src="https://github.com/user-attachments/assets/773fd986-2521-4154-b829-7016a255b2d6" />
<img width="1364" height="764" alt="Screenshot 2026-10-10 203001" src="https://github.com/user-attachments/assets/44e0fa0a-276e-4793-9f02-51602864473e" /><img width="1365" height="767" alt="Screenshot 2026-10-10 203010" src="https://github.com/user-attachments/assets/e98815e9-51dd-48e5-b963-421c935aaea0" />

<img width="1365" height="766" alt="Screenshot 2026-10-10 203019" src="https://github.com/user-attachments/assets/ec5a53c1-4ca6-4ef5-9571-6f0339dbc7ea" />
<img width="680" height="767" alt="Screenshot 2026-10-10 203854" src="https://github.com/user-attachments/assets/916732d7-f796-4db9-a115-a3a6f33bfd65" />

<img width="678" height="766" alt="Screenshot 2026-10-10 203914" src="https://github.com/user-attachments/assets/6f9fa92d-687d-41f6-b222-43c30dbb9229" />
<img width="680" height="767" alt="Screenshot 2026-10-10 203930" src="https://github.com/user-attachments/assets/e148190b-8d68-4746-9716-89ca021f0129" />
<img width="677" height="760" alt="Screenshot 2026-10-10 203945" src="https://github.com/user-attachments/assets/2b317165-9aa1-434c-9a33-8899d4325215" /><img width="678" height="767" alt="Screenshot 2026-10-10 204002" src="https://github.com/user-attachments/assets/e7831a46-89b0-4995-8fa4-dc8fc1f3a5cd" /><img width="1365" height="767" alt="Screenshot 2026-10-10 205250" src="https://github.com/user-attachments/assets/f0acef3c-2352-4f2d-9f8d-d7b271ae87df" />
<img width="1362" height="762" alt="Screenshot 2026-10-11 063017" src="https://github.com/user-attachments/assets/faf8b330-0647-4b50-8d94-1b67ccdccfcb" />
<img width="1365" height="767" alt="Screenshot 2026-10-11 063349" src="https://github.com/user-attachments/assets/4b182182-a4a8-4d37-93ee-9b55dc2f3d71" />
<img width="674" height="767" alt="Screenshot 2026-10-11 064201" src="https://github.com/user-attachments/assets/be912fa6-cfad-4f1a-8ffe-026238f76bfe" />
<img width="677" height="767" alt="Screenshot 2026-10-11 064815" src="https://github.com/user-attachments/assets/9e0ae701-5c47-47d4-85ee-4ec731c6f846" />
<img width="1365" height="734" alt="Screenshot 2026-10-11 065821" src="https://github.com/user-attachments/assets/8f32b31b-5718-4979-bd2a-ea1a549816e5" />
<img width="1365" height="767" alt="Screenshot 2026-10-11 065901" src="https://github.com/user-attachments/assets/f6df85fe-9aa9-409e-a154-7895fbfe3675" />
<img width="1354" height="767" alt="Screenshot 2026-10-11 075647" src="https://github.com/user-attachments/assets/21e372f3-f591-4a57-a628-744120d9482f" /><img width="1365" height="767" alt="Screenshot 2026-10-11 075659" src="https://github.com/user-attachments/assets/23058221-de39-4c89-b80e-aac767550376" />



