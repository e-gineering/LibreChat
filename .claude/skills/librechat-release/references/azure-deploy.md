# Azure deployment

The deploy is done in the Azure Portal — Claude can't operate it. Hand these steps to the user once the
image build is green. The pattern is: deploy the new tag to the **staging** slot, test it, then **swap**
staging into production.

## Steps

1. Open the **app-img-librechat-02** resource in the Azure Portal.
2. Go to **Deployment → Deployment slots** and choose **app-img-librechat-02-staging**.
3. If any environment variables need to change for this release, change them here on the staging slot
   first. **Note exactly what you change** — you'll re-apply the same changes to production after the swap.
4. Open **Deployment Center**, enter the new tag (e.g. `v0.8.6.EG1`) in the **Image and tag** field,
   and click **Save**.
5. Wait for the deployment to finish (watch the **Logs** tab). Then test staging at:
   `app-img-librechat-02-staging-fxfphsbqbpdjcvhw.eastus2-01.azurewebsites.net`
6. When staging looks good, click **Swap**, then **Start Swap** to promote it to production.
7. Confirm the change in production. Then re-apply to the production slot any env-var changes you made
   to staging in step 3 (the swap moves the slot, not necessarily those settings).

## Notes

- Deployment is by **explicit tag**, so the image's `:latest` tag is irrelevant to Azure — that's why
  the fork's build workflow pushing `:latest` is harmless even for `.EGN` tags.
- Long-term backlog (see `project_mount_config` memory): mounting `librechat.yaml` via Azure Files would
  let config-only changes skip the ~2-hour image rebuild entirely.
