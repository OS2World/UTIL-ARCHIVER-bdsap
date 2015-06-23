program bdsap_sprachdefinition;

uses
  spra_ein;

begin
  sprachtabellenkopf(true,   (* eng *)
                     true,   (* ger *)
                     false,  (* fra *)
                     false); (* rus *)

  sprach_eintrag('packe_datei',
                 'þ packing file ',
                 'þ packe Datei ',
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
                 'þ creating program ',
                 'þ Erzeuge Programm ',
                 '',
                 '');

  sprach_eintrag('Binde_gepackte_Resourcen',
                 'þ linking compressed resources',
                 'þ Binde gepackte Resourcen',
                 '',
                 '');

  sprach_eintrag('Loesche_temporaere_Dateien',
                 'þ deleting temporary files ',
                 'þ L”sche tempor„re Dateien ',
                 '',
                 '');

  sprach_eintrag('sprache',
                 'E',
                 'D',
                 '',
                 '');

  sprach_eintrag('merke_verzeichnis',
                 'þ adding directory ',
                 'þ merke Verzeichnis ',
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
