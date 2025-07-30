# E-gineering Librechat changes

Keeping track of custom features added to `e-gineering/LibreChat`.

- Google key contents
  - (Optional) Environment variable: `GOOGLE_KEY_FILE_CONTENTS`
  - The contents of the Google key JSON file, that will then be written to the file specified by `GOOGLE_KEY_JSON_FILENAME`.

- Google key location
  - (Optional) Environment variable: `GOOGLE_KEY_JSON_FILENAME`
    - Optional overall, but required currently if `GOOGLE_KEY_FILE_CONTENTS` is set.
  - The path to where the Google key JSON file is mounted to inside the container, instead of the hardcoded path `~/data/auth.json`.

- Custom favicon url path
  - (Optional) Environment variable: `FAVICON_PATH`
  - A URL to a path containing 5 image files that will be downloaded at runtime, to overwrite the 5 locations where the favicon is used in the Docker container:
    - `$FAVICON_PATH/favicon-16x16.png` ➜ `/app/client/dist/assets/favicon-16x16.png`
    - `$FAVICON_PATH/favicon-32x32.png` ➜ `/app/client/dist/assets/favicon-32x32.png`
    - `$FAVICON_PATH/apple-touch-icon-180x180.png` ➜ `/app/client/dist/assets/apple-touch-icon-180x180.png`
    - `$FAVICON_PATH/icon-192x192.png` ➜ `/app/client/dist/assets/icon-192x192.png`
    - `$FAVICON_PATH/maskable-icon.png` ➜ `/app/client/dist/assets/maskable-icon.png`
  - These images are defined in the `vite.config.ts` file.

- Custom `librechat.yaml`
  - Certain config changes are only possible by editing the `librechat.yaml` file.
  - To add changes for a specific implementation, create an environment variable called `LIBRECHAT_CUSTOM_CONFIG` and create a file called `librechat.{LIBRECHAT_CUSTOM_CONFIG}.yaml`, replacing the placeholder with the value of the environment variable.
  - Add an exception to `.dockerignore` after the `librechat*` entry, like this: `!librechat.{LIBRECHAT_CUSTOM_CONFIG}.yaml`.
  - The `librechat.example.yaml` file has an example implementation. Further documentation is here: https://www.librechat.ai/docs/configuration/librechat_yaml