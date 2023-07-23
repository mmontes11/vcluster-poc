# vcluster-poc
vcluster + flux multi-tenancy  PoC

### Install

```bash
make cluster
export GITHUB_TOKEN=<your-personal-access-token>
make deploy
``` 

### Configure vcluster contexts

```bash
make vctx
```

### Uninstall

```bash
make vcluster-delete
make cluster-delete
```