# Ceria Matematik · Tahun 1–6

Dashboard ceria dalam Bahasa Malaysia untuk latihan Matematik sekolah rendah. Sasaran penerbitan: **GitHub Pages + Supabase**. Tiada proses binaan berbayar atau pelayan Node diperlukan untuk laman web.

## Ciri yang siap dalam kod

- 48 kumpulan topik Tahun 1–6, 16 item setiap topik; 10 dipilih setiap kuiz.
- 9 set latihan UASA Tahun 4–6, 50 markah, 75 minit.
- 18 set Matriks Tahun 1–6, 50 markah, 60 minit.
- Semua jawapan diberi markah automatik. Jawapan akhir betul mendapat markah penuh item; salah/kosong mendapat 0. Pecahan setara diterima. Kira-kira pilihan tidak diberi markah kaedah.
- Tiada Ruang Guru dan tiada semakan markah manual.
- Rekod peranti, eksport CSV dan cetakan keputusan.
- Kod integrasi awan: sesi murid tanpa e-mel, kod kelas, beberapa kelas, akaun pengurusan, rekod percubaan, penapisan kelas, purata pencapaian dan eksport CSV.
- Markah awan dikira semula oleh fungsi SQL menggunakan 1,479 kunci soalan. Pelayar tidak dibenarkan memasukkan atau mengubah markah secara terus.

**Status:** Fungsi dan aliran peranti telah diuji secara automatik. Sambungan sebenar Supabase, polisi RLS pada pelayan, serta penerbitan GitHub Pages belum diuji atau diaktifkan dalam pakej ini. Tiada URL atau kunci projek sebenar dimasukkan. Pakej ini tidak mendakwa akaun, repositori atau pangkalan data telah dicipta.

## 1. Supabase

1. Cipta projek Supabase baharu. Pilih pelan percuma jika tersedia dan rantau sesuai. Semak pilihan serta kos dalam akaun sendiri.
2. SQL Editor: jalankan `supabase-schema.sql`, kemudian `supabase-answer-keys.sql`.
3. Dalam Authentication, aktifkan **Allow anonymous sign-ins** untuk murid. Pertimbangkan CAPTCHA dan kawalan kadar mengikut dokumentasi Supabase sebelum membuka penyertaan awam.
4. Cipta akaun pengurusan kelas menggunakan Authentication → Users di dashboard Supabase. Gunakan e-mel yang cikgu kawal dan kata laluan yang dimasukkan sendiri.
5. Salin UUID akaun tersebut dan jalankan SQL berikut (ganti UUID contoh):

```sql
insert into public.ceria_managers(user_id)
values ('UUID-AKAUN-PENGURUSAN-SEBENAR');
```

6. Isi **Project URL** dan **publishable key** dalam `supabase-config.js`:

```js
window.CERIA_SUPABASE = Object.freeze({
  url: 'https://PROJECT-REF.supabase.co',
  publishableKey: 'sb_publishable_...'
});
```

Jangan masukkan `service_role`, secret API key, token peribadi, kata laluan pangkalan data atau kata laluan pengguna ke repositori. Publishable key memang digunakan di pelayar; kawalan akses dikuatkuasakan pada pelayan.

7. Pada projek ujian, jalankan `tests/rls.sql` melalui SQL Editor. Ujian itu menyemak pengasingan dua murid, akses pengurus kelas yang ditugaskan, larangan menaik taraf peranan sendiri dan penskoran pecahan setara. Ia menggunakan transaksi ROLLBACK supaya data ujian tidak kekal.
8. Uji dua sesi pelayar berbeza dengan kelas berlainan sebelum memasukkan data sebenar.

## 2. GitHub Pages

1. Cipta repositori `kuiz-matematik-tahun4` dalam akaun GitHub. Nama ini dikekalkan mengikut rancangan projek; kandungannya menyokong Tahun 1–6.
2. Muat naik **kandungan pakej** ke akar repositori. Pastikan `.github/workflows/deploy.yml` turut dimuat naik; muat naik ZIP sahaja tidak menerbitkan laman.
3. Gunakan branch `main`.
4. Settings → Pages → Source: **GitHub Actions**.
5. Jalankan workflow `Terbitkan Ceria Matematik` di tab Actions jika perlu.
6. Buka URL Pages yang diberikan GitHub selepas deployment berjaya. Semua pautan aset menggunakan laluan relatif supaya serasi dengan sublaluan repositori.

Workflow menjalankan ujian dan membina `_site/` yang hanya mengandungi enam fail laman web. Skrip SQL, ujian, README dan bahan asal murid tidak dimasukkan ke artifak web. Tiada bahan lampiran asal cikgu disertakan dalam pakej ini.

