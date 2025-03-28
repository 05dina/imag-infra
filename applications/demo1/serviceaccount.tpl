---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: demo1
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${account_id}:role/${role_name}
...
