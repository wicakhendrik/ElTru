# DEPLOY.md — Panduan Deploy el-Tru

Dokumen ini ditulis untuk **manusia dan AI agent** yang men-deploy aplikasi ke VPS Linux (Ubuntu/Debian).
**Status pengujian:** jalur utama Docker Compose (bagian 3, 4, 5, 7) sudah diuji dari nol di Docker Desktop/Windows dengan MySQL 8.0 dan PHP 8.2: build, inisialisasi skema, login, buat kelas, gabung kelas, upload materi, backup, dan restore. Konfigurasi Caddy (bagian 6B) dan jalur LAMP (bagian 8) **belum diuji** di server sungguhan. Perlakukan keduanya sebagai titik awal, dan periksa hasilnya.

- [1. Gambaran singkat](#1-gambaran-singkat)
- [2. Prasyarat](#2-prasyarat)
- [3. Deploy (jalur utama: Docker Compose)](#3-deploy-jalur-utama-docker-compose)
- [4. Verifikasi](#4-verifikasi)
- [5. Membuat akun dosen sungguhan](#5-membuat-akun-dosen-sungguhan)
- [6. Mengamankan akses](#6-mengamankan-akses)
- [7. Operasional: update, backup, restore, reset](#7-operasional-update-backup-restore-reset)
- [8. Alternatif: tanpa Docker (LAMP)](#8-alternatif-tanpa-docker-lamp)
- [9. Troubleshooting](#9-troubleshooting)
- [10. Aturan untuk AI agent](#10-aturan-untuk-ai-agent)

---

## 1. Gambaran singkat

```text
Internet ──► Caddy/Nginx (HTTPS, basic auth)   ← opsional tapi sangat disarankan
                 │  reverse_proxy 127.0.0.1:8088
                 ▼
        ┌─────────────────── docker compose (project "eltru") ───────────────────┐
        │  web : php:8.2-apache  (aplikasi, port 80 di dalam container)          │
        │          │ PDO mysql, host "db"                                        │
        │  db  : mysql:8.0       (TIDAK dipublish ke host / internet)            │
        │                                                                        │
        │  volume: db_data, uploads_user (asset/user), uploads_materi (materi)   │
        └────────────────────────────────────────────────────────────────────────┘
```

Fakta penting tentang aplikasi ini:

| Hal | Nilai |
| --- | --- |
| Stack | PHP native + PDO MySQL, tanpa Composer / npm / build step |
| Koneksi DB | env `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS` (default: `localhost` / `elearning` / `root` / kosong) |
| Skema database | `database/schema.sql` (**bukan** `asset/eltru.sql`, itu desain lama yang tidak cocok) |
| Nama tabel | **huruf kecil** (`user`, `kelas`, ...). Linux membedakan huruf besar/kecil |
| Folder yang ditulis aplikasi | `asset/user/` (foto profil), `materi/` (file materi) |
| Port default | `127.0.0.1:8088` di host (ubah lewat `APP_BIND` / `APP_PORT` di `.env`) |
| Skema dijalankan otomatis | Ya, hanya saat volume `db_data` **pertama kali** dibuat |

## 2. Prasyarat

- VPS Linux (Ubuntu 22.04/24.04 atau Debian 12), RAM ≥ 1 GB, akses `sudo`.
- Port 22 (SSH) terbuka. Port 80/443 hanya jika memakai reverse proxy publik.
- Docker Engine + Docker Compose v2 (plugin `docker compose`, bukan `docker-compose` lama).
- Git.

Cek:

```bash
docker --version && docker compose version && git --version
```

Jika Docker belum ada (skrip resmi Docker):

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # logout/login ulang agar berlaku tanpa sudo
```

## 3. Deploy (jalur utama: Docker Compose)

### 3.1 Ambil kode

```bash
git clone https://github.com/wicakhendrik/ElTru.git
cd ElTru
```

### 3.2 Buat file `.env`

```bash
cp .env.example .env
# isi dua password dengan nilai acak:
sed -i "s/^DB_PASS=.*/DB_PASS=$(openssl rand -hex 16)/"           .env
sed -i "s/^DB_ROOT_PASS=.*/DB_ROOT_PASS=$(openssl rand -hex 16)/" .env
chmod 600 .env
```

`.env` berisi rahasia: **jangan di-commit** (sudah ada di `.gitignore`) dan jangan ditempel ke chat/log.

Isi akhir yang perlu dipahami:

| Variabel | Arti | Catatan |
| --- | --- | --- |
| `DB_NAME` / `DB_USER` | nama database & user aplikasi | default `elearning` / `eltru` |
| `DB_PASS` / `DB_ROOT_PASS` | password user aplikasi & root MySQL | **wajib diisi**, compose menolak jalan jika kosong |
| `APP_BIND` | alamat bind port aplikasi di host | `127.0.0.1` (aman, lewat reverse proxy). `0.0.0.0` hanya untuk uji coba |
| `APP_PORT` | port aplikasi di host | default `8088` |

### 3.3 Build dan jalankan

```bash
docker compose up -d --build
docker compose ps          # db harus "healthy", web "Up"
```

Pertama kali jalan, MySQL otomatis membuat database dan menjalankan `database/schema.sql`.
Build pertama mengunduh image `php:8.2-apache` dan `mysql:8.0` (beberapa menit).

### 3.4 Data demo (opsional, hanya untuk uji coba)

Membuat 3 akun dengan password lemah (`dosen/dosen123`, `andi/andi123`, `mahasiswa/mhs12345`):

```bash
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < database/seed-demo.sql
```

> **Di server yang bisa diakses publik, lewati langkah ini**, atau hapus akun demo setelah dipakai (lihat [bagian 5](#5-membuat-akun-dosen-sungguhan)).
> Jika dijalankan dua kali akan error `Duplicate entry`. Itu aman, artinya data sudah ada.

## 4. Verifikasi

Jalankan semua, semuanya harus sesuai hasil yang diharapkan.

```bash
# 1) kedua container berjalan, db healthy
docker compose ps --format '{{.Service}}: {{.State}} {{.Health}}'
#    db: running healthy
#    web: running

# 2) tabel sudah dibuat (5 tabel: kelas kelas_user level materi user)
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -N -e "show tables"' 2>/dev/null

# 3) halaman login merespons 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/login/index.php
#    200

# 4) (hanya jika data demo dimuat) login dosen -> 302 ke index.php
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' \
  -d 'username=dosen&password=dosen123&login=Login' http://127.0.0.1:8088/login/index.php
#    302 -> http://127.0.0.1:8088/index.php

# 5) tidak ada error PHP/MySQL di log
docker compose logs --tail=50 web | grep -iE 'fatal|error' || echo "log bersih"
```

Port MySQL **tidak** dipublish ke host. Pastikan:

```bash
ss -tlnp | grep -E ':3306|:33060' || echo "OK: MySQL tidak terbuka ke host"
```

## 5. Membuat akun dosen sungguhan

Aplikasi tidak punya halaman pendaftaran. User dibuat langsung di database.
Level: `1` = Dosen, `2` = Mahasiswa. Password disimpan sebagai `SHA2(password, 256)`.

Ganti nilai `GANTI_...` dulu. Heredoc di bawah memakai `'SQL'` (dengan kutip) supaya shell tidak mengubah isinya:

```bash
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' <<'SQL'
INSERT INTO user (ID_LEVEL, USERNAME, PASSWD, E_MAIL, NAMA, NOMORINDUK, PRODI, FAKULTAS, PT)
VALUES (1, 'GANTI_USERNAME', SHA2('GANTI_PASSWORD_KUAT', 256), 'email@contoh.com',
        'Nama Lengkap', '123456', 'Teknik Informatika', 'Teknik', 'Universitas Trunojoyo Madura');
SQL
```

Menghapus akun demo (jika data demo sempat dimuat):

```bash
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -e "DELETE FROM user WHERE USERNAME IN (\"dosen\",\"andi\",\"mahasiswa\");"'
```

Relasi `ON DELETE CASCADE` ikut menghapus keanggotaan kelas dan materi milik user tersebut.
Foto profil default adalah `default.jpg`; user bisa menggantinya lewat menu Profile → Edit Profile.

## 6. Mengamankan akses

> ⚠️ **Baca ini sebelum membuka ke internet.** Kode aplikasi dari 2019 dan punya celah yang diketahui:
> SQL injection di banyak query, XSS, tanpa CSRF, aksi hapus lewat `GET` tanpa cek peran, hash password tanpa salt.
> Jangan expose langsung tanpa lapisan pengaman di depannya. Pilih salah satu opsi di bawah.

### Opsi A — Hanya lewat VPN / Tailscale (paling aman, direkomendasikan)

Biarkan `APP_BIND=127.0.0.1`. Akses lewat SSH tunnel:

```bash
ssh -L 8088:127.0.0.1:8088 user@IP_VPS      # lalu buka http://localhost:8088 di laptop
```

Atau bind ke IP Tailscale server (ganti dengan hasil `tailscale ip -4`) di `.env`, lalu `docker compose up -d`:

```env
APP_BIND=100.x.y.z
```

### Opsi B — Domain + HTTPS + basic auth (Caddy)

Prasyarat: domain A-record sudah mengarah ke IP VPS; port 80 dan 443 terbuka di firewall.

```bash
sudo apt-get update && sudo apt-get install -y caddy
caddy hash-password            # ketik password, salin hash yang keluar
```

`/etc/caddy/Caddyfile`:

```caddyfile
eltru.contoh.com {
    # Caddy < 2.8 memakai "basicauth" (tanpa underscore)
    basic_auth {
        admin $2a$14$GANTI_DENGAN_HASH_DARI_PERINTAH_DI_ATAS
    }
    reverse_proxy 127.0.0.1:8088
}
```

```bash
sudo systemctl reload caddy
```

Caddy mengurus sertifikat HTTPS (Let's Encrypt) otomatis. Basic auth ini bertindak sebagai gerbang pertama
sebelum halaman login aplikasi, sehingga celah di kode tidak bisa dijangkau orang asing.

### Firewall (UFW)

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp && sudo ufw allow 443/tcp   # hanya untuk opsi B
sudo ufw enable
```

> Catatan Docker: port yang dipublish Docker **melewati UFW**. Itu sebabnya `APP_BIND=127.0.0.1` adalah pengaman utama.
> Jangan ubah ke `0.0.0.0` di server publik.

## 7. Operasional: update, backup, restore, reset

Jalankan dari folder repo.

### Update ke versi terbaru

```bash
git pull
docker compose up -d --build
```

Data (database dan upload) tetap aman karena ada di volume.
Perubahan `database/schema.sql` **tidak** dijalankan ulang otomatis pada database yang sudah ada.
Jika skema berubah, terapkan manual dengan `ALTER TABLE` melalui `docker compose exec`.

### Backup

```bash
mkdir -p backup

# database
docker compose exec -T db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' 2>/dev/null > backup/db-$(date +%F).sql

# file upload (foto profil & materi)
for v in uploads_user uploads_materi; do
  docker run --rm -v eltru_$v:/data:ro -v "$PWD/backup":/out alpine tar czf /out/$v-$(date +%F).tgz -C /data .
done
```

### Restore

```bash
# database (ke database yang sudah ada, menimpa tabel yang sama)
docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < backup/db-TANGGAL.sql

# upload
docker run --rm -v eltru_uploads_materi:/data -v "$PWD/backup":/in alpine tar xzf /in/uploads_materi-TANGGAL.tgz -C /data
```

### Log, restart, berhenti

```bash
docker compose logs -f web          # log Apache/PHP
docker compose restart web
docker compose down                 # berhenti, data tetap
```

### Reset total (⚠️ menghapus database dan semua upload)

```bash
docker compose down -v
docker compose up -d --build        # schema dibuat ulang dari nol
```

## 8. Alternatif: tanpa Docker (LAMP)

Gunakan jika VPS tidak boleh menjalankan Docker.

```bash
sudo apt-get update
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql mariadb-server git
sudo git clone https://github.com/wicakhendrik/ElTru.git /var/www/eltru
sudo chown -R www-data:www-data /var/www/eltru/asset/user /var/www/eltru/materi
```

Buat database dan user (ganti password):

```bash
sudo mysql <<'SQL'
CREATE DATABASE elearning CHARACTER SET utf8mb4;
CREATE USER 'eltru'@'localhost' IDENTIFIED BY 'GANTI_PASSWORD';
GRANT ALL PRIVILEGES ON elearning.* TO 'eltru'@'localhost';
SQL
sudo mysql elearning < /var/www/eltru/database/schema.sql
```

Kredensial dibaca dari environment variable. Cara paling mudah untuk Apache: buat `/etc/apache2/conf-available/eltru-env.conf`

```apache
SetEnv DB_HOST localhost
SetEnv DB_NAME elearning
SetEnv DB_USER eltru
SetEnv DB_PASS GANTI_PASSWORD
```

> `getenv()` pada mod_php membaca variabel dari `SetEnv`. Jika kredensial tidak terbaca, `koneksi.php`
> jatuh ke default `root` tanpa password dan koneksi gagal.

Lalu aktifkan:

```bash
sudo a2enconf eltru-env
sudo sed -i 's#DocumentRoot /var/www/html#DocumentRoot /var/www/eltru#' /etc/apache2/sites-available/000-default.conf
sudo chmod 640 /etc/apache2/conf-available/eltru-env.conf
sudo systemctl reload apache2
```

Tambahkan ke `php.ini` (`/etc/php/*/apache2/php.ini`): `display_errors = Off`, `upload_max_filesize = 20M`, `post_max_size = 25M`.
Lalu tetap terapkan [bagian 6](#6-mengamankan-akses). Untuk jalur ini, taruh basic auth/IP allowlist di Apache atau di firewall.

## 9. Troubleshooting

| Gejala | Penyebab | Solusi |
| --- | --- | --- |
| `docker compose up` error `isi DB_PASS di file .env` | `.env` belum dibuat atau kosong | Ulangi [3.2](#32-buat-file-env) |
| Halaman menampilkan `Koneksi atau query bermasalah: ... Access denied` | Password di `.env` diubah **setelah** volume `db_data` terbentuk | Password MySQL hanya diset saat inisialisasi. Kembalikan nilai lama, atau reset total (`down -v`) bila data boleh hilang |
| `Koneksi ... Connection refused` / `Unknown host db` | `db` belum siap, atau web dijalankan di luar compose | `docker compose ps` harus menunjukkan `db healthy`; jalankan lewat `docker compose`, bukan `docker run` manual |
| `Table 'elearning.user' doesn't exist` | Skema tidak termuat (volume `db_data` sudah ada sebelum skema masuk) | `docker compose exec -T db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < database/schema.sql` (aman diulang, memakai `IF NOT EXISTS`) |
| Buat kelas / gabung kelas / posting materi "gagal" | Versi lama kode memasukkan `''` ke kolom ID auto-increment, ditolak MySQL 8 (`ERROR 1366`) | Sudah diperbaiki (`NULL`) di `function/function.php`. Pastikan memakai kode terbaru (`git pull`) |
| Hapus kelas menghasilkan error foreign key | Database dibuat dari skema lama tanpa `ON DELETE CASCADE` | Pakai `database/schema.sql` terbaru |
| Upload materi gagal / file besar ditolak | Batas upload PHP | Naikkan `upload_max_filesize` dan `post_max_size` di `docker/php.ini`, lalu `docker compose up -d --build` |
| Upload gagal `Permission denied` | Folder upload bukan milik `www-data` | Docker: `docker compose exec web chown -R www-data:www-data asset/user materi`. LAMP: lihat [bagian 8](#8-alternatif-tanpa-docker-lamp) |
| Foto/PDF contoh tidak muncul setelah deploy | Volume upload sudah ada dan kosong sebelum image berisi file contoh | `docker compose down`, `docker volume rm eltru_uploads_user eltru_uploads_materi`, lalu `up -d` (hanya jika belum ada upload penting) |
| Port 8088 sudah dipakai | Bentrok dengan layanan lain | Ubah `APP_PORT` di `.env`, lalu `docker compose up -d` |
| Layar putih tanpa pesan | `display_errors` dimatikan di container | `docker compose logs web` untuk melihat error PHP yang sebenarnya |
| Login benar tapi kembali ke halaman login | Cookie sesi tidak terkirim (mis. HTTPS di belakang proxy diakses lewat HTTP campuran) | Akses lewat satu skema saja (semuanya HTTPS) dan hapus cookie |
| Login salah tidak menampilkan pesan error | Perilaku asli kode (pesan hanya muncul bila format input tidak valid) | Bukan bug deploy |

## 10. Aturan untuk AI agent

Jika kamu AI agent yang menjalankan panduan ini di VPS:

1. **Ikuti jalur utama (bagian 3)**, kecuali pengguna meminta jalur LAMP.
2. **Jangan mengubah kode aplikasi** untuk deploy. Semua penyesuaian lewat `.env`, Compose, atau Caddy.
3. **Jangan pernah** mempublish port MySQL (3306), mengisi `APP_BIND=0.0.0.0`, atau membuka port selain 22/80/443 tanpa persetujuan eksplisit pengguna.
4. **Jangan memuat `database/seed-demo.sql` di server publik** tanpa izin pengguna, karena memuat akun berpassword lemah.
5. **Jangan mencetak isi `.env`** ke output/log/chat. Cukup konfirmasi bahwa file ada dan terisi (`grep -c . .env`).
6. **Tanya pengguna sebelum**: menjalankan `docker compose down -v`, menghapus volume, `ufw enable`, mengubah DNS, atau memasang/mengubah reverse proxy publik.
7. Selesai deploy, jalankan **seluruh perintah di [bagian 4](#4-verifikasi)** dan laporkan hasilnya apa adanya. Jika ada yang gagal, jangan klaim berhasil; sertakan potongan log dan cocokkan dengan [bagian 9](#9-troubleshooting).
8. Laporkan ke pengguna: URL akses, bagaimana cara login, apakah data demo dimuat, dan apakah aplikasi sudah di balik VPN/basic auth atau masih terbuka.

### Ringkasan satu layar (untuk agent)

```bash
git clone https://github.com/wicakhendrik/ElTru.git && cd ElTru
cp .env.example .env
sed -i "s/^DB_PASS=.*/DB_PASS=$(openssl rand -hex 16)/"           .env
sed -i "s/^DB_ROOT_PASS=.*/DB_ROOT_PASS=$(openssl rand -hex 16)/" .env
chmod 600 .env
docker compose up -d --build
docker compose ps
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/login/index.php   # harus 200
```
