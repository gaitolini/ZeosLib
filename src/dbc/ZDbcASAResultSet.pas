{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Sybase SQL Anywhere Connectivity Classes        }
{                                                         }
{        Originally written by Sergey Merkuriev           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcASAResultSet;

interface

{$I ZDbc.inc}
{$IFNDEF ZEOS_DISABLE_ASA}

uses
{$IFDEF USE_SYNCOMMONS}
  SynCommons, SynTable,
{$ENDIF USE_SYNCOMMONS}
  {$IFDEF WITH_TOBJECTLIST_REQUIRES_SYSTEM_TYPES}System.Types, System.Contnrs,{$ENDIF}
  {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings, {$ENDIF} //need for inlined FloatToRaw
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, FmtBCD,
  ZSysUtils, ZDbcIntfs, ZDbcResultSet, ZDbcASA, ZCompatibility,
  ZDbcResultSetMetadata, ZDbcASAUtils, ZMessages, ZPlainASAConstants,
  ZPLainASADriver;

type

  {** Implements ASA ResultSet. }
  TZASAAbstractResultSet = class(TZAbstractReadOnlyResultSet_A, IZResultSet)
  private
    FSQLDA: PASASQLDA;
    FCachedBlob: boolean;
    FFetchStat: Integer;
    FCursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF};
    FStmtNum: SmallInt;
    FSqlData: IZASASQLDA;
    FASAConnection: IZASAConnection;
    FPlainDriver: TZASAPlainDriver;
  private
    procedure CheckIndex(const Index: Word);
    procedure CheckRange(const Index: Word);
  protected
    procedure Open; override;
  public
    constructor Create(const Statement: IZStatement; const SQL: string;
      StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF};
      const SqlData: IZASASQLDA; CachedBlob: boolean);

    procedure BeforeClose; override;
    procedure AfterClose; override;
    procedure ResetCursor; override;

    function IsNull(ColumnIndex: Integer): Boolean;
    function GetBoolean(ColumnIndex: Integer): Boolean;
    function GetInt(ColumnIndex: Integer): Integer;
    function GetUInt(ColumnIndex: Integer): Cardinal;
    function GetLong(ColumnIndex: Integer): Int64;
    function GetULong(ColumnIndex: Integer): UInt64;
    function GetFloat(ColumnIndex: Integer): Single;
    function GetDouble(ColumnIndex: Integer): Double;
    function GetCurrency(ColumnIndex: Integer): Currency;
    procedure GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
    procedure GetGUID(ColumnIndex: Integer; var Result: TGUID);
    function GetBytes(ColumnIndex: Integer; out Len: NativeUInt): PByte; overload;
    procedure GetDate(ColumnIndex: Integer; Var Result: TZDate); reintroduce; overload;
    procedure GetTime(ColumnIndex: Integer; Var Result: TZTime); reintroduce; overload;
    procedure GetTimestamp(ColumnIndex: Integer; Var Result: TZTimeStamp); reintroduce; overload;
    function GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar; overload;
    function GetPWideChar(ColumnIndex: Integer; out Len: NativeUInt): PWideChar; overload;
    function GetBlob(ColumnIndex: Integer): IZBlob;

    property SQLData: IZASASQLDA read FSQLData;
    {$IFDEF USE_SYNCOMMONS}
    procedure ColumnsToJSON(JSONWriter: TJSONWriter; JSONComposeOptions: TZJSONComposeOptions);
    {$ENDIF USE_SYNCOMMONS}
  end;

  TZASAParamererResultSet = Class(TZASAAbstractResultSet)
  public
    constructor Create(const Statement: IZStatement; const SQL: string;
      var StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}; const SqlData: IZASASQLDA;
      CachedBlob: boolean);
    function Next: Boolean; override;
  end;

  TZASANativeResultSet = Class(TZASAAbstractResultSet)
  public
    function Last: Boolean; override;
    function MoveAbsolute(Row: Integer): Boolean; override;
    function MoveRelative(Rows: Integer): Boolean; override;
    function Previous: Boolean; override;
    function Next: Boolean; override;
  end;
  (*
  TZASACachedResultSet = Class(TZASANativeResultSet)
  private
    FInsert: Boolean;
    FUpdate: Boolean;
    FDelete: Boolean;
    FUpdateSqlData: IZASASQLDA;
    procedure PrepareUpdateSQLData;
  public
    constructor Create(const Statement: IZStatement; const SQL: string;
      var StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}; const SqlData: IZASASQLDA;
      CachedBlob: boolean);

    procedure BeforeClose; override;

    function RowUpdated: Boolean; override;
    function RowInserted: Boolean; override;
    function RowDeleted: Boolean; override;

    procedure UpdateNull(ColumnIndex: Integer);
    procedure UpdateBoolean(ColumnIndex: Integer; const Value: Boolean);
    procedure UpdateByte(ColumnIndex: Integer; const Value: Byte);
    procedure UpdateShort(ColumnIndex: Integer; const Value: ShortInt);
    procedure UpdateWord(ColumnIndex: Integer; const Value: Word);
    procedure UpdateSmall(ColumnIndex: Integer; const Value: SmallInt);
    procedure UpdateUInt(ColumnIndex: Integer; const Value: LongWord);
    procedure UpdateInt(ColumnIndex: Integer; const Value: Integer);
    procedure UpdateULong(ColumnIndex: Integer; const Value: UInt64);
    procedure UpdateLong(ColumnIndex: Integer; const Value: Int64);
    procedure UpdateFloat(ColumnIndex: Integer; const Value: Single);
    procedure UpdateDouble(ColumnIndex: Integer; const Value: Double);
    procedure UpdateBigDecimal(ColumnIndex: Integer; const Value: TBCD);
    procedure UpdateString(ColumnIndex: Integer; const Value: String);
    procedure UpdateUnicodeString(ColumnIndex: Integer; const Value: ZWideString);
    procedure UpdateBytes(ColumnIndex: Integer; const Value: TBytes);
    procedure UpdateDate(ColumnIndex: Integer; const Value: TDateTime);
    procedure UpdateTime(ColumnIndex: Integer; const Value: TDateTime);
    procedure UpdateTimestamp(ColumnIndex: Integer; const Value: TDateTime);
    procedure UpdateAsciiStream(ColumnIndex: Integer; const Value: TStream);
    procedure UpdateUnicodeStream(ColumnIndex: Integer; const Value: TStream);
    procedure UpdateBinaryStream(ColumnIndex: Integer; const Value: TStream);

    procedure InsertRow; override;
    procedure UpdateRow; override;
    procedure DeleteRow; override;
    procedure RefreshRow; override;
    procedure CancelRowUpdates; override;
    procedure MoveToInsertRow; override;
    procedure MoveToCurrentRow; override;

    function MoveAbsolute(Row: Integer): Boolean; override;
    function MoveRelative(Rows: Integer): Boolean; override;
  End; *)

  {** Implements external clob wrapper object for ASA. }
  TZASAClob = class(TZAbstractClob)
  public
    constructor Create(const SqlData: IZASASQLDA; const ColID: Integer;
      Const ConSettings: PZConSettings);
  end;

