-- ============================================================
-- el-Tru (E-Learning Trunojoyo) - schema database
--
-- Direkonstruksi dari query yang dipakai di source code PHP,
-- karena asset/eltru.sql adalah desain awal (PDM) yang sudah tidak
-- cocok dengan aplikasi (tidak ada kolom USERNAME, PASSWD, FOTO, dll).
--
-- PENTING: nama tabel HARUS huruf kecil. Kode memakai `user`, `kelas`,
-- dst., dan MySQL di Linux membedakan huruf besar/kecil pada nama tabel.
-- ============================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `level` (
  `ID_LEVEL`   INT          NOT NULL,
  `NAMA_LEVEL` VARCHAR(30)  NOT NULL,
  PRIMARY KEY (`ID_LEVEL`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Level 1 = Dosen (boleh buat/edit/hapus kelas & posting materi)
-- Level 2 = Mahasiswa (boleh gabung kelas & lihat materi)
INSERT IGNORE INTO `level` (`ID_LEVEL`, `NAMA_LEVEL`) VALUES
  (1, 'Dosen'),
  (2, 'Mahasiswa');

CREATE TABLE IF NOT EXISTS `user` (
  `ID_USER`    INT          NOT NULL AUTO_INCREMENT,
  `ID_LEVEL`   INT          NOT NULL DEFAULT 2,
  `USERNAME`   VARCHAR(50)  NOT NULL,
  `PASSWD`     CHAR(64)     NOT NULL COMMENT 'SHA2(password, 256) hex',
  `E_MAIL`     VARCHAR(100) NOT NULL DEFAULT '',
  `NAMA`       VARCHAR(100) NOT NULL DEFAULT '',
  `FOTO`       VARCHAR(255) NOT NULL DEFAULT 'default.jpg',
  `NOMORINDUK` VARCHAR(30)  NOT NULL DEFAULT '',
  `PRODI`      VARCHAR(100) NOT NULL DEFAULT '',
  `FAKULTAS`   VARCHAR(100) NOT NULL DEFAULT '',
  `PT`         VARCHAR(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`ID_USER`),
  UNIQUE KEY `uq_user_username` (`USERNAME`),
  KEY `idx_user_level` (`ID_LEVEL`),
  CONSTRAINT `fk_user_level` FOREIGN KEY (`ID_LEVEL`) REFERENCES `level` (`ID_LEVEL`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kelas` (
  `ID_KELAS`        INT          NOT NULL AUTO_INCREMENT,
  `NAMA_KELAS`      VARCHAR(50)  NOT NULL,
  `DESKRIPSI_KELAS` VARCHAR(200) NOT NULL,
  PRIMARY KEY (`ID_KELAS`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `kelas_user` (
  `ID_KELAS_USER` INT NOT NULL AUTO_INCREMENT,
  `ID_KELAS`      INT NOT NULL,
  `ID_USER`       INT NOT NULL,
  PRIMARY KEY (`ID_KELAS_USER`),
  KEY `idx_ku_kelas` (`ID_KELAS`),
  KEY `idx_ku_user` (`ID_USER`),
  -- CASCADE supaya "Hapus Kelas" / hapus user tidak gagal karena FK
  CONSTRAINT `fk_ku_kelas` FOREIGN KEY (`ID_KELAS`) REFERENCES `kelas` (`ID_KELAS`) ON DELETE CASCADE,
  CONSTRAINT `fk_ku_user`  FOREIGN KEY (`ID_USER`)  REFERENCES `user`  (`ID_USER`)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `materi` (
  `ID_MATERI`        INT          NOT NULL AUTO_INCREMENT,
  `ID_KELAS`         INT          NOT NULL,
  `ID_USER`          INT          NOT NULL,
  `JUDUL_MATERI`     VARCHAR(100) NOT NULL,
  `DESKRIPSI_MATERI` TEXT         NOT NULL,
  `LINK_MATERI`      VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'nama file di folder materi/',
  PRIMARY KEY (`ID_MATERI`),
  KEY `idx_materi_kelas` (`ID_KELAS`),
  KEY `idx_materi_user` (`ID_USER`),
  CONSTRAINT `fk_materi_kelas` FOREIGN KEY (`ID_KELAS`) REFERENCES `kelas` (`ID_KELAS`) ON DELETE CASCADE,
  CONSTRAINT `fk_materi_user`  FOREIGN KEY (`ID_USER`)  REFERENCES `user`  (`ID_USER`)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