## 3. Cara menggunakan rekod kelas

1. Di laman, buka **Kelas & rekod awan** dan log masuk akaun pengurusan.
2. Cipta kelas dengan nama serta Tahun 1–6. Setiap kelas mendapat kod rawak 16 aksara.
3. Berikan kod hanya kepada murid kelas itu. Murid memasukkan nama panggilan dan kod.
4. Murid menjawab latihan bagi **tahun kelas aktif**. Latihan tahun lain masih boleh dijawab sebagai pengukuhan tetapi hanya disimpan pada peranti.
5. Markah muncul serta-merta. Simpanan awan berjalan selepas penghantaran; jika rangkaian gagal, rekod peranti dikekalkan dan butang **Cuba simpan semula** tersedia.
6. Akaun pengurusan melihat rekod kelas yang ditugaskan; murid melihat rekod sendiri sahaja. Penapisan kelas dan eksport CSV tersedia.

Sesi murid tanpa e-mel terikat pada pelayar. Memadam data pelayar atau keluar akaun menghilangkan akses sesi itu, tetapi rekod sedia ada kekal pada kelas. Kod kelas membenarkan penyertaan; nama panggilan tidak mengesahkan identiti murid. Untuk penggunaan beberapa peranti dengan identiti tetap, akaun murid berdaftar perlu ditambah kemudian. Jangan gunakan profil pelayar murid yang sama untuk beberapa murid tanpa mengurus pertukaran sesi.

Paparan awan mengambil sehingga **500 percubaan terkini** yang dibenarkan bagi akaun semasa. Purata menggunakan peratus setiap percubaan yang dipaparkan. Jadual menyimpan semua percubaan; paparan lebih besar dan laporan sejarah boleh dikembangkan kemudian.

### Beberapa akaun pengurusan

Pentadbir boleh menambah pengguna berdaftar ke `ceria_managers` dan memasangkannya kepada kelas tertentu:

```sql
insert into public.ceria_class_managers(class_id,user_id)
values ('UUID-KELAS-SEBENAR','UUID-PENGGUNA-SEBENAR');
```

Keahlian pengurusan hanya boleh ditetapkan pentadbir pangkalan data. Murid tidak boleh melantik diri sendiri melalui laman.

## 4. Ujian dan kemas kini

Keperluan pembangunan: Node.js 22 atau lebih baharu. Tiada pemasangan pakej npm diperlukan.

```sh
node tests/bank.cjs
node tests/flows.cjs
node tests/cloud.cjs
node scripts/build.cjs
```

Jika `bank.js` berubah, jana semula kunci jawapan dan jalankan SQL yang terhasil pada Supabase sebelum menerbitkan kod baharu:

```sh
node scripts/generate-answer-keys.cjs
```

Ujian peranti menggunakan simulasi DOM dan rangkaian; ia tidak menggantikan ujian visual dalam pelayar atau ujian langsung Supabase. Kod klien statik membekalkan soalan dan jawapan untuk latihan pembelajaran, maka ini bukan sistem peperiksaan berpengawasan yang menyembunyikan jawapan.

## 5. Kurikulum dan penskoran

Topik berasaskan bidang KSSR Matematik; pemetaan setiap Standard Pembelajaran belum disahkan terhadap keseluruhan DSKP. Kandungan ialah latihan binaan, bukan soalan rasmi KPM.

Rujukan format UASA KPM 2025: Bahagian A 13 soalan (26 markah), Bahagian B 2 soalan berpecahan (24 markah), 75 minit. Set latihan menyediakan nisbah markah rendah:sederhana:tinggi 25:15:10. Kaedah automatik jawapan akhir dalam versi digital ini **berbeza daripada penskoran analitikal jalan kerja KPM**.

“Matriks” menggunakan struktur contoh ujian kelas yang diberikan: A 20 markah, B 18, C 12. Ia bukan nama format pentaksiran kebangsaan. Set A–C mengandungi variasi nilai dan sebahagian konteks berulang untuk pengukuhan. Keputusan tidak ditukar secara automatik kepada TP PBD.

Rujukan:

- [KPM · Format Instrumen UASA Tahap Dua 2025](https://www.moe.gov.my/storage/files/shares/pentaksiran-berasaskan-sekolah/7.%20Format%20Instrumen%20UASA%20Tahap%20Dua%20Sekolah%20Rendah%202025.pdf)
- [BPK · KSSR](https://bpk.moe.gov.my/kurikulum/kssr/kssr-tahun-1)
- [Supabase · Anonymous sign-ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Supabase · Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [GitHub · Custom workflows for Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
