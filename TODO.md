# TODO

Checklist for standing up ConsideraWeb.Ng.Template.

## 1. Create

- [ ] From the template: `node scripts/create.mjs ConsideraWeb.Ng.Some.Name --port 42xx` (pick a port no other app uses)


## 3. GitHub

- [ ] Publish via GitHub Desktop
- [ ] Secret `NODE_AUTH_TOKEN` (same PAT as local) under Settings > Secrets and variables > Actions
- [ ] Environment `Production`, restricted to `master`, with variables
  - [ ] `AWS_S3_ROLE_ARN` (the GitHub deploy role in account 4979)
  - [ ] `AWS_S3_REGION`
  - [ ] `AWS_S3_ARTIFACTS_BUCKET` (`prod-consideraweb-artifacts`)
- [ ] The deploy role's trust policy allows this repo (`repo:considera-core/*` already does)
- [ ] Commit and push `master`, then check the Publish run deploys and tags `v1.0.0`
- [ ] Open a test PR and check the prerelease is tagged, then deleted by Cleanup when it closes

## 4. Serve it

- [ ] `ConsideraWeb.Aws.CloudFormation/stacks/cdn.yaml`: add an `APPS` entry keyed by the URL segment, with
  `home: '/template/home'` and `folder: 'ConsideraWeb.Ng.Template/prod/latest/consideraweb-ng-template/browser'`
- [ ] Deploy that stack and open https://app.considera.dev/template/home
- [ ] Note the new bucket folder in `ConsideraWeb.Aws.CloudFormation/INVENTORY.md`

## 5. Build the app

- [ ] Replace the `home` route in `src/app/app.routes.ts` with real routes (keep one at `home`, the CDN redirects there)
- [ ] Fill in `app.component.html` / `.ts` / `.scss`, and `<title>` in `src/index.html` if the default is wrong
- [ ] Update `README.md` with what the app is for
