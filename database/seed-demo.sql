-- ============================================================
-- el-Tru - DATA DEMO (opsional)
--
-- Akun demo (password lemah, hanya untuk lokal / demo!):
--   dosen     / dosen123   (Dosen)
--   andi      / andi123    (Mahasiswa)
--   mahasiswa / mhs12345   (Mahasiswa)
--
-- JANGAN load file ini di server publik tanpa mengganti password.
-- Semua nama/NIM/foto di bawah fiktif (foto memakai siluet default.jpg).
-- ============================================================

SET NAMES utf8mb4;

INSERT INTO `user`
  (`ID_USER`, `ID_LEVEL`, `USERNAME`, `PASSWD`, `E_MAIL`, `NAMA`, `FOTO`, `NOMORINDUK`, `PRODI`, `FAKULTAS`, `PT`)
VALUES
  (1, 1, 'dosen',     SHA2('dosen123', 256), 'dosen@example.com',     'Rina Kusuma',     'default.jpg',      '198001012005011001', 'Teknik Informatika', 'Teknik', 'Universitas Trunojoyo Madura'),
  (2, 2, 'andi',      SHA2('andi123', 256),  'andi@example.com',      'Andi Saputra',    'default.jpg',      '180411100001',       'Teknik Informatika', 'Teknik', 'Universitas Trunojoyo Madura'),
  (3, 2, 'mahasiswa', SHA2('mhs12345', 256), 'mahasiswa@example.com', 'Sari Dewi',       'default.jpg',      '180411100002',       'Teknik Informatika', 'Teknik', 'Universitas Trunojoyo Madura');

INSERT INTO `kelas` (`ID_KELAS`, `NAMA_KELAS`, `DESKRIPSI_KELAS`) VALUES
  (1, 'Pengembangan Aplikasi Web', 'Konsep dasar pengembangan aplikasi web: HTTP, HTML, PHP, dan basis data.'),
  (2, 'Keamanan Aplikasi Web',     'Mengenal celah umum aplikasi web seperti SQL Injection dan XSS beserta pencegahannya.'),
  (3, 'Basis Data',                'Perancangan basis data relasional dan SQL.');

INSERT INTO `kelas_user` (`ID_KELAS`, `ID_USER`) VALUES
  (1, 1), (2, 1), (3, 1),   -- dosen mengampu 3 kelas
  (1, 2), (2, 2),           -- andi ikut 2 kelas
  (1, 3);                   -- mahasiswa ikut 1 kelas

-- File PDF-nya sudah ada di folder materi/
INSERT INTO `materi` (`ID_KELAS`, `ID_USER`, `JUDUL_MATERI`, `DESKRIPSI_MATERI`, `LINK_MATERI`) VALUES
  (1, 1, 'Pertemuan 1 - Konsep Dasar',  'Slide pengantar konsep dasar pengembangan aplikasi web.', 'PAW2019-1_01 [Konsep Dasar Pengembangan Aplikasi Web]_perkuliahan_2.pdf'),
  (2, 1, 'Pertemuan 6 - Keamanan Web',  'Slide keamanan aplikasi web. Dibaca sebelum kuis minggu depan.', 'PAW2019-1_06 [Keamanan Aplikasi Web]_perkuliahan_3.pdf');
