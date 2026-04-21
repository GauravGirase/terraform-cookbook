```bash
1. Run workload with minimal IAM
2. CloudTrail logs AccessDenied events
3. Parser extracts missing permissions
4. Terraform file updated
5. CI pipeline runs terraform apply
6. Role updated
7. Retry succeeds
```