{$ENDIF ZEOS_DISABLE_ASA}
implementation
{$IFNDEF ZEOS_DISABLE_ASA}

uses
{$IFNDEF FPC}
  Variants,
{$ENDIF}
 Math, ZFastCode, ZDbcLogging, ZEncoding, ZClasses, ZDbcUtils;

{ TZASAResultSet }

{$IFDEF USE_SYNCOMMONS}
procedure TZASAAbstractResultSet.ColumnsToJSON(JSONWriter: TJSONWriter;
  JSONComposeOptions: TZJSONComposeOptions);
var L: NativeUInt;
    P: Pointer;
    C, H, I: SmallInt;
    Blob: IZBlob;
begin
  //init
  if JSONWriter.Expand then
    JSONWriter.Add('{');
  if Assigned(JSONWriter.Fields) then
    H := High(JSONWriter.Fields) else
    H := High(JSONWriter.ColNames);
  for I := 0 to H do begin
    if Pointer(JSONWriter.Fields) = nil then
      C := I else
      C := JSONWriter.Fields[i];
    {$R-}
    with FSQLDA.sqlvar[C] do
      if (sqlind <> nil) and (sqlind^ < 0) then
        if JSONWriter.Expand then begin
          if not (jcsSkipNulls in JSONComposeOptions) then begin
            JSONWriter.AddString(JSONWriter.ColNames[I]);
            JSONWriter.AddShort('null,')
          end;
        end else
          JSONWriter.AddShort('null,')
      else begin
        if JSONWriter.Expand then
          JSONWriter.AddString(JSONWriter.ColNames[I]);
        case sqlType and $FFFE of
          DT_NOTYPE           : JSONWriter.AddShort('""');
          DT_SMALLINT         : JSONWriter.Add(PSmallint(sqldata)^);
          DT_INT              : JSONWriter.Add(PInteger(sqldata)^);
          //DT_DECIMAL bound to double
          DT_FLOAT            : JSONWriter.AddSingle(PSingle(sqldata)^);
          DT_DOUBLE           : JSONWriter.AddDouble(PDouble(sqldata)^);
          //DT_DATE bound to TIMESTAMP_STRUCT
          DT_STRING,
          DT_FIXCHAR,
          DT_VARCHAR          : begin
                                  JSONWriter.Add('"');
                                  if ConSettings^.ClientCodePage^.CP = zCP_UTF8 then
                                    JSONWriter.AddJSONEscape(@PZASASQLSTRING(sqlData).data[0], PZASASQLSTRING(sqlData).length)
                                  else begin
                                    FUniTemp := PRawToUnicode(@PZASASQLSTRING(sqlData).data[0], PZASASQLSTRING(sqlData).length, ConSettings^.ClientCodePage^.CP);
                                    JSONWriter.AddJSONEscapeW(Pointer(FUniTemp), Length(FUniTemp));
                                  end;
                                  JSONWriter.Add('"');
                                end;
          DT_LONGVARCHAR      : begin
                                  JSONWriter.Add('"');
                                  blob := TZASAClob.Create(FsqlData, C, ConSettings);
                                  P := blob.GetPAnsiChar(zCP_UTF8);
                                  JSONWriter.AddJSONEscape(P, blob.Length);
                                  JSONWriter.Add('"');
                                end;
          DT_TIME,
          DT_TIMESTAMP,
          DT_TIMESTAMP_STRUCT : begin
                                  if jcoMongoISODate in JSONComposeOptions then
                                    JSONWriter.AddShort('ISODate("')
                                  else if jcoDATETIME_MAGIC in JSONComposeOptions then
                                    JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                  else
                                    JSONWriter.Add('"');
                                  if PZASASQLDateTime(sqlData).Year < 0 then
                                    JSONWriter.Add('-');
                                  if (TZColumnInfo(ColumnsInfo[C]).ColumnType <> stTime) then begin
                                    DateToIso8601PChar(@FTinyBuffer[0], True, Abs(PZASASQLDateTime(sqlData).Year),
                                    PZASASQLDateTime(sqlData).Month + 1, PZASASQLDateTime(sqlData).Day);
                                    JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],10);
                                  end else if jcoMongoISODate in JSONComposeOptions then
                                    JSONWriter.AddShort('0000-00-00');
                                  if (TZColumnInfo(ColumnsInfo[C]).ColumnType <> stDate) then begin
                                    TimeToIso8601PChar(@FTinyBuffer[0], True, PZASASQLDateTime(sqlData).Hour,
                                    PZASASQLDateTime(sqlData).Minute, PZASASQLDateTime(sqlData).Second,
                                    PZASASQLDateTime(sqlData).MicroSecond div 1000, 'T', jcoMilliseconds in JSONComposeOptions);
                                    JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],8 + (4*Ord(jcoMilliseconds in JSONComposeOptions)));
                                  end;
                                  if jcoMongoISODate in JSONComposeOptions
                                  then JSONWriter.AddShort('Z)"')
                                  else JSONWriter.Add('"');
                                end;
          DT_BINARY           : JSONWriter.WrBase64(@PZASASQLSTRING(sqlData).data[0], PZASASQLSTRING(sqlData).length, True);
          DT_LONGBINARY       : begin
                                  P := nil;
                                  try
                                    FSqlData.ReadBlobToMem(C, P, L{%H-});
                                    JSONWriter.WrBase64(P, L, True);
                                  finally
                                    FreeMem(P);
                                  end;
                                end;
          //DT_VARIABLE: ?
          DT_TINYINT          : JSONWriter.Add(PByte(sqldata)^);
          DT_BIGINT           : JSONWriter.Add(PInt64(sqldata)^);
          DT_UNSINT           : JSONWriter.AddU(PCardinal(sqldata)^);
          DT_UNSSMALLINT      : JSONWriter.AddU(PWord(sqldata)^);
          DT_UNSBIGINT        : JSONWriter.AddQ(PUInt64(sqldata)^);
          DT_BIT              : JSONWriter.AddShort(JSONBool[PByte(sqldata)^ <> 0]);
          DT_NSTRING,
          DT_NFIXCHAR,
          DT_NVARCHAR         : begin
                                  JSONWriter.Add('"');
                                  if ConSettings^.ClientCodePage^.CP = zCP_UTF8 then
                                    JSONWriter.AddJSONEscape(@PZASASQLSTRING(sqlData).data[0], PZASASQLSTRING(sqlData).length)
                                  else begin
                                    FUniTemp := PRawToUnicode(@PZASASQLSTRING(sqlData).data[0], PZASASQLSTRING(sqlData).length, ConSettings^.ClientCodePage^.CP);
                                    JSONWriter.AddJSONEscapeW(Pointer(FUniTemp), Length(FUniTemp));
                                  end;
                                  JSONWriter.Add('"');
                                end;
          DT_LONGNVARCHAR     : begin
                                JSONWriter.Add('"');
                                blob := TZASAClob.Create(FsqlData, C, ConSettings);
                                P := blob.GetPAnsiChar(zCP_UTF8);
                                JSONWriter.AddJSONEscape(P, blob.Length);
                                JSONWriter.Add('"');
                              end;
          else
            FSqlData.CreateException(Format(SErrorConvertionField,
              [ FSqlData.GetFieldName(C), ConvertASATypeToString(sqlType)]));
        end;
        JSONWriter.Add(',');
      end;
  end;
  if jcoEndJSONObject in JSONComposeOptions then begin
    JSONWriter.CancelLastComma; // cancel last ','
    if JSONWriter.Expand then
      JSONWriter.Add('}');
  end;
