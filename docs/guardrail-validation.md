# Guardrail Validation

All tests were run from the **Workloads account** (`477013660563`) using the
`OrganizationAccountAccessRole`, because SCPs never apply to the management
account. Identity was confirmed before every run with `aws sts get-caller-identity`.

![Caller identity in Workloads](screenshots/validation-identity.png)

## Results

| # | Guardrail (SCP) | Attempted action | Result |
|---|---|---|---|
| 1 | Protect CloudTrail and Config | Stop the organization CloudTrail | Denied (see note below) |
| 2 | Protect CloudTrail and Config | Stop the AWS Config recorder in Workloads | TODO: paste result |
| 3 | Deny public S3 | Disable Block Public Access on a bucket | TODO: paste result |
| 4 | Deny public S3 | Set a bucket ACL to public-read | TODO: paste result |
| 5 | Restrict regions | List VPCs in ap-southeast-1 | TODO: paste result |
| 6 | Require encryption | Create an unencrypted EBS volume | TODO: paste result |
| 7 | Deny leaving the organization | Run `organizations leave-organization` | TODO: paste result |
| 8 | Require encryption | Create an unencrypted RDS instance | Denied during the initial Flowdesk deploy (`explicit deny in a service control policy`), then fixed in code with `storage_encrypted = true` |

## Notes on the CloudTrail test

An organization trail cannot be stopped from a member account at all, because
the trail is owned by the management account. That is why test 1 returns an
access error rather than an SCP-specific message. The SCP also denies the same
actions on any trail local to the account, and test 2 demonstrates the SCP
directly using the Config recorder that exists inside Workloads.

## Not tested

**SCP 1 (deny root user)** is codified and attached to the Workloads OU but was
not tested, because it requires signing in as the root user of the Workloads
account.

## Lesson learned

My first test run executed from the management account, where SCPs do not
apply, so the actions succeeded and the organization trail was briefly stopped
(about 3 minutes of logging gap). It was restarted immediately. The tests were
then re-run from the Workloads account with a named profile and the account
verified first.
