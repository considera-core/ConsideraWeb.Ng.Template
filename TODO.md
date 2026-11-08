# TODO

Checklist for standing up ConsideraWeb.Ng.Template.

## 1. Create

- [ ] `Create-Ng ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 42xx` from the template folder
  (or anywhere, after `add-to-path.ps1`). Pick a port no other app uses.

## 2. Local

- [ ] Add application to ConsideraWeb.Proxy Caddyfile
- [ ] `npm run root-run` opens https://local.considera.dev/template/home with no console errors
- [ ] `npm run build` and `npm test` pass
- [ ] Replace `public/favicon.ico` if this app should have its own

## 3. GitHub

- [ ] Publish via GitHub Desktop
- [ ] Secret `NODE_AUTH_TOKEN` (same PAT as local) under Settings > Secrets and variables > Actions
- [ ] Environment `Production`, restricted to `master`, with variables `AWS_S3_ROLE_ARN` (the GitHub deploy role in
  account 4979), `AWS_S3_REGION` and `AWS_S3_ARTIFACTS_BUCKET` (`prod-consideraweb-artifacts`)
- [ ] Push `master` and check the Publish run deploys and tags `1.0.0`
- [ ] Open a test PR and check its prerelease tag is deleted by Cleanup when the PR closes

## 4. Serve it

- [ ] `ConsideraWeb.Aws.CloudFormation/stacks/cdn.yaml`: add an `APPS` entry keyed by the URL segment, with
  `home: '/template/home'` and `folder: 'ConsideraWeb.Ng.Template/prod/latest/consideraweb-ng-template/browser'`
- [ ] Deploy that stack, open https://app.considera.dev/template/home, and note the new bucket folder in
  `ConsideraWeb.Aws.CloudFormation/INVENTORY.md`

## 5. Build the app

- [ ] Replace the `home` route in `src/app/app.routes.ts` with real routes (keep one at `home`, the CDN redirects there)
- [ ] Fill in `app.component.html` / `.ts` / `.scss`
- [ ] Update `README.md` with what the app is for

Later template changes can be pulled in with `Sync-Ng ConsideraWeb.Ng.Template` (and pushed back with `-Reverse`).