end;
{$ENDIF USE_SYNCOMMONS}

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param Statement a related SQL statement object.
  @param handle a Interbase6 database connect handle.
  @param the statement previously prepared
  @param the sql out data previously allocated
  @param the Interbase sql dialect
}
constructor TZASAAbstractResultSet.Create(const Statement: IZStatement;
  const SQL: string; StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF};
  const SqlData: IZASASQLDA; CachedBlob: boolean);
begin
  inherited Create(Statement, SQL, nil,Statement.GetConnection.GetConSettings);

  FFetchStat := 0;
  FSqlData := SqlData;
  Self.FSQLDA := FSqlData.GetData;
  FCursorName := CursorName;
  FCachedBlob := CachedBlob;
  FASAConnection := Statement.GetConnection as IZASAConnection;
  FPlainDriver := TZASAPlainDriver(FASAConnection.GetIZPlainDriver.GetInstance);
  FStmtNum := StmtNum;
  ResultSetType := rtScrollSensitive;
  ResultSetConcurrency := rcUpdatable;

  Open;
end;

{**
   Check range count fields. If index out of range raised exception.
   @param Index the index field
}
procedure TZASAAbstractResultSet.CheckIndex(const Index: Word);
begin
  Assert(Assigned(FSQLDA), 'SQLDA not initialized.');
  Assert(Index < Word(FSQLDA.sqld), 'Out of Range.');
end;

procedure TZASAAbstractResultSet.CheckRange(const Index: Word);
begin
  CheckIndex(Index);
  Assert(Assigned(FSQLDA.sqlVar[Index].sqlData),
    'No memory for variable in SQLDA.');
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZASAAbstractResultSet.IsNull(ColumnIndex: Integer): Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  CheckRange(ColumnIndex);
  with FSQLDA.sqlvar[ColumnIndex] do
    Result := Assigned(sqlind) and (sqlind^ < 0);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZASAAbstractResultSet.GetBoolean(ColumnIndex: Integer): Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBoolean);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := False;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^ <> 0;
        DT_BIT         : Result := PByte(sqldata)^ <> 0;
        DT_SMALLINT    : Result := PSmallint(sqldata)^ <> 0;
        DT_UNSSMALLINT : Result := PWord(sqldata)^ <> 0;
        DT_INT         : Result := PInteger(sqldata)^ <> 0;
        DT_UNSINT      : Result := PCardinal(sqldata)^ <> 0;
        DT_BIGINT      : Result := PInt64(sqldata)^ <> 0;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^ <> 0;
        DT_FLOAT       : Result := PSingle(sqldata)^ <> 0;
        DT_DOUBLE      : Result := PDouble(sqldata)^ <> 0;
        DT_VARCHAR     :Result := StrToBoolEx(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PAnsiChar(@PZASASQLSTRING(sqlData).data[0])+PZASASQLSTRING(sqlData).length, True);
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            Result := StrToBoolEx(FRawTemp);
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the address of value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> array in the Java programming language.
  The bytes represent the raw values returned by the driver.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len return the length of the addressed buffer
  @return the adressed column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZASAAbstractResultSet.GetBytes(ColumnIndex: Integer;
  out Len: NativeUInt): PByte;
begin
  {$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBytes);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := nil;
  Len := 0;
  if not LastWasNull then  with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
    case sqlType and $FFFE of
      DT_BINARY: begin
          Result := @PZASASQLSTRING(sqlData).data;
          Len := PZASASQLSTRING(sqlData).length;
        end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>Cardinal</code> in Pascal.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZASAAbstractResultSet.GetUInt(ColumnIndex: Integer): Cardinal;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLongWord);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(sqldata)^);
        DT_DOUBLE      : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(sqldata)^);
        DT_VARCHAR:
           begin
             ZSetString(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PZASASQLSTRING(sqlData).length, FRawTemp{%H-});
             Result := RawToInt64(FRawTemp);
           end;
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            Result := ZFastCode.RawToInt64(FRawTemp);
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZASAAbstractResultSet.GetInt(ColumnIndex: Integer): Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stInteger);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(sqldata)^);
        DT_DOUBLE      : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(sqldata)^);
        DT_VARCHAR:
           begin
             ZSetString(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PZASASQLSTRING(sqlData).length, FRawTemp{%H-});
             Result := RawToInt(FRawTemp);
           end;
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            Result := ZFastCode.RawToInt(FRawTemp);
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
function TZASAAbstractResultSet.GetULong(ColumnIndex: Integer): UInt64;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stULong);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(sqldata)^);
        DT_DOUBLE      : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(sqldata)^);
        DT_VARCHAR:
           begin
             ZSetString(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PZASASQLSTRING(sqlData).length, FRawTemp{%H-});
             Result := RawToUInt64(FRawTemp);
           end;
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            Result := ZFastCode.RawToUInt64(FRawTemp);
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZASAAbstractResultSet.GetLong(ColumnIndex: Integer): Int64;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(sqldata)^);
        DT_DOUBLE      : Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(sqldata)^);
        DT_VARCHAR:
           begin
             ZSetString(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PZASASQLSTRING(sqlData).length, FRawTemp{%H-});
             Result := RawToInt64(FRawTemp);
           end;
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            Result := ZFastCode.RawToInt64(FRawTemp);
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZASAAbstractResultSet.GetFloat(ColumnIndex: Integer): Single;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stFloat);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := PSingle(sqldata)^;
        DT_DOUBLE      : Result := PDouble(sqldata)^;
        DT_VARCHAR     : SQLStrToFloatDef(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), 0, Result, PZASASQLSTRING(sqlData).length);
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            SQLStrToFloatDef(PAnsiChar(Pointer(FRawTemp)), 0, Result, Length(fRawTemp));
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(columnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>UUID</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>Zero-UUID</code>
}
procedure TZASAAbstractResultSet.GetGUID(ColumnIndex: Integer;
  var Result: TGUID);
