# DEBUG TIPS

## Backend
Open the logs:

```
docker logs agentic-backend
```

After fixing the issue, shut down everything, rebuild and launch

```
make dev-down
docker compose build backend
make dev-up
```