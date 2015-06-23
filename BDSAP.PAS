(*$D+*)(*$LocInfo+*)(*$I+*)

(*$M 32000*)
(*$Delphi+*)(*$X+*)

program bdsap;

(* 1999.03.23 Veit Kannegieser *)
(* 1999.05.13 šberarbeitung als Packer *)

uses
  VpSysLow,
  VpUtils,
  aplibu,
  spr,
  dos;

const
  aplib_version         =20; (* 0.20 *)
  bdsap_aplib_signatur  ='VK*ARAP'#$1a;
  datum                 ='1999.03.23..1999.05.14';

type
  dateiblock_typ=
    packed record
      signatur          :array[1..8] of char;   (*  0 *)
      blocklaenge       :longint;               (*  8 *)
      blocktyp          :longint;               (* 12 *) (* 1 *)

      packverfahren     :longint;               (* 16 *)
      pruefsumme        :longint;               (* 20 *)
      laenge_eingepackt :longint;               (* 24 *)
      laenge_ausgepackt :longint;               (* 28 *)
      dateizeit         :longint;               (* 32 *)
      dateiattribute    :longint;               (* 36 *)
      dateiname         :string;                (* 40 *)
      (* pascal shortstring mit zus„tzlichem #0 *)
    end;

  verzeichnis_block_typ=dateiblock_typ; (* blocktyp=2 *)

  ende_block_typ=
    packed record
      signatur          :array[1..8] of char;
      blocklaenge       :longint;
      blocktyp          :longint;                        (* 0 *)
    end;

var
  datei_zaehler,
  datei_zaehler_alt     :longint;
  tmp                   :string;
  cmd                   :string;
  zieldatei             :string;
  workmem               :^workmem_type;
  rc                    :text;
  aktuelle_dateilaenge  :longint;

function gross(const zk:string):string;
  var
    z:longint;
  begin
    result:=zk;
    for z:=1 to Length(result) do
      case result[z] of
        'a'..'z':result[z]:=Chr(Ord(result[z])-Ord('a')+Ord('A'));
      end;
  end;

(*$SAVES ALL*)
function cb(w1,w2:longint):longint;cdecl;
  begin
    write('<',w1,'/',aktuelle_dateilaenge,'> -> ',w2,^m);
    cb:=aP_pack_continue;
  end;
(*$SAVES EBX,ESI,EDI*)

procedure packe(const anfang,datei:string);
  var
    packname            :string;
    d1,d2               :file;
    p1,p2               :pointer;
    kopflaenge          :longint;
    dateiblock          :dateiblock_typ;
    l                   :longint;

  begin
    WriteLn(textz_packe_datei^,datei);
    inc(datei_zaehler);
    packname:=tmp+'BDSAP$$$.'+Int2StrZ(datei_zaehler,3);
    WriteLn(rc,'RESOURCE 999 ',datei_zaehler,' ',packname);

    filemode:=open_access_ReadOnly+open_share_DenyNone;
    Assign(d1,datei);
    Reset(d1,1);

    with dateiblock do
      begin
        signatur:=bdsap_aplib_signatur;
        dateiname:=Copy(datei,Length(anfang)+1,255)+#0;
        GetFattr(d1,dateiattribute);
        GetFTime(d1,dateizeit);
        laenge_ausgepackt:=FileSize(d1);
        packverfahren:=aplib_version;
        pruefsumme:=0;
        blocktyp:=1; (* DATEI *)
      end;

    l:=FileSize(d1);
    GetMem(p1,l);
    BlockRead(d1,p1^,l);
    Close(d1);

    GetMem(p2,((l*9) div 8)+16);

    aktuelle_dateilaenge:=l;
    l:=_ap_pack(p1^,p2^,l,workmem^,cb);
    Write('                                        '^m);

    with dateiblock do
      begin
        laenge_eingepackt:=l;
        kopflaenge:=Ofs(dateiblock.dateiname)-ofs(dateiblock)
                    +length(dateiname)+1;
        blocklaenge:=kopflaenge+laenge_eingepackt;
      end;

    filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
    Assign(d2,packname);
    Rewrite(d2,1);
    BlockWrite(d2,dateiblock,kopflaenge);
    BlockWrite(d2,p2^,l);
    Close(d2);

    Dispose(p1);
    Dispose(p2);
  end;

procedure speichere_verzeichnis(const anfang,verzeichnisname:string;const datum_zeit,attribute:longint);
  var
    verzeichnis_block                   :verzeichnis_block_typ;
    d2                                  :file;
    packname                            :string;
  begin
    WriteLn(textz_merke_verzeichnis^,verzeichnisname);
    inc(datei_zaehler);
    packname:=tmp+'BDSAP$$$.'+Int2StrZ(datei_zaehler,3);
    WriteLn(rc,'RESOURCE 999 ',datei_zaehler,' ',packname);

    with verzeichnis_block do
      begin
        signatur:=bdsap_aplib_signatur;
        dateiname:=Copy(verzeichnisname,Length(anfang)+1,255)+#0;

        filemode:=open_access_ReadOnly+open_share_DenyNone;
        dateiattribute:=attribute;
        dateizeit:=datum_zeit;
        laenge_ausgepackt:=0;
        laenge_eingepackt:=0;
        packverfahren:=0;
        pruefsumme:=0;
        blocktyp:=2; (* VERZEICHNIS *)

        blocklaenge:=Ofs(verzeichnis_block.dateiname)-ofs(verzeichnis_block)
                    +length(dateiname)+1;
      end;

    filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
    Assign(d2,packname);
    Rewrite(d2,1);
    BlockWrite(d2,verzeichnis_block,verzeichnis_block.blocklaenge);
    Close(d2);
  end;

procedure suche(const anfang,dateien:string);
  var
    sr                                  :searchrec;
    pfad,name_,erweiterung              :string;
  begin
    FSplit(dateien,pfad,name_,erweiterung);
    if anfang='' then
      begin
        suche(pfad,pfad+name_+erweiterung);
      end
    else
      begin
        FindFirst(dateien,AnyFile,sr);
        while DosError=0 do
          begin

            if  (sr.name<>'.')
            and (sr.name<>'..')
            and (pos('BDSAP$$$',gross(sr.name))=0)
            and (gross(pfad+sr.name)<>gross(zieldatei))
             then
              begin
                if (sr.attr and Directory)=Directory then
                  begin
                    speichere_verzeichnis(anfang,pfad+sr.name,sr.time,sr.attr);
                    suche(anfang,pfad+sr.name+'\*.*')
                  end
                else
                  packe(anfang,pfad+sr.name);
              end;

            FindNext(sr);
          end;
        FindClose(sr);
      end;
  end;

procedure schreibe_ende;
  var
    ende_block          :ende_block_typ;
    packname            :string;
    d2                  :file;
  begin
    inc(datei_zaehler);
    packname:=tmp+'BDSAP$$$.'+Int2StrZ(datei_zaehler,3);
    WriteLn(rc,'RESOURCE 999 ',datei_zaehler,' ',packname);

    filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
    Assign(d2,packname);
    Rewrite(d2,1);
    with ende_block do
      begin
        signatur:=bdsap_aplib_signatur;
        blocklaenge:=SizeOf(ende_block_typ);
        blocktyp:=0; (* ENDE *)
      end;
    Blockwrite(d2,ende_block,SizeOf(ende_block_typ));
    Close(d2);
  end;

(*$ORGNAME+*)
procedure auspacker_d;external;
procedure auspacker_d_laenge;external;
procedure auspacker_e;external;
procedure auspacker_e_laenge;external;
(*$L SFX_D.OBJ*)
(*$L SFX_E.OBJ*)
(*$ORGNAME-*)

procedure schreibe_auspacker;
  var
    exe:file;
  begin
    filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
    Assign(exe,zieldatei);
    ReWrite(exe,1);
    if textz_sprache^='D' then
      BlockWrite(exe,ptr(ofs(auspacker_d))^,meml[ofs(auspacker_d_laenge)])
    else
      BlockWrite(exe,ptr(ofs(auspacker_e))^,meml[ofs(auspacker_e_laenge)]);
    Close(exe);
  end;


procedure loesche(const endung:string);
  var
    d                   :file;
  begin
    filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
    Assign(d,tmp+'BDSAP$$$.'+endung);
    Erase(d);
    Write('.');
  end;

var
  para_zaehler          :longint;
  exe                   :file;

begin
  WriteLn('ð BDSAP * Veit Kannegieser * ',datum);
  if paramcount<2 then
    begin
      WriteLn(textz_hilfe^);
      Halt(1);
    end;

  tmp:=GetEnv('TMP');
  if tmp='' then
    tmp:=GetEnv('TMP');
  if tmp='' then
    tmp:='.';

  tmp:=FExpand(tmp);

  if not (tmp[length(tmp)] in ['/','\']) then
    tmp:=tmp+'\';

  zieldatei:=FExpand(ParamStr(1));

  cmd:=GetEnv('COMSPEC');

  datei_zaehler:=0;

  (* Erzeugen des Resource Compiler Quelltextes *)
  filemode:=open_access_WriteOnly+open_share_DenyReadWrite;
  Assign(rc,tmp+'BDSAP$$$.RC');
  Rewrite(rc);
  WriteLn(rc,'; BDSAP * V.K.');

  New(workmem);

  for para_zaehler:=2 to ParamCount do
    begin
      datei_zaehler_alt:=datei_zaehler;
      suche('',FExpand(ParamStr(para_zaehler)));
      if datei_zaehler_alt=datei_zaehler then
        WriteLn(textz_keine_dateine_gefunden^,ParamStr(para_zaehler));
    end;

  Dispose(workmem);


  if datei_zaehler=0 then
    begin
      Close(rc);
      Erase(rc);
      Halt(1);
    end;

  schreibe_ende;
  Close(rc);

  WriteLn(textz_Erzeuge_Programm^,zieldatei);
  schreibe_auspacker;

  WriteLn(textz_Binde_gepackte_Resourcen^);
  Exec(cmd,'/C RC.EXE -n '+tmp+'BDSAP$$$.RC '+zieldatei);

  Write  (textz_Loesche_temporaere_Dateien^);
  loesche('RC');
  loesche('RES');
  while datei_zaehler>0 do
    begin
      loesche(Int2StrZ(datei_zaehler,3));
      dec(datei_zaehler);
    end;
  WriteLn;
end.

