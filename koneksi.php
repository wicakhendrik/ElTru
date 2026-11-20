<?php
	// Konfigurasi koneksi dibaca dari environment variable (dipakai di Docker/VPS).
	// Jika tidak diset, otomatis memakai default lama (localhost / root / tanpa password)
	// sehingga tetap jalan di XAMPP/Laragon tanpa konfigurasi tambahan.
	$dbHost = getenv('DB_HOST') !== false ? getenv('DB_HOST') : 'localhost';
	$dbName = getenv('DB_NAME') !== false ? getenv('DB_NAME') : 'elearning';
	$dbUser = getenv('DB_USER') !== false ? getenv('DB_USER') : 'root';
	$dbPass = getenv('DB_PASS') !== false ? getenv('DB_PASS') : '';
	try
	{
	$dbh = new PDO("mysql:host=$dbHost;dbname=$dbName;charset=utf8mb4", $dbUser, $dbPass); //mengkoneksikan dengan database
	
  	$dbh->setAttribute( PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION );
	}
	catch (PDOException $e) 
	{
		// tampilkan pesan kesalahan jika koneksi gagal
		echo "Koneksi atau query bermasalah: " . $e->getMessage() . "<br/>";
		die();
	}
?>