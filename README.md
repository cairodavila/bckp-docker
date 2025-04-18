[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Citation](https://img.shields.io/badge/Cite%20Us-CITATION.cff-lightgrey.svg)](CITATION.cff)

# bckp-docker

a drop‑in CLI to back up all Docker‑Compose volumes to any S3‑compatible remote  
(e.g. MinIO, AWS S3, DigitalOcean Spaces) via rclone.

## features

- discovers `docker-compose.yml` and its volumes automatically  
- brings your stack **down**, runs an rclone container to sync volumes, then **up**  
- optional bucket versioning via `rclone backend versioning`  
- optional bucket ACL via `rclone s3api` (if supported)  
- choose between size‑only, checksum, modtime or update logic  
- fast‑list, no‑traverse, skip HEAD after PUT, multipart tuning  
- colorful, timestamped logs & per‑volume error handling  
- debug mode to trace the helper’s shell steps  

## prerequisites

- Docker & Docker Compose (v2)  
- `rclone` configured with an S3 remote
- Linux or WSL2 (macOS should work too)  
- shell: bash/zsh/sh  

## installation

```bash
# copy or clone these files into ~/.local/bin (or similar in your PATH)
chmod +x ~/.local/bin/bckp-docker
chmod +x ~/.local/bin/backup-container.sh

# copy example env and edit
cp ~/.local/bin/.env.example ~/.local/bin/.env
# open ~/.local/bin/.env and update REMOTE, MAIN_BUCKET, etc.

# ensure ~/.local/bin is in your PATH (e.g. in ~/.zshrc or ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"
```

## usage

```bash
cd /path/to/compose/project
bckp-docker

# or point explicitly:
bckp-docker -p /path/to/project
```

what happens:

1. reads `.env` for settings  
2. finds your `docker-compose.yml`  
3. `docker compose down`  
4. ensures bucket exists (and optionally sets versioning & ACL)  
5. spins up `rclone/rclone` container, mounts volumes at `/data/<vol>`, and runs:
   ```
   rclone sync /data/<vol> s3://<bucket>/<project>/<vol>/ [your flags…]
   ```
6. shows a per‑volume progress line every 5s  
7. reports failures or success  
8. brings your compose stack **up** again  

## configuration

edit the `.env` values:

- `REMOTE`: name of rclone remote  
- `MAIN_BUCKET`: bucket for all backups  
- toggles for sync strategy:  
  - `SIZE_ONLY=1`  
  - `CHECKSUM=1`  
  - `UPDATE=1` & `USE_SERVER_MODTIME=1`  
- listing: `FAST_LIST`, `NO_TRAVERSE`  
- skip HEAD after PUT: `S3_NO_HEAD`  
- multipart: `S3_UPLOAD_CUTOFF`, `S3_CHUNK_SIZE`, `S3_UPLOAD_CONCURRENCY`  
- versioning/ACL: `ENABLE_VERSIONING`, `ENABLE_ACL`  
- `DEBUG=1` to trace the helper’s shell  

## tips

- for S3⇄S3 server‑side copies, add `--fast-list --checksum --transfers=200 --checkers=200`  
- for “top‑up” only new files: `UPDATE=1 USE_SERVER_MODTIME=1 NO_TRAVERSE=1`  
- stopping your DB container briefly avoids inconsistent DB files  
- run `rclone check` afterwards if you need end‑to‑end integrity  

enjoy rock‑solid, configurable Docker‑Compose volume backups to any S3 endpoint! 🚀

## license

this project is licensed under the GNU General Public License v3.0. see the LICENSE file for details.

## citation

if you use this project, please acknowledge the following facilitators and co‑authors:

**facilitators:**
- Roo Code
- OpenRouter
- OpenAI
- Google DeepMind

**co‑authors:**
- GPT‑4.1
- o4 mini
- Gemini 2.5 Pro