/**
 * BUİK Yoklama → Google Drive senkronu
 *
 * Supabase'de henüz Sheet'e aktarılmamış yoklama kayıtlarını
 * (attendance_records.synced_to_sheet = false) çeker; her toplantı için ilgili
 * alt kurulun Drive klasöründe (committees.drive_folder_id) bir Sheet açar,
 * katılanları yazar ve kayıtları "aktarıldı" olarak işaretler.
 *
 * Kurulum:
 *  1. Project Settings > Script Properties'e ekle:
 *       SUPABASE_URL          = https://YOUR-PROJECT-REF.supabase.co
 *       SUPABASE_SERVICE_KEY  = (Supabase > Project Settings > API > service_role)
 *  2. Editörde `kurulum` fonksiyonunu bir kez çalıştır, izinleri onayla.
 *     5 dakikada bir çalışan zamanlayıcıyı kurar ve ilk senkronu yapar.
 */

const TIMEZONE = 'Europe/Istanbul';
const BATCH_SIZE = 500;
const HEADERS = ['Ad Soyad', 'E-posta', 'Bölüm', 'Sınıf', 'Telefon', 'Katılım Zamanı', 'Kayıt No'];
const RECORD_ID_COLUMN = HEADERS.length; // "Kayıt No" — tekrar yazmayı önlemek için

function kurulum() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'yoklamalariSenkronizeEt')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('yoklamalariSenkronizeEt').timeBased().everyMinutes(5).create();
  yoklamalariSenkronizeEt();
}

function yoklamalariSenkronizeEt() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10 * 1000)) return; // önceki çalışma sürüyor
  try {
    const records = supabase_(
      'get',
      'attendance_records?synced_to_sheet=eq.false&order=checked_in_at.asc&limit=' + BATCH_SIZE +
        '&select=id,checked_in_at,' +
        'meetings(id,meeting_number,sheet_file_id,committees(name,drive_folder_id)),' +
        'profiles(full_name,email,department,class_year,phone)'
    );
    if (records.length === 0) return;

    const byMeeting = {};
    records.forEach(r => {
      (byMeeting[r.meetings.id] = byMeeting[r.meetings.id] || []).push(r);
    });

    Object.keys(byMeeting).forEach(meetingId => {
      const group = byMeeting[meetingId];
      try {
        const sheet = toplantiSheetiniGetir_(group[0].meetings);
        const written = mevcutKayitNolari_(sheet);
        const rows = group
          .filter(r => !written.has(String(r.id)))
          .map(r => [
            r.profiles.full_name || '',
            r.profiles.email || '',
            r.profiles.department || '',
            r.profiles.class_year || '',
            r.profiles.phone || '',
            Utilities.formatDate(new Date(r.checked_in_at), TIMEZONE, 'dd.MM.yyyy HH:mm'),
            String(r.id),
          ]);
        if (rows.length > 0) {
          sheet.getRange(sheet.getLastRow() + 1, 1, rows.length, HEADERS.length)
            .setNumberFormat('@')
            .setValues(rows);
        }
        supabase_('patch', 'attendance_records?id=in.(' + group.map(r => r.id).join(',') + ')', {
          synced_to_sheet: true,
        });
      } catch (e) {
        // Bu toplantı atlanır, kayıtları "aktarılmadı" kalır; sonraki çalışmada tekrar denenir.
        console.error('Toplantı ' + meetingId + ' aktarılamadı: ' + e.message);
      }
    });
  } finally {
    lock.releaseLock();
  }
}

function toplantiSheetiniGetir_(meeting) {
  if (meeting.sheet_file_id) {
    try {
      const file = DriveApp.getFileById(meeting.sheet_file_id);
      if (!file.isTrashed()) {
        return SpreadsheetApp.openById(meeting.sheet_file_id).getSheets()[0];
      }
    } catch (e) {
      // Dosya silinmiş ya da erişim yok — yenisi oluşturulur.
    }
  }

  const committee = meeting.committees;
  if (!committee.drive_folder_id) {
    throw new Error(committee.name + ' için drive_folder_id tanımlı değil');
  }
  const folder = DriveApp.getFolderById(committee.drive_folder_id);
  const spreadsheet = SpreadsheetApp.create(committee.name + ' – Toplantı ' + meeting.meeting_number);
  DriveApp.getFileById(spreadsheet.getId()).moveTo(folder);

  const sheet = spreadsheet.getSheets()[0];
  sheet.setName('Yoklama');
  sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]).setFontWeight('bold');
  sheet.setFrozenRows(1);

  supabase_('patch', 'meetings?id=eq.' + meeting.id, { sheet_file_id: spreadsheet.getId() });
  return sheet;
}

function mevcutKayitNolari_(sheet) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return new Set();
  return new Set(
    sheet.getRange(2, RECORD_ID_COLUMN, lastRow - 1, 1).getValues().map(row => String(row[0]))
  );
}

function supabase_(method, path, body) {
  const props = PropertiesService.getScriptProperties();
  const url = props.getProperty('SUPABASE_URL');
  const key = props.getProperty('SUPABASE_SERVICE_KEY');
  if (!url || !key) throw new Error('SUPABASE_URL / SUPABASE_SERVICE_KEY Script Properties\'te eksik');

  const options = {
    method: method,
    headers: { apikey: key, Authorization: 'Bearer ' + key, Prefer: 'return=minimal' },
    muteHttpExceptions: true,
  };
  if (body) {
    options.contentType = 'application/json';
    options.payload = JSON.stringify(body);
  }
  const res = UrlFetchApp.fetch(url + '/rest/v1/' + path, options);
  const code = res.getResponseCode();
  if (code >= 300) throw new Error('Supabase ' + method + ' ' + path + ' → ' + code + ': ' + res.getContentText());
  const text = res.getContentText();
  return text ? JSON.parse(text) : null;
}
