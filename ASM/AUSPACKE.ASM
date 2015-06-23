;****************************************************************************
                .386p

                .model flat

code32          segment dword use32 public 'CODE'
code32          ends

data32          segment dword use32 public 'DATA'
data32          ends

;****************************************************************************

data32         segment use32

;****************************************************************************

datum           equ <'1999.03.23..1999.05.14'>

pstr macro zk
                local zk_l1
                local zk_l2

                db (offset zk_l2)-(offset zk_l1)
zk_l1:
                db zk
zk_l2:

endm
;****************************************************************************

titel:          pstr <'BDSAP OS/2 SFX * Veit Kannegieser * ',datum,13,10>

text_fehler_beim_resource_laden:
                ifdef englisch
                pstr <'Error loading resources !',13,10,7>
                else
                pstr <'Fehler beim Laden der Resourcen !',13,10,7>
                endif

text_datei_oeffnen_fehler:
                ifdef englisch
                pstr <'Error creating target file !',13,10,7>
                else
                pstr <'Fehler beim Erzeugen der Zieldatei !',13,10,7>
                endif

text_datei_schreiben_fehler:
                ifdef englisch
                pstr <'Error writing to target file !',13,10,7>
                else
                pstr <'Fehler beim Schreiben der Zieldatei !',13,10,7>
                endif

text_fehler_beim_entpacken:
                ifdef englisch
                pstr <'Decompression error !',13,10,7>
                else
                pstr <'Fehler beim Entpacken !',13,10,7>
                endif

umbruch:        pstr <13,10>

blocknummer     dd 0

geschrieben:    dd ?

resource_zeiger:dd ?

speicher_zeiger:dd ?

action:         dd ?

dateihandhabe:  dd ?

FileStatus3:
  _Creation     dd ?
  _LastAccess   dd ?
  _LastWrite    dd ?
  _cbFile       dd ?
  _cbFileAlloc  dd ?
  _attrFile     dd ?

cbFileStatus3=6*4


off_signatur            equ  0
off_blocklaenge         equ  8
off_blocktyp            equ 12

off_packverfahren       equ 16
off_pruefsumme          equ 20
off_laenge_eingepackt   equ 24
off_laenge_ausgepackt   equ 28
off_dateizeit           equ 32
off_dateiattribute      equ 36
off_dateiname           equ 40

ends


;****************************************************************************

code32          segment
                assume cs:code32
                assume ds:flat,es:flat
                assume ss:stack32

;****************************************************************************

                ; DOSCalls
                extrn DosExit                   :near

                extrn DosGetResource            :near
                extrn DosFreeResource           :near

                extrn DosOpen                   :near
                extrn DosWrite                  :near
                extrn DosClose                  :near

                extrn DosQueryFileInfo          :near
                extrn DosSetFileInfo            :near
                extrn DosQueryPathInfo          :near
                extrn DosSetPathInfo            :near

                extrn DosSetDefaultDisk         :near
                extrn DosSetCurrentDir          :near
                extrn DosCreateDir              :near

                extrn DosAllocMem               :near
                extrn DosFreeMem                :near

                ; APLib
                extrn _aP_depack_asm_fast       :near

;****************************************************************************

start:
                ;------------------------------------------
                ; Begráung
                mov esi,offset titel
                call ausschrift
                ;------------------------------------------

                ;------------------------------------------
                ; auf Komandozeile zeigen
                mov esi,[esp+010h]
                cld
              suche_p1:
                lodsb
                cmp al,0
                jne short suche_p1

              uebergehe_leerzeichen:
                lodsb
                ; " 123" -> "123"
                cmp al,0
                je short kein_p1
                cmp al,' '
                je short uebergehe_leerzeichen
                cmp al,9
                je short uebergehe_leerzeichen

                dec esi
                ;------------------------------------------

                ;------------------------------------------
                ; Laufwerksbuchstabe angegeben ?
                cmp byte ptr [esi+1],':'
                jne kein_laufwerkswechsel

                ; Buchstabe auswerten
                mov al,[esi]
                sub al,'@'   ; 'A'=1
                ; Laufwerk wechseln
                movzx eax,al
                push eax
                  call DosSetDefaultDisk
                pop eax ; add esp,1*4
                ;------------------------------------------

kein_laufwerkswechsel:
                ;------------------------------------------
                ; Pfad wechseln
                push esi
                  call DosSetCurrentDir
                pop ebx ; add esp,1*4
                or eax,eax
                je erfolgreich_gewechselt
                ;------------------------------------------

                ;------------------------------------------
                ; Verzeichnis existiert noch nicht
                push 0 ; EA
                  push esi
                    call DosCreateDir
                  pop ebx
                pop ebx
                or eax,eax
                jne kann_verzeichnis_nicht_anlegen

                ; Pfad wechseln
                push esi
                  call DosSetCurrentDir
                pop eax ; add esp,1*4
                ;------------------------------------------