label Fail;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stGUID);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    FillChar(Result, SizeOf(TGUID), #0)
  else with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do begin
    case sqlType and $FFFE of
      DT_VARCHAR    : if (PZASASQLSTRING(sqlData).length = 36) or (PZASASQLSTRING(sqlData).length = 38)
                      then ValidGUIDToBinary(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), @Result.D1)
                      else goto Fail;
      DT_BINARY     : if PZASASQLSTRING(sqlData).length = SizeOf(TGUID) then
                      Move(PZASASQLSTRING(sqlData).data[0], Result.D1, SizeOf(TGUID))
                      else goto Fail;
    else begin
fail:  FillChar(Result, SizeOf(TGUID), #0);
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZASAAbstractResultSet.GetDouble(ColumnIndex: Integer): Double;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDouble);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := PSingle(sqldata)^;
        DT_DOUBLE      : Result := PDouble(sqldata)^;
        DT_VARCHAR     : SQLStrToFloatDef(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), 0, Result, PZASASQLSTRING(sqlData).length);
        DT_LONGVARCHAR :
          begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            SQLStrToFloatDef(PAnsiChar(Pointer(FRawTemp)), 0, Result, Length(fRawTemp));
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(columnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.BigDecimal</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param scale the number of digits to the right of the decimal point
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZASAAbstractResultSet.GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBigDecimal);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    FillChar(Result, SizeOf(TBCD), #0)
  else with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
    case sqlType and $FFFE of
      DT_TINYINT     : ScaledOrdinal2BCD(SmallInt(PShortInt(sqldata)^), 0, Result);
      DT_BIT         : ScaledOrdinal2BCD(Word(PByte(sqldata)^), 0, Result, False);
      DT_SMALLINT    : ScaledOrdinal2BCD(PSmallint(sqldata)^, 0, Result);
      DT_UNSSMALLINT : ScaledOrdinal2BCD(PWord(sqldata)^, 0, Result, False);
      DT_INT         : ScaledOrdinal2BCD(PInteger(sqldata)^, 0, Result);
      DT_UNSINT      : ScaledOrdinal2BCD(PCardinal(sqldata)^, 0, Result, False);
      DT_BIGINT      : ScaledOrdinal2BCD(PInt64(sqldata)^, 0, Result);
      DT_UNSBIGINT   : ScaledOrdinal2BCD(PUInt64(sqldata)^, 0, Result, False);
      DT_FLOAT       : Double2BCD(PSingle(sqldata)^, Result);
      DT_DOUBLE      : Double2BCD(PDouble(sqldata)^, Result);
      DT_VARCHAR     : TryRawToBCD(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), PZASASQLSTRING(sqlData).length, Result, '.');
      DT_LONGVARCHAR : begin
          FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
          TryRawToBCD(FRawTemp, Result, '.');
        end;
    else
      FSqlData.CreateException(Format(SErrorConvertionField,
        [ FSqlData.GetFieldName(columnIndex), ConvertASATypeToString(sqlType)]));
    end;
end;

