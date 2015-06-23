unit aplibu;

(* $DEFINE ESC_ABORT*)

(***************************************************************
 *         aPLib v0.20b  -  the smaller the better :)          *
 *       PASCAL interface to ..\..\lib\watcom\aplib.lib        *
 *                                                             *
 *   Copyright (c) 1998-99 by  ÄúJibzúÄ  All Rights Reserved   *
 *    -> Pascal   Veit Kannegieser, 23.09.1998                 *
 ***************************************************************)

interface

const
  aP_pack_continue=1;
  aP_pack_break   =0;

type
  (*$Cdecl+*)(*$SAVES ALL*)
  apack_status=function(w1,w2:longint):longint;
  (*$Cdecl-*)(*$SAVES EBX,ESI,EDI*)

  workmem_type=array[0..1024*1024-1] of byte;

(*$ORGNAME+*) (* aplibu@_aP_pack -> _aP_pack *)
function _aP_pack(var quelle;
                  var ziel;
                  laenge:longint;
                  var workmem:workmem_type;
                  status:apack_status):longint;cdecl;

function _aP_depack_asm(var quelle,ziel):longint;cdecl;

function _aP_depack_asm_fast(var quelle,ziel):longint;cdecl;
(*$ORGNAME-*)

(*$SAVES ALL*)
function cb0(w1,w2:longint):longint;cdecl;
function cb1(w1,w2:longint):longint;cdecl;
(*$SAVES EBX,ESI,EDI*)

implementation

(*$IFDEF ESC_ABORT*)
uses
  VPSysLow;
(*$ENDIF ESC_ABORT*)


function _aP_pack(var quelle;
                  var ziel;
                  laenge:longint;
                  var workmem:workmem_type;
                  status:apack_status):longint;external;

function _aP_depack_asm(var quelle,ziel):longint;external;

function _aP_depack_asm_fast(var quelle,ziel):longint;external;

(*$L lib\aplib.lib*)
(* $L depack.obj   *)
(* $L depackf.obj  *)
(* $L aplib.obj    *)



(* callback samples for _aP_pack *)
function cb0(w1,w2:longint):longint;assembler;(*$FRAME-*)(*$USES NONE*)
  asm
    mov eax,aP_pack_continue
  end;

function cb1(w1,w2:longint):longint;
  begin
    write('<',w1:8,'/',w2:8,'>'+^h+^h^h^h^h^h^h^h^h+^h+^h^h^h^h^h^h^h^h+^h);
    cb1:=aP_pack_continue;
    (*$IFDEF ESC_ABORT*)
    if SysKeypressed then
      if SysReadKey=#27 then
        cb1:=aP_pack_break;
    (*$ENDIF ESC_ABORT*)
  end;

end.