kann_verzeichnis_nicht_anlegen:
erfolgreich_gewechselt:
kein_p1:

;############################################################################

datei_haupt_schleife:

                ;--- weiterzaehlen zur 1./2./3... Datei ---
                inc [blocknummer]
                ;------------------------------------------

                ;--- Resource von OS/2 anfordern ----------
                ;function DosGetResource(
                ;  Module: HModule;
                ;  IdType, IdName: ULong;
                ;  var ppb: Pointer): ApiRet;
                push offset resource_zeiger
                  push [blocknummer]
                    push 999
                      push 0
                         call DosGetResource
                add esp,4*4
                ;------------------------------------------

                ;--- Resource nicht vorhanden -> Abbruch --
                mov esi,offset text_fehler_beim_resource_laden
                or eax,eax
                jnz near ptr fehler_abbruch
                ;------------------------------------------

                ;------------------------------------------
                ; Basiszeiger laden
                mov ebp,dword ptr [resource_zeiger]
                ;------------------------------------------

                ;------------------------------------------
                ; Resourceblock mit Typ="Ende" ?
                cmp dword ptr [ebp+off_blocktyp],1
                je datei_block
                cmp dword ptr [ebp+off_blocktyp],2
                je near ptr verzeichnis_block

                push 0  ; ohne Fehler beenden
                push 1  ; Prozess
                call DosExit
                ;------------------------------------------

datei_block:
                ;------------------------------------------
                ; Dateinamen Anzeigen
                lea esi,[ebp+off_dateiname]
                call ausschrift
                mov esi,offset umbruch
                call ausschrift
                ;------------------------------------------

                ;------------------------------------------
                ; Datei erzeugen
;-----------------------------------------------------------------------------------------------------------------------
;  Filename   : Pchar;  // Address of the ASCIIZ path name of the file or device to be opened
;  var F      : HFile;  // The variable that receives the handle for the file
;  var Action : ULong;  // The variable that receives the value that specIfies the action taken by the DosOpen function
;  cbFile     : ULong;  // New logical size of the file (end of data, EOD), in bytes
;  Attribute  : ULong;  // File attribute information
;  OpenFlags  : ULong;  // The action to be taken depending on whether the file exists or does not exist
;  OpenMode   : ULong;  // The mode of the open function
;  EAs        : PEaop2; // Extended attributes
;
;  Result     : ApiRet; // Return Code

                ; EA
                push 0
                  ; open_share_DenyReadWrite ($00000010)
                  ; open_access_WriteOnly ($00000001)
                  push 011h
                    ; 0001xxxx -> open_action_Create_If_New
                    ; xxxx0010 -> open_action_Replace_If_Exists
                    push 012h
                      ; Attribute
                      ;---push dword ptr [ebp+off_dateiattribute]
                      ; Archiv+Sys+Versteckt
                      ; nicht Schreibschutz
                      push (020h+004h+002h)
                        ; Dateil„nge
                        push 0
                          push offset action
                            push offset dateihandhabe
                              ; Dateiname
                              lea eax,[ebp+off_dateiname+1]
                              push eax
                                call DosOpen
                add esp,8*4
                ;------------------------------------------

                ;------------------------------------------
                ; Fehlerbehandlung wenn Datei sich nicht
                ; ”ffenen l„át
                mov esi,offset text_datei_oeffnen_fehler
                or eax,eax
                jnz fehler_abbruch
                ;------------------------------------------


                ;------------------------------------------
                ; Speicher anfordern
                ;
                ; pag_Read ($00000001)
                ; pag_Write ($00000002)
                ; pag_Commit ($00000010)
                ; obj_Tile ($00000040) (<512 n”tig ?)
                push 053h
                  ; L„nge ausgepackt
                  push dword ptr [ebp+off_laenge_ausgepackt]
                    ; @pointer
                    push offset speicher_zeiger
                      call DosAllocMem
                add esp,3*4
                ; keine Fehlerbehandlung !
                ;------------------------------------------

                ;------------------------------------------
                ; 0 Byte mssen nicht entpackt werden
                mov eax,[ebp+off_laenge_ausgepackt]
                or eax,eax
                je short erfolgreich_ausgepackt

                ; schnellen Entpacker aufrufen
                push dword ptr [speicher_zeiger]
                  movzx eax,byte ptr [ebp+off_dateiname]
                  lea eax,[ebp+off_dateiname+1+eax]
                  push eax
                    call _aP_depack_asm_fast
                add esp,2*4
                ; eax=l„nge
                ;------------------------------------------

                ;------------------------------------------
                ; Fehlerbehandlung
                ; ausgepackt=Origginall„nge ?
                mov esi,offset text_fehler_beim_entpacken
                cmp eax,[ebp+off_laenge_ausgepackt]
                je short erfolgreich_ausgepackt

