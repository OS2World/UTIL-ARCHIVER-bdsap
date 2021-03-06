program bdsap_sprachdefinition;

uses
  spra_ein;

begin
  sprachtabellenkopf(true,   (* eng *)
                     true,   (* ger *)
                     false,  (* fra *)
                     false); (* rus *)

  sprach_eintrag('packe_datei',
                 '� packing file ',
                 '� packe Datei ',
                 '',
                 '');

  sprach_eintrag('hilfe',
                 'usgae: BDSAP.EXE <PACKED.EXE> <files> ...',
                 'Benutzung: BDSAP.EXE <GEPACKT.EXE> <Dateien> ...',
                 '',
                 '');

  sprach_eintrag('keine_dateine_gefunden',
                 'no files found : ',
                 'keine Dateien gefunden : ',
                 '',
                 '');

  sprach_eintrag('Erzeuge_Programm',
                 '� creating program ',
                 '� Erzeuge Programm ',
                 '',
                 '');

  sprach_eintrag('Binde_gepackte_Resourcen',
                 '� linking compressed resources',
                 '� Binde gepackte Resourcen',
                 '',
                 '');

  sprach_eintrag('Loesche_temporaere_Dateien',
                 '� deleting temporary files ',
                 '� L�sche tempor�re Dateien ',
                 '',
                 '');

  sprach_eintrag('sprache',
                 'E',
                 'D',
                 '',
                 '');

  sprach_eintrag('merke_verzeichnis',
                 '� adding directory ',
                 '� merke Verzeichnis ',
                 '',
                 '');
{
  sprach_eintrag('',
                 '',
                 '',
                 '',
                 '');

  sprach_eintrag('',
                 '',
                 '',
                 '',
                 '');

  sprach_eintrag('',
                 '',
                 '',
                 '',
                 '');

  sprach_eintrag('',
                 '',
                 '',
                 '',
                 '');
}
  schreibe_sprach_datei('BDS$$$.001','BDS$$$.002','sprach_modul','sprach_start','^string');
end.