function TZASAAbstractResultSet.GetCurrency(ColumnIndex: Integer): Currency;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stCurrency);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := 0;
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_TINYINT     : Result := PShortInt(sqldata)^;
        DT_BIT         : Result := PByte(sqldata)^;
        DT_SMALLINT    : Result := PSmallint(sqldata)^;
        DT_UNSSMALLINT : Result := PWord(sqldata)^;
        DT_INT         : Result := PInteger(sqldata)^;
        DT_UNSINT      : Result := PCardinal(sqldata)^;
        DT_BIGINT      : Result := PInt64(sqldata)^;
        DT_UNSBIGINT   : Result := PUInt64(sqldata)^;
        DT_FLOAT       : Result := PSingle(sqldata)^;
        DT_DOUBLE      : Result := PDouble(sqldata)^;
        DT_VARCHAR     : SQLStrToFloatDef(PAnsiChar(@PZASASQLSTRING(sqlData).data[0]), 0, Result, PZASASQLSTRING(sqlData).length);
        DT_LONGVARCHAR : begin
            FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
            SQLStrToFloatDef(PAnsiChar(Pointer(FRawTemp)), 0, Result, length(FRawTemp));
          end;
      else
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(columnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZASAAbstractResultSet.GetDate(ColumnIndex: Integer; Var Result: TZDate);
var
  P: PAnsiChar;
  Len: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDate);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_VARCHAR:
          begin
            P := @PZASASQLSTRING(sqlData).data[0];
            Len := PZASASQLSTRING(sqlData).length;
            LastWasNull := not TryPCharToDate(P, Len, ConSettings^.ReadFormatSettings, Result);
          end;
       DT_TIMESTAMP_STRUCT: begin
            Result.Year := Abs(PZASASQLDateTime(sqlData).Year);
            Result.Month := PZASASQLDateTime(sqlData).Month+1;
            Result.Day := PZASASQLDateTime(sqlData).Day;
            Result.IsNegative := PZASASQLDateTime(sqlData).Year < 0;
          end;
    else
      FSqlData.CreateException(Format(SErrorConvertionField,
        [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZASAAbstractResultSet.GetTime(ColumnIndex: Integer; Var Result: TZTime);
var
  P: PAnsiChar;
  Len: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_VARCHAR:
          begin
            P := @PZASASQLSTRING(sqlData).data[0];
            Len := PZASASQLSTRING(sqlData).length;
            LastWasNull := not TryPCharToTime(P, Len, ConSettings^.ReadFormatSettings, Result);
          end;
        DT_TIMESTAMP_STRUCT:
          begin
            Result.Hour := PZASASQLDateTime(sqlData)^.Hour;
            Result.Minute := PZASASQLDateTime(sqlData)^.Minute;
            Result.Second := PZASASQLDateTime(sqlData)^.Second;
            Result.Fractions := PZASASQLDateTime(sqlData).MicroSecond * 1000;
          end;
        else
          FSqlData.CreateException(Format(SErrorConvertionField,
            [FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Timestamp</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
  value returned is <code>null</code>
  @exception SQLException if a database access error occurs
}
procedure TZASAAbstractResultSet.GetTimestamp(ColumnIndex: Integer; Var Result: TZTimeStamp);
var
  P: PAnsiChar;
  Len: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTimeStamp);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if not LastWasNull then
    with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
      case sqlType and $FFFE of
        DT_VARCHAR:
          begin
            P := @PZASASQLSTRING(sqlData).data[0];
            Len := PZASASQLSTRING(sqlData).length;
            LastWasNull := not TryPCharToTimeStamp(P, Len, ConSettings^.ReadFormatSettings, Result);
          end;
        DT_TIMESTAMP_STRUCT: begin
            Result.Year := Abs(PZASASQLDateTime(sqlData).Year);
            Result.Month := PZASASQLDateTime(sqlData).Month+1;
            Result.Day := PZASASQLDateTime(sqlData).Day;
            Result.Hour := PZASASQLDateTime(sqlData)^.Hour;
            Result.Minute := PZASASQLDateTime(sqlData)^.Minute;
            Result.Second := PZASASQLDateTime(sqlData)^.Second;
            PInt64(PAnsiChar(@Result.TimeZoneHour)-2)^ := 0;
            Result.Fractions := PZASASQLDateTime(sqlData).MicroSecond * 1000;
            Result.IsNegative := PZASASQLDateTime(sqlData).Year < 0;
          end;
        else
          FSqlData.CreateException(Format(SErrorConvertionField,
            [FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>TZAnsiRec</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the Length of the PAnsiChar String
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZASAAbstractResultSet.GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar;
label set_Results;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := nil;
  Len := 0;
  if not LastWasNull then
  with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do begin
    case sqlType and $FFFE of
      DT_TINYINT    : begin
                        IntToRaw(Cardinal(PByte(sqldata)^), PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_BIT        : if PByte(sqldata)^ <> 0 then begin
                        Result := Pointer(BoolStrsRaw[True]);
                        Len := 4;
                      end else begin
                        Result := Pointer(BoolStrsRaw[False]);
                        Len := 5;
                      end;
      DT_SMALLINT   : begin
                        IntToRaw(Integer(PSmallInt(sqldata)^), PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSSMALLINT: begin
                        IntToRaw(Cardinal(PWord(sqldata)^), PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_INT        : begin
                        IntToRaw(PInteger(sqldata)^, PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSINT     : begin
                        IntToRaw(PCardinal(sqldata)^, PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_BIGINT     : begin
                        IntToRaw(PInt64(sqldata)^, PAnsiChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSBIGINT  : begin
                        IntToRaw(PUInt64(sqldata)^, PAnsiChar(@FTinyBuffer[0]), @Result);
set_Results:            Len := Result - PAnsiChar(@FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_FLOAT      : begin
                        Len := FloatToSQLRaw(PSingle(sqldata)^, @FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_DOUBLE     : begin
                        Len := FloatToSQLRaw(PDouble(sqldata)^, @FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_VARCHAR,
      DT_BINARY     : begin
                        Result := @PZASASQLSTRING(sqlData).data[0];
                        Len := PZASASQLSTRING(sqlData).length;
                      end;
      DT_LONGBINARY,
      DT_LONGVARCHAR: begin
                        FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
                        Len := Length(FRawTemp);
                        if Len = 0
                        then Result := PEmptyAnsiString
                        else Result := Pointer(FRawTemp);
                      end;
      DT_TIMESTAMP_STRUCT : begin
                      Result := @FTinyBuffer[0];
                      case TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]).ColumnType of
                        stDate: Len := DateToRaw(PZASASQLDateTime(SQLData).Year,
                                  PZASASQLDateTime(SQLData).Month +1, PZASASQLDateTime(SQLData).Day,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, False);
                        stTime: Len := TimeToRaw(PZASASQLDateTime(SQLData).Hour,
                                  PZASASQLDateTime(SQLData).Minute, PZASASQLDateTime(SQLData).Second,
                                  PZASASQLDateTime(SQLData).MicroSecond * 1000,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, False);
                        else    Len := DateTimeToRaw(PZASASQLDateTime(SQLData).Year,
                                  PZASASQLDateTime(SQLData).Month +1, PZASASQLDateTime(SQLData).Day,
                                  PZASASQLDateTime(SQLData).Hour, PZASASQLDateTime(SQLData).Minute,
                                  PZASASQLDateTime(SQLData).Second, PZASASQLDateTime(SQLData).MicroSecond * 1000,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, False);
                        end;
                      end;

    else begin
        Result := nil;
        Len := 0;
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
    end;
  end;
end;

function TZASAAbstractResultSet.GetPWideChar(ColumnIndex: Integer;
  out Len: NativeUInt): PWideChar;
label set_Results, set_from_uni;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  Result := nil;
  Len := 0;
  if not LastWasNull then
  with FSQLDA.sqlvar[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}] do
    case sqlType and $FFFE of
      DT_TINYINT    : begin
                        IntToUnicode(Cardinal(PByte(sqldata)^), PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_BIT        : if PByte(sqldata)^ <> 0 then begin
                        Result := Pointer(BoolStrsRaw[True]);
                        Len := 4;
                      end else begin
                        Result := Pointer(BoolStrsRaw[False]);
                        Len := 5;
                      end;
      DT_SMALLINT   : begin
                        IntToUnicode(Integer(PSmallInt(sqldata)^), PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSSMALLINT: begin
                        IntToUnicode(Cardinal(PWord(sqldata)^), PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_INT        : begin
                        IntToUnicode(PInteger(sqldata)^, PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSINT     : begin
                        IntToUnicode(PCardinal(sqldata)^, PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_BIGINT     : begin
                        IntToUnicode(PInt64(sqldata)^, PWideChar(@FTinyBuffer[0]), @Result);
                        goto set_Results;
                      end;
      DT_UNSBIGINT  : begin
                        IntToUnicode(PUInt64(sqldata)^, PWideChar(@FTinyBuffer[0]), @Result);
set_Results:            Len := Result - PWideChar(@FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_FLOAT      : begin
                        Len := FloatToSQLUnicode(PSingle(sqldata)^, @FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_DOUBLE     : begin
                        Len := FloatToSQLUnicode(PDouble(sqldata)^, @FTinyBuffer[0]);
                        Result := @FTinyBuffer[0];
                      end;
      DT_VARCHAR    : begin
                        fUniTemp := PRawToUnicode(@PZASASQLSTRING(sqlData).data[0],
                          PZASASQLSTRING(sqlData).length, ConSettings.ClientCodePage.CP);
                        goto set_from_uni;
                      end;
      DT_BINARY     : begin
                        fUniTemp := Ascii7ToUnicodeString(@PZASASQLSTRING(sqlData).data[0],
                          PZASASQLSTRING(sqlData).length);
                        goto set_from_uni;
                      end;
      DT_LONGVARCHAR: begin
                        FSqlData.ReadBlobToString(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, FRawTemp);
                        FUniTemp := ZRawtoUnicode(FRawTemp, ConSettings.ClientCodePage.CP);
set_from_uni:           Len := Length(FUniTemp);
                        if Len = 0
                        then Result := PEmptyUnicodeString
                        else Result := Pointer(FUniTemp);
                      end;
      DT_TIMESTAMP_STRUCT : begin
                      Result := @FTinyBuffer[0];
                      case TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]).ColumnType of
                        stDate: Len := DateToUni(Abs(PZASASQLDateTime(SQLData).Year),
                                  PZASASQLDateTime(SQLData).Month +1, PZASASQLDateTime(SQLData).Day,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, PZASASQLDateTime(SQLData).Year < 0);
                        stTime: Len := TimeToUni(PZASASQLDateTime(SQLData).Hour,
                                  PZASASQLDateTime(SQLData).Minute, PZASASQLDateTime(SQLData).Second,
                                  PZASASQLDateTime(SQLData).MicroSecond * 1000,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, False);
                        else    Len := DateTimeToUni(Abs(PZASASQLDateTime(SQLData).Year),
                                  PZASASQLDateTime(SQLData).Month +1, PZASASQLDateTime(SQLData).Day,
                                  PZASASQLDateTime(SQLData).Hour, PZASASQLDateTime(SQLData).Minute,
                                  PZASASQLDateTime(SQLData).Second, PZASASQLDateTime(SQLData).MicroSecond * 1000,
                                  Result, ConSettings.ReadFormatSettings.DateTimeFormat, False, PZASASQLDateTime(SQLData).Year < 0);
                        end;
                      end;

    else begin
        Result := nil;
        Len := 0;
        FSqlData.CreateException(Format(SErrorConvertionField,
          [ FSqlData.GetFieldName(ColumnIndex), ConvertASATypeToString(sqlType)]));
      end;
    end;
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
function TZASAAbstractResultSet.GetBlob(ColumnIndex: Integer): IZBlob;
var
  TempBytes: TBytes;
  Buffer: Pointer;
  Len: NativeUint;
begin
  CheckBlobColumn(ColumnIndex);

  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := nil
  else case GetMetadata.GetColumnType(ColumnIndex) of
    stAsciiStream, stUnicodeStream:
      Result := TZASAClob.Create(FsqlData, ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, ConSettings);
    stBinaryStream:
      begin
        Buffer := nil; //satisfy FPC compiler
        FSqlData.ReadBlobToMem(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Buffer, Len{%H-});
        {$IFDEF WITH_MM_CAN_REALLOC_EXTERNAL_MEM}
        Result := TZAbstractBlob.Create;
        Result.SetBlobData(Buffer, Len); //no Move!
        {$ELSE}
        Result := TZAbstractBlob.CreateWithData(Buffer, Len);
        FreeMem(Buffer); //hmpf we need to move the memory
        {$ENDIF}
      end;
    stBytes:
      begin
        TempBytes := GetBytes(ColumnIndex);
        Result := TZAbstractBlob.CreateWithData(Pointer(TempBytes), Length(TempBytes));
      end;
    else begin
        Buffer := GetPAnsiChar(ColumnIndex, Len);
        Result := TZAbstractClob.CreateWithData(PAnsiChar(Buffer), Len,
          ConSettings^.ClientCodePage^.CP, ConSettings);
      end;
  end;
end;

{**
  Opens this recordset.
}
procedure TZASAAbstractResultSet.Open;
var
  i: Integer;
  FieldSqlType: TZSQLType;
  ColumnInfo: TZColumnInfo;
begin
  if FStmtNum = 0 then
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);

  ColumnsInfo.Clear;
  for i := 0 to FSqlData.GetFieldCount - 1 do begin
    ColumnInfo := TZColumnInfo.Create;
    with ColumnInfo, FSqlData  do
    begin
      FieldSqlType := GetFieldSqlType(I);
      ColumnLabel := GetFieldName(I);
      ColumnType := FieldSqlType;

      if FieldSqlType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream] then begin
        ColumnCodePage := ConSettings^.ClientCodePage^.CP;
        if ColumnType = stString then begin
          CharOctedLength := GetFieldLength(I);
          Precision := CharOctedLength div ConSettings^.ClientCodePage^.CharWidth;
        end else if FieldSQLType = stUnicodeString then begin
          Precision := GetFieldLength(I) div ConSettings^.ClientCodePage^.CharWidth;
          CharOctedLength := Precision shl 1;
        end;
      end else if FieldSqlType = stBytes then begin
        Precision := GetFieldLength(I);
        CharOctedLength := Precision;
      end;

        ColumnCodePage := High(Word);

      ReadOnly := False;

      if IsNullable(I) then
        Nullable := ntNullable
      else
        Nullable := ntNoNulls;
      Nullable := ntNullable;
      Signed := ColumnType = stBytes; //asa has no varbinary has it?

      Scale := GetFieldScale(I);
      AutoIncrement := False;
      //Signed := False;
      CaseSensitive := False;
    end;
    ColumnsInfo.Add(ColumnInfo);
  end;
  FSqlData.InitFields; //EH: init fields AFTER retrieving col infos!
  inherited Open;
end;

{**
  Releases this <code>ResultSet</code> object's database and
  JDBC resources immediately instead of waiting for
  this to happen when it is automatically closed.

  <P><B>Note:</B> A <code>ResultSet</code> object
  is automatically closed by the
  <code>Statement</code> object that generated it when
  that <code>Statement</code> object is closed,
  re-executed, or is used to retrieve the next result from a
  sequence of multiple results. A <code>ResultSet</code> object
  is also automatically closed when it is garbage collected.
}
procedure TZASAAbstractResultSet.AfterClose;
begin
  FCursorName := EmptyRaw;
  inherited AfterClose;
end;

procedure TZASAAbstractResultSet.BeforeClose;
begin
  FSqlData := nil;
  inherited BeforeClose; //Calls ResetCursor so db_close is called!
end;

{**
  Resets cursor position of this recordset to beginning and
  the overrides should reset the prepared handles.
}
procedure TZASAAbstractResultSet.ResetCursor;
begin
  if FCursorName <> EmptyRaw then
    FPLainDriver.dbpp_close(FASAConnection.GetDBHandle, Pointer(FCursorName));
  inherited ResetCursor;
end;

{ TZASAParamererResultSet }

constructor TZASAParamererResultSet.Create(const Statement: IZStatement;
  const SQL: string; var StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF};
  const SqlData: IZASASQLDA; CachedBlob: boolean);
begin
  inherited Create(Statement, SQL, StmtNum, CursorName, SqlData, CachedBlob);
  SetType(rtForwardOnly);
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZASAParamererResultSet.Next: Boolean;
begin
  Result := (not Closed) and (RowNo = 0);
  if Result then RowNo := 1;
end;

{ TZASANativeResultSet }

{**
  Moves the cursor to the last row in
  this <code>ResultSet</code> object.

  @return <code>true</code> if the cursor is on a valid row;
    <code>false</code> if there are no rows in the result set
}
function TZASANativeResultSet.Last: Boolean;
begin
  if LastRowNo <> MaxInt then
    Result := MoveAbsolute(LastRowNo)
  else
    Result := MoveAbsolute(-1);
end;

{**
  Moves the cursor to the given row number in
  this <code>ResultSet</code> object.

  <p>If the row number is positive, the cursor moves to
  the given row number with respect to the
  beginning of the result set.  The first row is row 1, the second
  is row 2, and so on.

  <p>If the given row number is negative, the cursor moves to
  an absolute row position with respect to
  the end of the result set.  For example, calling the method
  <code>absolute(-1)</code> positions the
  cursor on the last row; calling the method <code>absolute(-2)</code>
  moves the cursor to the next-to-last row, and so on.

  <p>An attempt to position the cursor beyond the first/last row in
  the result set leaves the cursor before the first row or after
  the last row.

  <p><B>Note:</B> Calling <code>absolute(1)</code> is the same
  as calling <code>first()</code>. Calling <code>absolute(-1)</code>
  is the same as calling <code>last()</code>.

  @return <code>true</code> if the cursor is on the result set;
    <code>false</code> otherwise
}
function TZASANativeResultSet.MoveAbsolute(Row: Integer): Boolean;
begin
  Result := False;
  if Closed or ((MaxRows > 0) and (Row >= MaxRows)) then
    Exit;

  FPlainDriver.dbpp_fetch(FASAConnection.GetDBHandle,
    Pointer(FCursorName), CUR_ABSOLUTE, Row, FSqlData.GetData, BlockSize, CUR_FORREGULAR);
  ZDbcASAUtils.CheckASAError(FPlainDriver,
    FASAConnection.GetDBHandle, lcOther, ConSettings);

  if FASAConnection.GetDBHandle.sqlCode <> SQLE_NOTFOUND then begin
    RowNo := Row;
    Result := True;
    FFetchStat := 0;
  end else begin
    FFetchStat := FASAConnection.GetDBHandle.sqlerrd[2];
    if FFetchStat > 0 then
      LastRowNo := Max(Row - FFetchStat, 0);
  end;
end;

{**
  Moves the cursor a relative number of rows, either positive or negative.
  Attempting to move beyond the first/last row in the
  result set positions the cursor before/after the
  the first/last row. Calling <code>relative(0)</code> is valid, but does
  not change the cursor position.

  <p>Note: Calling the method <code>relative(1)</code>
  is different from calling the method <code>next()</code>
  because is makes sense to call <code>next()</code> when there
  is no current row,
  for example, when the cursor is positioned before the first row
  or after the last row of the result set.

  @return <code>true</code> if the cursor is on a row;
    <code>false</code> otherwise
}
function TZASANativeResultSet.MoveRelative(Rows: Integer): Boolean;
begin
  Result := False;
  if Closed or ((RowNo > LastRowNo) or ((MaxRows > 0) and (RowNo >= MaxRows))) then
    Exit;
  FPlainDriver.dbpp_fetch(FASAConnection.GetDBHandle,
    Pointer(FCursorName), CUR_RELATIVE, Rows, FSqlData.GetData, BlockSize, CUR_FORREGULAR);
    ZDbcASAUtils.CheckASAError(FPlainDriver,
      FASAConnection.GetDBHandle, lcOther, ConSettings, EmptyRaw, SQLE_CURSOR_NOT_OPEN); //handle a known null resultset issue (cursor not open)
  if FASAConnection.GetDBHandle.sqlCode = SQLE_CURSOR_NOT_OPEN then Exit;
  if FASAConnection.GetDBHandle.sqlCode <> SQLE_NOTFOUND then begin
    //if (RowNo > 0) or (RowNo + Rows < 0) then
    RowNo := RowNo + Rows;
    if Rows > 0 then
      LastRowNo := RowNo;
    Result := True;
    FFetchStat := 0;
  end else begin
    FFetchStat := FASAConnection.GetDBHandle.sqlerrd[2];
    if (FFetchStat > 0) and (RowNo > 0) then
      LastRowNo := Max(RowNo + Rows - FFetchStat, 0);
    if Rows > 0 then
      RowNo := LastRowNo + 1;
  end;
end;

{**
  Moves the cursor to the previous row in this
  <code>ResultSet</code> object.

  <p><B>Note:</B> Calling the method <code>previous()</code> is not the same as
  calling the method <code>relative(-1)</code> because it
  makes sense to call</code>previous()</code> when there is no current row.

  @return <code>true</code> if the cursor is on a valid row;
    <code>false</code> if it is off the result set
}
function TZASANativeResultSet.Previous: Boolean;
begin
  Result := MoveRelative(-1);
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZASANativeResultSet.Next: Boolean;
begin
  Result := MoveRelative(1);
end;

(*
{ TZASACachedResultSet }

constructor TZASACachedResultSet.Create(const Statement: IZStatement; const SQL: string;
  var StmtNum: SmallInt; const CursorName: {$IFNDEF NO_ANSISTRING}AnsiString{$ELSE}RawByteString{$ENDIF}; const SqlData: IZASASQLDA;
  CachedBlob: boolean);
begin
  inherited Create(Statement, SQL, StmtNum, CursorName, SqlData, CachedBlob);
  FInsert := False;
  FUpdate := False;
  FDelete := False;
end;

procedure TZASACachedResultSet.PrepareUpdateSQLData;
begin
  FUpdate := not FInsert;
  if not Assigned(FUpdateSQLData) then
  begin
    FUpdateSQLData := TZASASQLDA.Create(FPlainDriver,
      FASAConnection.GetDBHandle, Pointer(FCursorName), ConSettings, FSQLData.GetFieldCount);
    FSQLDA := FUpdateSQLData.GetData;
    FSQLDA^.sqld := FSQLDA^.sqln;
  end
  else
    if FUpdateSQLData.GetFieldCount <> Self.FSqlData.GetFieldCount then
      FUpdateSQLData.AllocateSQLDA(FSQLData.GetFieldCount);
end;

procedure TZASACachedResultSet.BeforeClose;
begin
  FUpdateSQLData := nil;
  inherited BeforeClose;
end;

function TZASACachedResultSet.RowUpdated: Boolean;
begin
  Result := FUpdate;
end;

function TZASACachedResultSet.RowInserted: Boolean;
begin
  Result := FInsert;
end;

function TZASACachedResultSet.RowDeleted: Boolean;
begin
  Result := FDelete;
end;

procedure TZASACachedResultSet.UpdateNull(ColumnIndex: Integer);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateNull(ColumnIndex, True);
end;

procedure TZASACachedResultSet.UpdateBoolean(ColumnIndex: Integer; const Value: Boolean);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateBoolean(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateByte(ColumnIndex: Integer; const Value: Byte);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateByte(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateShort(ColumnIndex: Integer; const Value: ShortInt);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateSmall(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateWord(ColumnIndex: Integer; const Value: Word);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateWord(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateSmall(ColumnIndex: Integer; const Value: SmallInt);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateSmall(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateUInt(ColumnIndex: Integer; const Value: LongWord);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateUInt(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateInt(ColumnIndex: Integer; const Value: Integer);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateInt(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateULong(ColumnIndex: Integer; const Value: UInt64);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateULong(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateLong(ColumnIndex: Integer; const Value: Int64);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateLong(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateFloat(ColumnIndex: Integer; const Value: Single);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateFloat(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateDouble(ColumnIndex: Integer; const Value: Double);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateDouble(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateBigDecimal(ColumnIndex: Integer; const Value: TBCD);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateBigDecimal(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateString(ColumnIndex: Integer; const Value: String);
begin
  PrepareUpdateSQLData;
  FRawTemp := ConSettings^.ConvFuncs.ZStringToRaw(Value,
            ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP);
  FUpdateSqlData.UpdatePRaw(ColumnIndex, Pointer(FRawTemp), Length(FRawTemp));
end;

procedure TZASACachedResultSet.UpdateUnicodeString(ColumnIndex: Integer; const Value: ZWideString);
begin
  PrepareUpdateSQLData;
  FRawTemp := ZUnicodeToRaw(Value, ConSettings^.ClientCodePage^.CP);
  FUpdateSqlData.UpdatePRaw(ColumnIndex, Pointer(FRawTemp), Length(FRawTemp));
end;

procedure TZASACachedResultSet.UpdateBytes(ColumnIndex: Integer; const Value: TBytes);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateBytes(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateDate(ColumnIndex: Integer; const Value: TDateTime);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateDate(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateTime(ColumnIndex: Integer; const Value: TDateTime);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateTime(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateTimestamp(ColumnIndex: Integer; const Value: TDateTime);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.UpdateTimestamp(ColumnIndex, Value);
end;

procedure TZASACachedResultSet.UpdateAsciiStream(ColumnIndex: Integer; const Value: TStream);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.WriteBlob(ColumnIndex, Value, stAsciiStream);
end;

procedure TZASACachedResultSet.UpdateUnicodeStream(ColumnIndex: Integer; const Value: TStream);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.WriteBlob(ColumnIndex, Value, stUnicodeStream);
end;

procedure TZASACachedResultSet.UpdateBinaryStream(ColumnIndex: Integer; const Value: TStream);
begin
  PrepareUpdateSQLData;
  FUpdateSqlData.WriteBlob(ColumnIndex, Value, stBinaryStream);
end;

procedure TZASACachedResultSet.InsertRow;
begin
  if Assigned(FUpdateSQLData) and FInsert then
  begin
    FPlainDriver.dbpp_put_into(FASAConnection.GetDBHandle,
      PAnsiChar(FCursorName), FUpdateSQLData.GetData, FSQLData.GetData);
    ZDbcASAUtils.CheckASAError(FPlainDriver,
      FASAConnection.GetDBHandle, lcOther, ConSettings, 'Insert row');

    FInsert := false;
    Self.FSQLDA :=  FSqlData.GetData;
  end;
end;

procedure TZASACachedResultSet.UpdateRow;
begin
  if Assigned(FUpdateSQLData) and FUpdate then
  begin
    FPlainDriver.dbpp_update(FASAConnection.GetDBHandle,
      PAnsiChar(FCursorName), FUpdateSQLData.GetData);
    ZDbcASAUtils.CheckASAError(FPlainDriver,
      FASAConnection.GetDBHandle, lcOther, ConSettings, 'Update row:' + IntToRaw(RowNo));

    FUpdate := false;
    FUpdateSQLData.FreeSQLDA;
    FSQLDA := FSqlData.GetData;
  end;
end;

procedure TZASACachedResultSet.DeleteRow;
begin
  FPlainDriver.dbpp_delete(FASAConnection.GetDBHandle,
    Pointer(FCursorName), nil, nil);
  ZDbcASAUtils.CheckASAError(FPlainDriver,
    FASAConnection.GetDBHandle, lcOther, ConSettings, 'Delete row:' + IntToRaw(RowNo));

  FDelete := True;
  LastRowNo := LastRowNo - FASAConnection.GetDBHandle.sqlerrd[2];
end;

procedure TZASACachedResultSet.RefreshRow;
begin
  MoveRelative(0);
end;

procedure TZASACachedResultSet.CancelRowUpdates;
begin
  FUpdate := false;
  if Assigned(FUpdateSQLData) then
  begin
    FUpdateSQLData.FreeSQLDA;
    FSQLDA := FSqlData.GetData;
  end;
end;

procedure TZASACachedResultSet.MoveToInsertRow;
begin
  FInsert := true;
end;

procedure TZASACachedResultSet.MoveToCurrentRow;
begin
  FInsert := false;
  if Assigned(FUpdateSQLData) then
    FUpdateSQLData.FreeSQLDA;
end;

function TZASACachedResultSet.MoveAbsolute(Row: Integer): Boolean;
begin
  Result := inherited MoveAbsolute(Row);
  if Result then
  begin
    FDelete := False;
    FInsert := False;
    FUpdate := False;
  end;
end;

function TZASACachedResultSet.MoveRelative(Rows: Integer): Boolean;
begin
  Result := inherited MoveRelative(Rows);
  if Result then
  begin
    FDelete := False;
    FInsert := False;
    FUpdate := False;
  end;
end;
*)
{ TZASAClob }
constructor TZASAClob.Create(const SqlData: IZASASQLDA; const ColID: Integer;
  Const ConSettings: PZConSettings);
var
  Buffer: Pointer;
  Len: NativeUInt;
begin
  inherited CreateWithData(nil, 0, ConSettings^.ClientCodePage^.CP, ConSettings);
  SQLData.ReadBlobToMem(ColId, Buffer{%H-}, Len{%H-}, False);
  (PAnsiChar(Buffer)+Len)^ := #0; //add leading terminator
  FBlobData := Buffer;
  FBlobSize := Len+1;
end;

{$ENDIF ZEOS_DISABLE_ASA}
end.