fehler_abbruch:
                call ausschrift
                push 1  ; Fehler !
                push 1  ; Prozess
                call DosExit

erfolgreich_ausgepackt:

                ;------------------------------------------
                ; entpackte Daten in Datei schreiben
                push offset geschrieben
                  ; Anzahl
                  push eax
                    ; wieviel
                    push dword ptr [speicher_zeiger]
                      push dword ptr [dateihandhabe]
                        call DosWrite
                add esp,4*4
                ;------------------------------------------

                ;------------------------------------------
                ; Schreibfehler ?
                mov esi,offset text_datei_schreiben_fehler
                mov eax,[ebp+off_laenge_ausgepackt]
                cmp eax,dword ptr [geschrieben]
                jne fehler_abbruch
                ;------------------------------------------

                ;------------------------------------------
                ; Daten holen
                ; L„nge
                push cbFileStatus3
                  ; Puffer
                  push offset FileStatus3
                    ; nur Datum/Zeit/..
                    push 1
                      push dword ptr [dateihandhabe]
                        call DosQueryFileInfo
                add esp,4*4
                ; keine Fehlerbehandlung
                ;------------------------------------------

                ;------------------------------------------
                ; Datum/Zeit kopieren
                mov eax,[ebp+off_dateizeit]
                rol eax,16
                mov [_Creation  ],eax
                mov [_LastAccess],eax
                mov [_LastWrite ],eax
                mov eax,[ebp+off_dateiattribute]
                mov [_attrFile],eax
                ;------------------------------------------

                ;------------------------------------------
                ; Daten schreiben
                ; L„nge
                push cbFileStatus3
                  ; Puffer
                  push offset FileStatus3
                    ; nur Datum/Zeit/..
                    push 1
                      push dword ptr [dateihandhabe]
                        call DosSetFileInfo
                add esp,4*4
                ; keine Fehlerbehandlung
                ;------------------------------------------


                ;------------------------------------------
                ; Datei Schliessen
                push dword ptr [dateihandhabe]
                  call DosClose
                pop eax ;add esp,1*4
                ; keine Prfung
                ;------------------------------------------


                ;------------------------------------------
                ; Speicher wieder freigeben
                push dword ptr [speicher_zeiger]
                  call DosFreeMem
                pop eax ;add esp,1*4
                ; keine Prfung
                ;------------------------------------------

                ;------------------------------------------
                ; Resource wird nicht mehr ben”tigt
                push dword ptr [resource_zeiger]
                  call DosFreeResource
                pop eax ;add esp,1*4
                ; keine Prfung
                ;------------------------------------------

                ; n„chste Datei ... -----------------------
                jmp near ptr datei_haupt_schleife
                ;------------------------------------------

;############################################################################

verzeichnis_block:
                ;------------------------------------------
                ; esi:=Verzeichnisname
                lea esi,[ebp+off_dateiname+1]
                ; Verzeichnis anlegen
                push 0 ; EA
                  push esi
                    call DosCreateDir
                  pop eax ; Keine Fehlerbehandlung
                pop eax
                ;------------------------------------------

                ;------------------------------------------
                ; Verzeichnisdatum/Zeit/Attribute holen
                ; L„nge
                push cbFileStatus3
                  ; Puffer
                  push offset FileStatus3
                    ; nur Datum/Zeit/..
                    push 1
                      push esi
                        call DosQueryPathInfo
                add esp,4*4
                ; keine Fehlerbehandlung
                ;------------------------------------------

                ;------------------------------------------
                ; Datum/Zeit kopieren
                mov eax,[ebp+off_dateizeit]
                rol eax,16
                mov [_Creation  ],eax
                mov [_LastAccess],eax
                mov [_LastWrite ],eax
                mov eax,[ebp+off_dateiattribute]
                mov [_attrFile],eax
                ;------------------------------------------

                ;------------------------------------------
                ; Daten schreiben
                ; 0 mit Schreibverz”gerung egal
                push 0
                  ; L„nge
                  push cbFileStatus3
                    ; Puffer
                    push offset FileStatus3
                      ; nur Datum/Zeit/..
                      push 1
                        push esi
                          call DosSetPathInfo
                add esp,5*4
                ; keine Fehlerbehandlung
                ;------------------------------------------

                ; n„chste Datei ... -----------------------
                jmp near ptr datei_haupt_schleife
                ;------------------------------------------

;****************************************************************************
; ESI
ausschrift:
                pushad
                  push offset geschrieben       ; @Actual
                    sub eax,eax
                    lodsb
                    push eax                    ; cbWrite
                      push esi                  ; @Buffer
                        push 0                  ; STDOUT
                          call DosWrite
                    add esp,4*4
                popad
                ret
;****************************************************************************
ends


;****************************************************************************

stack32         segment use32 stack
                db 02000h dup (?)
ends

;****************************************************************************

end start

