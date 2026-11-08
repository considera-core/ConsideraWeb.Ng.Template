# Troubleshooting

## 1. Dev versions of ConsideraWeb.Extensions won't update even with new tags

Make sure you don't have a `^` prefix in your package.json:
```json
{
    "@considera-core/angular-extensions": "1.0.14-0.ZC-CORE-153",
}
```

Production versions should include a prefix (`^` or `~`):
```json
{
    "@considera-core/angular-extensions": "^1.0.14",
}
```