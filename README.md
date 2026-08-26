# How to build a complete pi-gen image

## Requirements

- A build machine with **at least a Raspberry Pi 4 (8GB) worth of resources** — i.e. 8GB+ free RAM available for the build. Native and Docker builds are both RAM/IO heavy; low-memory hosts will fail or swap heavily.
- A Debian Bullseye/Buster-based Linux host, or Docker on any OS with `binfmt-support` installed.
- A pre-configured build machine reachable over the ilucharge2 VPN at **`pi-compiler.local`**, login user **`futech`**. You can SSH there directly instead of setting up your own build environment:

  ```bash
  ssh futech@pi-compiler.local
  ```
- access to https://drive.google.com/drive/folders/1WKPfpat9R893bzxAaSAZcOHl4fw_tCNm?usp=drive_link for all certificates and vpn clients... 

## Known quirk

> ⚠️ Always start a build from a freshly rebooted machine. Running `sudo ./cronjob.sh` (or `build.sh`) only reliably works right after a reboot — on a machine that has already run a build, certain temp files/mounts from the previous run don't seem to get cleaned up properly and can cause the next build to fail. Reboot the build host before kicking off a new build.

## 1. Clone the repository

```bash
git clone https://github.com/RdFutech/ilucharge2_image_builder.git
cd ilucharge2_image_builder
```

## 2. EVerest source structure dependency

The `stage2/09-install-everest` step does not pull EVerest sources directly — it relies on **[everest-deploy-devkit](https://github.com/RdFutech/everest-deploy-devkit/tree/main/futech)**, which defines *which* repositories/tags/revisions make up an EVerest release for this product.

The relevant file is `futech/basecamp-complete.yaml`, e.g.:

```yaml
everest-core:
  git: git@github.com:RdFutech/EVerest.git
  git_tag: ilucharge2
basecamp:
  git: git@github.com:RdFutech/everest-basecamp.git
  git_rev: 836d7abdaf2f1fc25b68f796e2c42d2a5c927df3
everest-cmake:
  git: git@github.com:RdFutech/everest-cmake.git
  git_rev: 329f8dbf67b4aa6cd480538e8715d602e3506e9d
everest-utils:
  git: git@github.com:RdFutech/everest-utils.git
  git_tag: v0.1.4
everest-futech:
  git: git@github.com:RdFutech/everest-futech.git
  git_tag: main
everest-framework:
  git: git@github.com:RdFutech/everest-framework.git
  git_tag: v0.6.2
```

Each entry pins a repo to either a `git_tag` or a fixed `git_rev`. To build against different EVerest sources/branches/forks, edit this YAML in `everest-deploy-devkit` (or point to a different devkit repo/branch) before starting the pi-gen build — this is what the `UPDATE_EVEREST_CHANNEL` config variable in pi-gen ultimately resolves against.

## 3. Configure the build

Edit the `config` file in the repo root. Key variables:

| Variable | Purpose |
|---|---|
| `IMG_NAME` | Base name of the output image (required) |
| `STAGE_LIST` | Which stages to build, e.g. `'stage0 stage1 stage2'` |
| `TARGET_HOSTNAME` | Hostname baked into the image |
| `FIRST_USER_NAME` / `FIRST_USER_PASS` | Default login account |
| `ENABLE_SSH` | `1` to enable SSH |
| `WPA_ESSID` / `WPA_PASSWORD` / `WPA_COUNTRY` | Pre-configure WiFi |
| `TIMEZONE_DEFAULT` | e.g. `Europe/Brussels` |
| `DEPLOY_COMPRESSION` | `gz`, `zip`, `xz`, or `none` |
| `HW_ID` | Hardware ID used for update targeting |
| `UPDATE_CHANNEL` | RAUC update channel — always set to `"unstable"` for new builds. New images must first be validated on a select number of devices before ever being promoted to `testing`/`stable`/`basecamp`. |
| `UPDATE_EVEREST_CHANNEL` | Which EVerest package channel/devkit structure to install |

## 4. Build and upload the image

Reboot the build machine first (see quirk above). Then just run the cronjob script — it builds **and** uploads the result to the FTP server in one step:

```bash
sudo ./cronjob.sh
```

This wraps `build.sh` and then calls `upload_futech.sh deploy/*.pnx`, which uploads to `pt.futech.be` under:

```text
/subdomains/pt/httpdocs/firmware/ilucharge2/<HW_ID>/<UPDATE_CHANNEL>/
```

e.g. for `HW_ID=futechr1` and `UPDATE_CHANNEL=unstable`:

```text
/subdomains/pt/httpdocs/firmware/ilucharge2/futechr1/unstable/
```

This uploads the `.pnx`, `.meta`, and updates `current.meta`/`current.img.gz` in that channel folder.

> **Important:** After upload, open the uploaded `current.meta` on the FTP server and make sure the `download_uri` path segment matches the channel folder you uploaded to (e.g. `unstable`, not `basecamp`). Example for the `unstable` channel:
>
> ```json
> {
>   "update": {
>     "hwid": "futechr1",
>     "version": 1786107729,
>     "description": "v1.0.0",
>     "download_uri": "http://pt.futech.be/firmware/ilucharge2/futechr1/unstable/1786107729-2026-08-07-ilucharge2_OS_CM4.pnx"
>   }
> }
> ```

## 5. Point devices at the new channel

By default a device checks `basecamp`. To have a specific device pull from another channel (e.g. `unstable`) for testing, on that device create/edit:

```bash
/mnt/user_data/etc/update_channel
```

with the channel name as its only contents, e.g.:

```text
unstable
```

## 6. Verify what a device is currently running

On the device, check the currently active update metadata:

```bash
cat /etc/update.meta
```

Example output for `basecamp`:

```json
{
  "update": {
    "hwid": "futechr1",
    "version": 1786107729,
    "description": "v1.0.0",
    "download_uri": "http://pt.futech.be/firmware/ilucharge2/futechr1/basecamp/1786107729-2026-08-07-ilucharge2_OS_CM4.pnx"
  }
}
```

The `download_uri` shows which channel it last updated from.

## 7. (Optional) Inspect/mount a built image

```bash
sudo ./imagetool.sh --mount --image-name deploy/<name>.img --mount-point /mnt/pi
sudo ./imagetool.sh --umount --mount-point /mnt/pi
```

---

**Summary of the release workflow:**

1. Reboot `pi-compiler.local`.
2. Edit `config` → set `UPDATE_CHANNEL="unstable"`, pick your EVerest channel via `UPDATE_EVEREST_CHANNEL`.
3. Run `sudo ./cronjob.sh` — this builds and uploads to FTP under `<HW_ID>/unstable/`.
4. On the device, create `/mnt/user_data/etc/update_channel` with contents `unstable`.
5. Reboot or trigger an update on the device; it will pull from `http://pt.futech.be/firmware/ilucharge2/futechr1/unstable/...` and install via RAUC.
