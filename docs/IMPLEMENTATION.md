# Implementation status

Execute the numbered prompts in order. Podman supersedes the original Docker-engine assumption.

| Stage | Status |
| --- | --- |
| 1 foundation | Implemented; validation in VALIDATION.md |
| 2 infrastructure | Implemented and tested on Podman ARM64 |
| 3 Ansible | Implemented; converges on community and licensed Enterprise Vault |
| 4 backend | Implemented; unit and real Vault denial/recovery checks pass |
| 5 frontend | Implemented; Chromium transition/safety/mobile checks pass |
| 6 Make/verification | Implemented; scoped lifecycle and fault-recovery run passes |
| 7 guides/retirement | Implemented; current guides linked and HCP source retired |
| 8 acceptance/portability | Implemented; clean-checkout acceptance passes, native platform limits recorded |

The configuration, endpoints, private files, and ownership contract is in
[ARCHITECTURE.md](ARCHITECTURE.md). `workshop/config.json` and `workshop/users.yml`
are canonical inputs. Runtime data belongs under ignored `.workshop/`.

| Acceptance | Implementation/check location |
| --- | --- |
| AC-01 | package lockfiles, Containerfiles, build/fresh-clone checks |
| AC-02/04/12 | infra/, scripts/lab.py, scoped lifecycle checks |
| AC-03 | doctor, SETUP.md, VALIDATION.md platform matrix |
| AC-05/06/08 | ansible/, persona and database permission verifier |
| AC-07/09/10 | backend/, frontend/, API tests and recovery verifier |
| AC-11 | runtime permissions, secret scan, public-file checks |
| AC-13/14 | participant/facilitator guides and legacy dependency audit |

## Delivered core

All eight prompt stages have been executed. The current workshop runs locally on
Podman with Terraform, Ansible and Make, ordered synthetic personas, a runnable
locked learner seam, and an explicit facilitator solution. Validation evidence and
remaining native-host/pilot work are in [VALIDATION.md](VALIDATION.md).
