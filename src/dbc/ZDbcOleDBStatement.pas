{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           OleDB Database Connectivity Classes           }
{                                                         }
{            Originally written by EgonHugeist            }
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

unit ZDbcOleDBStatement;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_OLEDB} //if set we have an empty unit
{$IFDEF WIN64}
{$ALIGN 8}
{$ELSE}
{$ALIGN 2}
{$ENDIF}
{$MINENUMSIZE 4}

uses
  Types, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, ActiveX, FmtBCD,
  {$IF defined (WITH_INLINE) and defined(MSWINDOWS) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows, {$IFEND}
  ZCompatibility, ZSysUtils, ZOleDB, ZDbcLogging, ZDbcStatement, ZCollections,
  ZDbcOleDBUtils, ZDbcIntfs, ZVariant, ZDbcProperties, ZDbcUtils, ZClasses;

type
  IZOleDBPreparedStatement = Interface(IZStatement)
    ['{42A4A633-C63D-4EFA-A8BC-CF755237D0AD}']
    function GetInternalBufferSize: Integer;
    function GetMoreResultsIndicator: TZMoreResultsIndicator;
    procedure SetMoreResultsIndicator(Value: TZMoreResultsIndicator);
    function GetNewRowSet(var RowSet: IRowSet): Boolean;
  End;

  {** Implements Prepared ADO Statement. }
  TZAbstractOleDBStatement = class(TZUTF16ParamDetectPreparedStatement,
    IZOleDBPreparedStatement)
  private
    FMultipleResults: IMultipleResults;
    FZBufferSize, fStmtTimeOut: Integer;
    FCommand: ICommandText;
    FRowSize: NativeUInt;
    FDBParams: TDBParams;
    FRowsAffected: DBROWCOUNT;
    fMoreResultsIndicator: TZMoreResultsIndicator;
    FDBBINDSTATUSArray: TDBBINDSTATUSDynArray;
    FSupportsMultipleResultSets: Boolean;
    FOutParameterAvailibility: TOleEnum;
    FCallResultCache: TZCollection;
    procedure CheckError(Status: HResult; LoggingCategory: TZLoggingCategory;
       const DBBINDSTATUSArray: TDBBINDSTATUSDynArray = nil);
    procedure PrepareOpenedResultSetsForReusing;
    function FetchCallResults(var RowSet: IRowSet): Boolean;
    function GetFirstResultSet: IZResultSet;
    procedure ClearCallResultCache;
  public
    constructor Create(const Connection: IZConnection; const SQL: string;
      const Info: TStrings);
    destructor Destroy; override;

    procedure AfterClose; override;

    procedure Prepare; override;
    procedure Unprepare; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;

    function GetMoreResults: Boolean; override;

    procedure Cancel; override;
  public
    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable;
      var AError: EZSQLConnectionLost); override;
  protected //interface based!
    function CreateResultSet(const RowSet: IRowSet): IZResultSet; virtual;
    function GetInternalBufferSize: Integer;
    function GetMoreResultsIndicator: TZMoreResultsIndicator;
    procedure SetMoreResultsIndicator(Value: TZMoreResultsIndicator);
    function GetNewRowSet(var RowSet: IRowSet): Boolean;
  end;

  EZOleDBConvertError = class(EZSQLException);

  TZOleDBPreparedStatement = class(TZAbstractOleDBStatement, IZPreparedStatement)
  private
    FDBBindingArray: TDBBindingDynArray;
    FParamNamesArray: TStringDynArray;
    FDBUPARAMS: DB_UPARAMS;
    fDEFERPREPARE, //ole: if set the stmt will be prepared immediatelly and we'll try to decribe params
    fBindImmediat, //the param describe did fail! we'll try to bind the params with describe emulation
    fBindAgain, //param type or sizes have been changed need to create a new accessor handle
    fSupportsByRef: Boolean; //are by REF bound values supported by provider?
    FParamsBuffer: TByteDynArray; //our value buffer
    FParameterAccessor: IAccessor;
    FClientCP: Word;
    procedure CalcParamSetsAndBufferSize;
    procedure SetPWideChar(Index: Word; Value: PWideChar; Len: Cardinal);
    procedure SetPAnsiChar(Index: Word; Value: PAnsiChar; Len: Cardinal);
    procedure BindBatchDMLArrays;
    procedure BindRaw(Index: Integer; const Value: RawByteString; CP: Word);
    procedure Dyn_W_Convert(Index, Len: Integer; var Arr: PZArray);
    procedure SetOleCommandProperties;
    procedure InitVaryBind(Index: Integer; Len: Cardinal; _Type: DBTYPE);
    procedure InitFixedBind(Index: Integer; Size: Cardinal; _Type: DBTYPE);
    procedure InitDateBind(Index: Integer; SQLType: TZSQLType);
    procedure InitLongBind(Index: Integer; _Type: DBTYPE);
    procedure InternalBindSInt(Index: Integer; SQLType: TZSQLType; Value: NativeInt);
    procedure InternalBindUInt(Index: Integer; SQLType: TZSQLType; Value: NativeUInt);
    procedure InternalBindDbl(Index: Integer; SQLType: TZSQLType; const Value: Double);
    procedure SetBindOffsets;
  protected
    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
    procedure CheckParameterIndex(var Value: Integer); override;
    procedure SetParamCount(NewParamCount: Integer); override;
    procedure SetBindCapacity(Capacity: Integer); override;
    function CreateOleDBConvertErrror(Index: Integer; WType: Word; SQLType: TZSQLType): EZOleDBConvertError;
    procedure RaiseExceeded(Index: Integer);
    function CreateResultSet(const RowSet: IRowSet): IZResultSet; override;
    procedure AddParamLogValue(ParamIndex: Integer; SQLWriter: TZRawSQLStringWriter; Var Result: RawByteString); override;
    function GetCompareFirstKeywordStrings: PPreparablePrefixTokens; override;
  public
    constructor Create(const Connection: IZConnection; const SQL: string;
      const Info: TStrings);

    procedure Prepare; override;
  public
    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable;
      var AError: EZSQLConnectionLost); override;
  public //setters
    //a performance thing: direct dispatched methods for the interfaces :
    //https://stackoverflow.com/questions/36137977/are-interface-methods-always-virtual
    procedure SetNull(Index: Integer; {%H-}SQLType: TZSQLType);
    procedure SetBoolean(Index: Integer; Value: Boolean);
    procedure SetByte(Index: Integer; Value: Byte);
    procedure SetShort(Index: Integer; Value: ShortInt);
    procedure SetWord(Index: Integer; Value: Word);
    procedure SetSmall(Index: Integer; Value: SmallInt);
    procedure SetUInt(Index: Integer; Value: Cardinal);
    procedure SetInt(Index: Integer; Value: Integer);
    procedure SetULong(Index: Integer; const Value: UInt64);
    procedure SetLong(Index: Integer; const Value: Int64);
    procedure SetFloat(Index: Integer; Value: Single);
    procedure SetDouble(Index: Integer; const Value: Double);
    procedure SetCurrency(Index: Integer; const Value: Currency);
    procedure SetBigDecimal(Index: Integer; const Value: TBCD);

    procedure SetCharRec(Index: Integer; const Value: TZCharRec); reintroduce;
    procedure SetString(Index: Integer; const Value: String); reintroduce;
    {$IFNDEF NO_UTF8STRING}
    procedure SetUTF8String(Index: Integer; const Value: UTF8String); reintroduce;
    {$ENDIF}
    {$IFNDEF NO_ANSISTRING}
    procedure SetAnsiString(Index: Integer; const Value: AnsiString); reintroduce;
    {$ENDIF}
    procedure SetRawByteString(Index: Integer; const Value: RawByteString); reintroduce;
    procedure SetUnicodeString(Index: Integer; const Value: ZWideString); reintroduce;

    procedure SetDate(Index: Integer; const Value: TZDate); reintroduce; overload;
    procedure SetTime(Index: Integer; const Value: TZTime); reintroduce; overload;
    procedure SetTimestamp(Index: Integer; const Value: TZTimeStamp); reintroduce; overload;

    procedure SetBytes(Index: Integer; const Value: TBytes); reintroduce;
    procedure SetGUID(Index: Integer; const Value: TGUID); reintroduce;
    procedure SetBlob(Index: Integer; SQLType: TZSQLType; const Value: IZBlob); override{keep it virtual because of (set)ascii/uniocde/binary streams};

    procedure SetDataArray(ParameterIndex: Integer; const Value;
      const SQLType: TZSQLType; const VariantType: TZVariantType = vtNull); override;

    procedure RegisterParameter(Index: Integer; SQLType: TZSQLType;
      ParamType: TZProcedureColumnType; const Name: String = ''; PrecisionOrSize: LengthInt = 0;
      Scale: LengthInt = 0); override;
  end;

  TZOleDBStatement = class(TZAbstractOleDBStatement, IZStatement)
  public
    constructor Create(const Connection: IZConnection; const Info: TStrings);
  end;

  TZOleDBCallableStatementMSSQL = class(TZAbstractCallableStatement_W,
    IZCallableStatement)
  protected
    function CreateExecutionStatement(const StoredProcName: String): TZAbstractPreparedStatement; override;
  end;

{$ENDIF ZEOS_DISABLE_OLEDB} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_OLEDB} //if set we have an empty unit

uses
  Variants, Math,
  {$IFDEF WITH_UNIT_NAMESPACES}System.Win.ComObj{$ELSE}ComObj{$ENDIF}, TypInfo,
  {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings,{$ENDIF} DateUtils,
  ZDbcOleDB, ZDbcOleDBResultSet, ZEncoding, ZDbcOleDBMetadata,
  ZFastCode, ZDbcMetadata, ZMessages, ZDbcResultSet,
  ZDbcCachedResultSet, ZDbcGenericResolver;

var DefaultPreparableTokens: TPreparablePrefixTokens;
{ TZAbstractOleDBStatement }

{**
  Cancels this <code>Statement</code> object if both the DBMS and
  driver support aborting an SQL statement.
  This method can be used by one thread to cancel a statement that
  is being executed by another thread.
}
procedure TZAbstractOleDBStatement.Cancel;
begin
  if FCommand <> nil
  then CheckError(FCommand.Cancel, lcOther, nil)
  else inherited Cancel;
end;

procedure TZAbstractOleDBStatement.CheckError(Status: HResult;
  LoggingCategory: TZLoggingCategory;
  const DBBINDSTATUSArray: TDBBINDSTATUSDynArray = nil);
begin
  if DriverManager.HasLoggingListener and
     ((LoggingCategory = lcExecute) or (Ord(LoggingCategory) > ord(lcOther))) then
    DriverManager.LogMessage(LoggingCategory, ConSettings^.Protocol, ASQL);
  if Failed(Status) then
    OleDBCheck(Status, SQL, Self, DBBINDSTATUSArray);
end;

procedure TZAbstractOleDBStatement.ClearCallResultCache;
var I: Integer;
  RS: IZResultSet;
begin
  for I := 0 to FCallResultCache.Count -1 do
    if Supports(FCallResultCache[i], IZResultSet, RS) then
      RS.Close;
  FreeAndNil(FCallResultCache);
end;

constructor TZAbstractOleDBStatement.Create(const Connection: IZConnection;
  const SQL: string; const Info: TStrings);
var DatabaseInfo: IZDataBaseInfo;
begin
  inherited Create(Connection, SQL, Info);
  FZBufferSize := {$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(ZDbcUtils.DefineStatementParameter(Self, DSProps_InternalBufSize, ''), 131072); //by default 128KB
  fStmtTimeOut := {$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(ZDbcUtils.DefineStatementParameter(Self, DSProps_StatementTimeOut, ''), 60); //execution timeout in seconds by default 1 min
  DatabaseInfo := Connection.GetMetadata.GetDatabaseInfo;
  FSupportsMultipleResultSets := DatabaseInfo.SupportsMultipleResultSets;
  FOutParameterAvailibility := (DatabaseInfo as IZOleDBDatabaseInfo).GetOutParameterAvailability;
  DatabaseInfo := nil;
end;

function TZAbstractOleDBStatement.CreateResultSet(const RowSet: IRowSet): IZResultSet;
var
  CachedResolver: IZCachedResolver;
  NativeResultSet: TZOleDBResultSet;
  CachedResultSet: TZCachedResultSet;
begin
  Result := nil;
  if Assigned(RowSet) then begin
    NativeResultSet := TZOleDBResultSet.Create(Self, SQL, RowSet,
      FZBufferSize, ChunkSize);
    if (ResultSetConcurrency = rcUpdatable) or (ResultSetType <> rtForwardOnly) then begin
      if (Connection.GetServerProvider = spMSSQL) and (Self.GetResultSetConcurrency = rcUpdatable)
      then CachedResolver := TZOleDBMSSQLCachedResolver.Create(Self, NativeResultSet.GetMetaData)
      else CachedResolver := TZGenerateSQLCachedResolver.Create(Self, NativeResultSet.GetMetaData);
      CachedResultSet := TZOleDBCachedResultSet.Create(NativeResultSet, SQL, CachedResolver, ConSettings);
      CachedResultSet.SetConcurrency(ResultSetConcurrency);
      Result := CachedResultSet;
    end else
      Result := NativeResultSet;
  end;
  FOpenResultSet := Pointer(Result);
end;

destructor TZAbstractOleDBStatement.Destroy;
begin
  inherited Destroy;
  FCommand := nil;
end;

function TZAbstractOleDBStatement.GetFirstResultSet: IZResultSet;
var I: Integer;
begin
  Result := nil;
  if FCallResultCache <> nil then
    for I := 0 to FCallResultCache.Count -1 do
      if Supports(FCallResultCache[i], IZResultSet, Result) then begin
        FCallResultCache.Delete(I);
        Break;
      end;
end;

function TZAbstractOleDBStatement.GetInternalBufferSize: Integer;
begin
  Result := FZBufferSize;
end;

procedure TZAbstractOleDBStatement.AfterClose;
begin
  FCommand := nil;
end;

{**
  prepares the statement on the server if minimum execution
  count have been reached
}
procedure TZAbstractOleDBStatement.Prepare;
begin
  if FCommand = nil then
    FCommand := (Connection as IZOleDBConnection).CreateCommand;
  if FCallResultCache <> nil then
    ClearCallResultCache;
  inherited Prepare;
end;

procedure TZAbstractOleDBStatement.PrepareOpenedResultSetsForReusing;
  procedure SetMoreResInd;
  begin
    if (fMoreResultsIndicator = mriUnknown) and Assigned(FMultipleResults) then begin
      if GetMoreResults and (Assigned(LastResultSet) or (FRowsAffected <> -1)) then
        fMoreResultsIndicator := mriHasMoreResults
      else
        fMoreResultsIndicator := mriHasNoMoreResults;
    end;
    if Assigned(LastResultSet) then begin
      LastResultSet.Close;
      LastResultSet := nil;
    end;
  end;
begin
  if Assigned(FOpenResultSet) then
    if fMoreResultsIndicator <> mriHasNoMoreResults then begin
      if (Pointer(LastResultSet) = FOpenResultSet) then begin
        LastResultSet.Close;
        LastResultSet := nil;
      end else begin
        IZResultSet(FOpenResultSet).Close;
        FOpenResultSet := nil;
      end;
      SetMoreResInd;
    end else
      IZResultSet(FOpenResultSet).ResetCursor;
  if Assigned(LastResultSet) then begin
    if (fMoreResultsIndicator <> mriHasNoMoreResults) then begin
      LastResultSet.Close;
      LastResultSet := nil;
      SetMoreResInd;
    end else
      LastResultSet.ResetCursor;
  end;
end;

procedure TZAbstractOleDBStatement.ReleaseImmediat(
  const Sender: IImmediatelyReleasable; var AError: EZSQLConnectionLost);
begin
  inherited ReleaseImmediat(Sender, AError);
  FMultipleResults := nil;
  FCommand := nil;
  SetLength(FDBBINDSTATUSArray, 0);
end;

{**
  Executes the SQL query in this <code>PreparedStatement</code> object
  and returns the result set generated by the query.

  @return a <code>ResultSet</code> object that contains the data produced by the
    query; never <code>null</code>
}
function TZAbstractOleDBStatement.ExecuteQueryPrepared: IZResultSet;
var
  FRowSet: IRowSet;
begin
  PrepareOpenedResultSetsForReusing;
  Prepare;
  BindInParameters;
  try
    FRowsAffected := DB_COUNTUNAVAILABLE;
    FRowSet := nil;
    if Assigned(FOpenResultSet) then
      Result := IZResultSet(FOpenResultSet)
    else begin
      if FSupportsMultipleResultSets then begin
        CheckError(FCommand.Execute(nil, IID_IMultipleResults, FDBParams,@FRowsAffected,@FMultipleResults),
          lcExecute, fDBBINDSTATUSArray);
        if Assigned(FMultipleResults) then
          CheckError(FMultipleResults.GetResult(nil, DBRESULTFLAG(DBRESULTFLAG_ROWSET),
            IID_IRowset, @FRowsAffected, @FRowSet), lcOther);
      end else
        CheckError(FCommand.Execute(nil, IID_IRowset,
          FDBParams,@FRowsAffected,@FRowSet), lcExecute, fDBBINDSTATUSArray);
      if BindList.HasOutOrInOutOrResultParam then begin
        FetchCallResults(FRowSet);
        Result := GetFirstResultSet;
      end else if FRowSet <> nil
        then Result := CreateResultSet(FRowSet)
        else Result := nil;
      LastUpdateCount := FRowsAffected;
      if not Assigned(Result) then
        while GetMoreResults do
          if (LastResultSet <> nil) then begin
            Result := LastResultSet;
            FLastResultSet := nil;
            Break;
          end;
    end;
  finally
    FRowSet := nil;
  end;
end;

{**
  Executes the SQL INSERT, UPDATE or DELETE statement
  in this <code>PreparedStatement</code> object.
  In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @return either the row count for INSERT, UPDATE or DELETE statements;
  or 0 for SQL statements that return nothing
}
function TZAbstractOleDBStatement.ExecuteUpdatePrepared: Integer;
begin
  Prepare;
  BindInParameters;

  FRowsAffected := DB_COUNTUNAVAILABLE; //init
  if DriverManager.HasLoggingListener then
    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ASQL);
  if FSupportsMultipleResultSets then begin
    CheckError(FCommand.Execute(nil, IID_IMultipleResults, FDBParams,@FRowsAffected,@FMultipleResults),
      lcExecute, fDBBINDSTATUSArray);
    if Assigned(FMultipleResults) then
      CheckError(FMultipleResults.GetResult(nil, DBRESULTFLAG(DBRESULTFLAG_DEFAULT),
        DB_NULLGUID, @FRowsAffected, nil), lcExecute);
  end else
    CheckError(FCommand.Execute(nil, DB_NULLGUID,FDBParams,@FRowsAffected,nil), lcExecute, FDBBINDSTATUSArray);
  if BindList.HasOutOrInOutOrResultParam then
    FOutParamResultSet := CreateResultSet(nil);
  LastUpdateCount := FRowsAffected;
  Result := LastUpdateCount;
end;

function TZAbstractOleDBStatement.FetchCallResults(var RowSet: IRowSet): Boolean;
var CallResultCache: TZCollection;
begin
  Result := RowSet <> nil;
  if (FOutParameterAvailibility = DBPROPVAL_OA_ATEXECUTE) then
    FOutParamResultSet := CreateResultSet(nil);
  CallResultCache := TZCollection.Create;
  if RowSet <> nil then begin
    FLastResultSet := CreateResultSet(RowSet);
    CallResultCache.Add(Connection.GetMetadata.CloneCachedResultSet(FlastResultSet));
    FLastResultSet.Close;
    RowSet := nil;
  end else CallResultCache.Add(TZAnyValue.CreateWithInteger(LastUpdateCount));
  while GetMoreresults do
    if LastResultSet <> nil then begin
      CallResultCache.Add(Connection.GetMetadata.CloneCachedResultSet(FLastResultSet));
      FLastResultSet.Close;
      FLastResultSet := nil;
      FOpenResultSet := nil;
    end else
      CallResultCache.Add(TZAnyValue.CreateWithInteger(LastUpdateCount));
  if (FOutParameterAvailibility = DBPROPVAL_OA_ATROWRELEASE) then
    FOutParamResultSet := CreateResultSet(nil);
  FCallResultCache := CallResultCache;
end;

{**
  Executes any kind of SQL statement.
  Some prepared statements return multiple results; the <code>execute</code>
  method handles these complex statements as well as the simpler
  form of statements handled by the methods <code>executeQuery</code>
  and <code>executeUpdate</code>.
  @see Statement#execute
}
function TZAbstractOleDBStatement.ExecutePrepared: Boolean;
var FRowSet: IRowSet;
begin
  PrepareOpenedResultSetsForReusing;
  LastUpdateCount := -1;

  Prepare;
  BindInParameters;
  FRowsAffected := DB_COUNTUNAVAILABLE;
  try
    FRowSet := nil;
    if FSupportsMultipleResultSets then begin
      CheckError(FCommand.Execute(nil, IID_IMultipleResults,
        FDBParams,@FRowsAffected,@FMultipleResults), lcExecute, FDBBINDSTATUSArray);
      if Assigned(FMultipleResults) then
        CheckError(FMultipleResults.GetResult(nil, DBRESULTFLAG(DBRESULTFLAG_ROWSET),
          IID_IRowset, @FRowsAffected, @FRowSet), lcOther);
    end else
      CheckError(FCommand.Execute(nil, IID_IRowset,
        FDBParams,@FRowsAffected,@FRowSet), lcExecute, FDBBINDSTATUSArray);
    if BindList.HasOutOrInOutOrResultParam then
      if FetchCallResults(FRowSet)
      then LastResultSet := GetFirstResultSet
      else LastResultSet := nil
    else if FRowSet <> nil
      then LastResultSet := CreateResultSet(FRowSet)
      else LastResultSet := nil;
    LastUpdateCount := FRowsAffected;
    Result := Assigned(LastResultSet);
  finally
    FRowSet := nil;
    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ASQL);
  end;
end;

{**
  Moves to a <code>Statement</code> object's next result.  It returns
  <code>true</code> if this result is a <code>ResultSet</code> object.
  This method also implicitly closes any current <code>ResultSet</code>
  object obtained with the method <code>getResultSet</code>.

  <P>There are no more results when the following is true:
  <PRE>
        <code>(!getMoreResults() && (getUpdateCount() == -1)</code>
  </PRE>

 @return <code>true</code> if the next result is a <code>ResultSet</code> object;
   <code>false</code> if it is an update count or there are no more results
 @see #execute
}
function TZAbstractOleDBStatement.GetMoreResults: Boolean;
var
  FRowSet: IRowSet;
  Status: HResult;
  RS: IZResultSet;
  AnyValue: IZAnyValue;
begin
  if (FOpenResultSet <> nil) and (FOpenResultSet <> Pointer(FOutParamResultSet))
  then IZResultSet(FOpenResultSet).Close;
  if FCallResultCache <> nil then begin
    Result := FCallResultCache.Count > 0;
    if Result then begin
      if Supports(FCallResultCache[0], IZResultSet, RS) then begin
        LastResultSet := RS;
        LastUpdateCount := -1;
      end else begin
        FCallResultCache[0].QueryInterface(IZAnyValue, AnyValue);
        LastUpdateCount := AnyValue.GetInteger;
        LastResultSet := nil;
      end;
      FCallResultCache.Delete(0);
    end;
  end else begin
    Result := False;
    LastResultSet := nil;
    LastUpdateCount := -1;
    if Assigned(FMultipleResults) then begin
      Status := FMultipleResults.GetResult(nil, DBRESULTFLAG(DBRESULTFLAG_ROWSET),
        IID_IRowset, @FRowsAffected, @FRowSet);
      Result := Status = S_OK;
      if Result then begin
        if Assigned(FRowSet)
        then LastResultSet := CreateResultSet(FRowSet)
        else LastUpdateCount := FRowsAffected;
      end {else if Status <> DB_S_NORESULT then
        CheckError(Status, lcOther)};
    end;
  end;
end;

function TZAbstractOleDBStatement.GetMoreResultsIndicator: TZMoreResultsIndicator;
begin
  Result := fMoreResultsIndicator;
end;

function TZAbstractOleDBStatement.GetNewRowSet(var RowSet: IRowSet): Boolean;
begin
  RowSet := nil;
  if Prepared then begin
    CheckError(FCommand.Execute(nil, IID_IRowset,
      FDBParams,@FRowsAffected,@RowSet), lcExecute);
    Result := Assigned(RowSet);
  end else Result := False;
end;

procedure TZAbstractOleDBStatement.Unprepare;
var
  Status: HRESULT;
  FRowSet: IRowSet;
begin
  if Prepared then
    try
      inherited Unprepare;
      if FCallResultCache <> nil then
        ClearCallResultCache;
      if FMultipleResults <> nil then begin
        repeat
          FRowSet := nil;
          Status := FMultipleResults.GetResult(nil, DBRESULTFLAG(DBRESULTFLAG_DEFAULT),
            IID_IRowset, @FRowsAffected, @FRowSet);
        until Failed(Status) or (Status = DB_S_NORESULT);
        FMultipleResults := nil;
      end;
      CheckError((FCommand as ICommandPrepare).UnPrepare, lcOther, nil);
    finally
      FCommand := nil;
      FMultipleResults := nil;
    end;
end;

procedure TZAbstractOleDBStatement.SetMoreResultsIndicator(
  Value: TZMoreResultsIndicator);
begin
  fMoreResultsIndicator := Value;
end;

{ TZOleDBPreparedStatement }

//const OleDbNotNullTable: array[Boolean] of DBSTATUS = (DBSTATUS_S_ISNULL, DBSTATUS_S_OK);
procedure TZOleDBPreparedStatement.BindBatchDMLArrays;
var
  ZData, Data, P: Pointer;
  PLen: PDBLENGTH;
  PD: PZDate absolute PLen;
  PT: PZTime absolute PLen;
  PTS: PZTimeStamp absolute PLen;
  P_BCD: PBCD absolute PLen;
  MaxL, CPL: DBLENGTH;
  ZArray: PZArray;
  I, j: Integer;
  BuffOffSet: NativeUInt;
  SQLType: TZSQLType;
  DateTimeTemp: TDateTime;
  W1, WType: Word;
  Native: Boolean;
  BCD: TBCD;
  TS: TZTimeStamp absolute BCD;
  T: TZTime absolute TS;
  D: TZDate absolute TS;
  DBDate: PDBDate absolute Data;
  DBTime: PDBTime absolute Data;
  DBTIME2: PDBTIME2 absolute Data;
  DBTimeStamp: PDBTimeStamp absolute Data;
  DBTIMESTAMPOFFSET: PDBTIMESTAMPOFFSET absolute Data;
  DB_NUMERIC: PDB_NUMERIC absolute Data;

  (*function IsNotNull(I, j: Cardinal): Boolean;
  var OffSet: NativeUInt;
  begin
    OffSet := (j*fRowSize);
    Result := not IsNullFromArray(ZArray, J);
    PDBSTATUS(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obStatus + OffSet))^ := OleDbNotNullTable[Result];
    if Result then begin
      Data := Pointer(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obValue + OffSet));
      //note PLen is valid only if DBPART_LENGTH was set in Bindings.dwFlags!!!
      PLen := PDBLENGTH(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obLength + OffSet));
    end;
  end;
  procedure SetData(ByRef: Boolean; P: Pointer; Len: DBLENGTH);
  begin
    PLen^ := Len;
    if ByRef then PPointer(Data)^:= P
    else if (PLen^ >= 0) and (PLen^ <= MaxL)
      then Move(P^, Pointer(Data)^, {$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(MaxL, PLen^))
      else RaiseExceeded(I);
  end;
  procedure Bind_DBTYPE_BYTES(ByRef: Boolean);
  var TempLob: IZBlob;
    P: Pointer;
    j: Integer;
  begin
    case SQLType of
      stBinaryStream: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then
                with TInterfaceDynArray(ZData)[J] as IZBLob do
                  SetData(ByRef, TempLob.GetBuffer, TempLob.Length);
      stBytes: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then
                SetData(ByRef, Pointer(TBytesDynArray(ZData)[J]), Length(TBytesDynArray(ZData)[J]));
      stGUID: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then
                SetData(ByRef, @TGUIDDynArray(ZData)[J].D1, SizeOf(TGUID));
      else
        raise Exception.Create('Unsupported Byte-Array Variant');
    end;
  end;
  //*)
  procedure Bind_DBTYPE_BYTES(ByRef: Boolean);
  var TempLob: IZBlob;
    P: Pointer;
  begin
    case SQLType of
      stBinaryStream: begin
                TempLob := TInterfaceDynArray(ZData)[J] as IZBLob;
                PLen^ := TempLob.Length;
                P := TempLob.GetBuffer;
                TempLob := nil;
              end;
      stBytes: begin
                PLen^ := Length(TBytesDynArray(ZData)[J]);
                P := Pointer(TBytesDynArray(ZData)[J]);
              end;
      stGUID: begin
                PLen^ := SizeOf(TGUID);
                P := @TGUIDDynArray(ZData)[J].D1;
              end;
      else
        raise Exception.Create('Unsupported Byte-Array Variant');
    end;
    if ByRef then PPointer(Data)^:= P
    else if (PLen^ > 0) and (PLen^ <= MaxL)
      then Move(P^, Pointer(Data)^, {$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(MaxL, PLen^))
      else RaiseExceeded(I);
  end;
  procedure Bind_Long_DBTYPE_WSTR_BY_REF;
  var TempLob: IZBlob;
    TmpStream: TStream;
  begin
    TempLob := TInterfaceDynArray(ZData)[J] as IZBLob;
    if not TempLob.IsClob then begin
      TmpStream := GetValidatedUnicodeStream(TempLob.GetBuffer, TempLob.Length, ConSettings, False);
      TempLob := TZAbstractClob.CreateWithStream(TmpStream, zCP_UTF16, ConSettings);
      TInterfaceDynArray(ZData)[J] := TempLob; //keep mem alive!
      TmpStream.Free;
    end;
    PPointer(Data)^:= TempLob.GetPWideChar;
    PLen^ := TempLob.Length;
  end;
label W_Len, WStr;
begin
  {.$R-}
  MaxL := 0; CPL := 0; W1 := 0; Native := False;//satisfy the compiler
  //http://technet.microsoft.com/de-de/library/ms174522%28v=sql.110%29.aspx
  for i := 0 to BindList.Count -1 do begin
    if not (BindList[I].BindType in [zbtRefArray, zbtArray]) then
      Continue;
    ZArray := BindList[I].Value;
    ZData := ZArray.VArray;
    SQLType := TZSQLType(ZArray.VArrayType);
    BuffOffSet := 0;
    WType := fDBBindingArray[i].wType;
    if (Wtype = DBTYPE_WSTR) then begin
      MaxL := fDBBindingArray[i].cbMaxLen -2; //omit trailing zero
      CPL := MaxL shr 1;  //need codepoint len
      if (SQLType in [stString, stUnicodeString]) then
      case ZArray.VArrayVariantType of
        {$IFNDEF UNICODE}
        vtString: if ConSettings^.AutoEncode
                  then W1 := zCP_None
                  else W1 := ConSettings^.CTRL_CP;
        {$ENDIF}
        vtAnsiString: W1 := ZOSCodePage;
        vtUTF8String: W1 := zCP_UTF8;
        vtRawByteString: W1 := FClientCP;
      end;
    end else if (wType = DBTYPE_BYTES) or (wType = DBTYPE_STR) then
      MaxL := fDBBindingArray[i].cbMaxLen - Byte(Ord(wType = DBTYPE_STR))
    else Native := (SQLType2OleDBTypeEnum[SQLType] = wType) and (ZArray.VArrayVariantType = vtNull);
      (*case wType of
        DBTYPE_I1: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PShortInt(Data)^  := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI1:   for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PByte(Data)^      := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I2:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PSmallInt(Data)^  := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI2:   for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PWord(Data)^      := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I4:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PInteger(Data)^   := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI4:   for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PCardinal(Data)^  := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I8:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PInt64(Data)^     := ArrayValueToInt64(ZArray, j);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
        DBTYPE_UI8:   for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PUInt(Data)^       := ArrayValueToUInt64(ZArray, j);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
        DBTYPE_R4:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PSingle(Data)^     := ArrayValueToDouble(ZArray, j);
        DBTYPE_R8:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PDouble(Data)^     := ArrayValueToDouble(ZArray, j);
        DBTYPE_CY:    for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PCurrency(Data)^   := ArrayValueToCurrency(ZArray, j);
        DBType_BOOL:  for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PWordBool(Data)^   := ArrayValueToBoolean(ZArray, j);
        DBTYPE_DATE, DBTYPE_DBDATE, DBTYPE_DBTIME, DBTYPE_DBTIME2, DBTYPE_DBTIMESTAMP:  for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then begin
            case SQLType of
              stTime:       DateTimeTemp := ArrayValueToTime(ZArray, j, ConSettings.WriteFormatSettings);
              stDate:       DateTimeTemp := ArrayValueToDate(ZArray, j, ConSettings.WriteFormatSettings);
              else          DateTimeTemp := ArrayValueToDateTime(ZArray, j, ConSettings.WriteFormatSettings);
            end;
            case wType of
              DBTYPE_DATE: PDateTime(Data)^ := DateTimeTemp;
              DBTYPE_DBDATE: begin
                  DecodeDate(DateTimeTemp, W1, PDBDate(Data)^.month, PDBDate(Data)^.day);
                  PDBDate(Data)^.year := W1;
                end;
              DBTYPE_DBTIME: DecodeTime(DateTimeTemp, PDBTime(Data)^.hour, PDBTime(Data)^.minute, PDBTime(Data)^.second, MS);
              DBTYPE_DBTIME2: begin
                  DecodeTime(DateTimeTemp,
                    PDBTIME2(Data)^.hour, PDBTIME2(Data)^.minute, PDBTIME2(Data)^.second, MS);
                    PDBTIME2(Data)^.fraction := MS * 1000000;
                end;
              DBTYPE_DBTIMESTAMP: begin
                  DecodeDate(DateTimeTemp, W1, PDBTimeStamp(Data)^.month, PDBTimeStamp(Data)^.day);
                  PDBTimeStamp(Data)^.year := W1;
                  if SQLType <> stDate then begin
                    DecodeTime(DateTimeTemp, PDBTimeStamp(Data)^.hour, PDBTimeStamp(Data)^.minute, PDBTimeStamp(Data)^.second, MS);
                    {if fSupportsMilliseconds
                    then} PDBTimeStamp(Data)^.fraction := MS * 1000*1000
                    {else PDBTimeStamp(Data)^.fraction := 0};
                  end else begin
                    PDBTimeStamp(Data)^.hour := 0; PDBTimeStamp(Data)^.minute := 0;
                    PDBTimeStamp(Data)^.second := 0; PDBTimeStamp(Data)^.fraction := 0;
                  end;
                end;
            end;
          end;
        { next types are automatically prepared on binding the arrays }
        DBTYPE_GUID: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then ArrayValueToGUID(ZArray, j, PGUID(Data));
        DBTYPE_GUID or DBTYPE_BYREF: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then PPointer(Data)^ := @TGUIDDynArray(ZData)[J].D1;
        DBTYPE_BYTES: Bind_DBTYPE_BYTES(False);
        DBTYPE_BYTES or DBTYPE_BYREF: Bind_DBTYPE_BYTES(True);
        DBTYPE_WSTR, DBTYPE_WSTR or DBTYPE_BYREF: begin
            case SQLType of
             { stBoolean:      FUniTemp := BoolToUnicodeEx(TBooleanDynArray(ZData)[J]);
              stByte:         FUniTemp := IntToUnicode(TByteDynArray(ZData)[J]);
              stShort:        FUniTemp := IntToUnicode(TShortIntDynArray(ZData)[J]);
              stWord:         FUniTemp := IntToUnicode(TWordDynArray(ZData)[J]);
              stSmall:        FUniTemp := IntToUnicode(TSmallIntDynArray(ZData)[J]);
              stLongWord:     FUniTemp := IntToUnicode(TCardinalDynArray(ZData)[J]);
              stInteger:      FUniTemp := IntToUnicode(TIntegerDynArray(ZData)[J]);
              stULong:        FUniTemp := IntToUnicode(TUInt64DynArray(ZData)[J]);
              stLong:         FUniTemp := IntToUnicode(TInt64DynArray(ZData)[J]);
              stFloat:        FUniTemp := FloatToUnicode(TSingleDynArray(ZData)[J]);
              stDouble:       FUniTemp := FloatToUnicode(TDoubleDynArray(ZData)[J]);
              stCurrency:     FUniTemp := FloatToUnicode(TCurrencyDynArray(ZData)[J]);
              stBigDecimal:   FUniTemp := FloatToUnicode(TExtendedDynArray(ZData)[J]);
              stTime:         FUniTemp := DateTimeToUnicodeSQLTime(TDateTimeDynArray(ZData)[J], ConSettings.WriteFormatSettings, False);
              stDate:         FUniTemp := DateTimeToUnicodeSQLDate(TDateTimeDynArray(ZData)[J], ConSettings.WriteFormatSettings, False);
              stTimeStamp:    FUniTemp := DateTimeToUnicodeSQLTimeStamp(TDateTimeDynArray(ZData)[J], ConSettings.WriteFormatSettings, False);}
              stString, stUnicodeString: begin
                case ZArray.VArrayVariantType of
                  {$IFNDEF UNICODE}vtString, {$ENDIF}
                  vtAnsiString,vtUTF8String,vtRawByteString: for j := 0 to fDBParams.cParamSets-1 do if IsNotNull(I, J) then begin
                      if wType = DBTYPE_WSTR then begin
                        P := Pointer(TRawByteStringDynArray(ZData)[J]);
                        SetData(False, PWideChar(Data), PRaw2PUnicode(PAnsiChar(P), PWideChar(Data), W1, LengthInt(Length(TRawByteStringDynArray(ZData)[J])), LengthInt(CPL)) shl 1);
                      end else begin
                        Dyn_W_Convert(I, Length(TRawByteStringDynArray(ZData)), ZArray);
                        ZData := ZArray.VArray;
                        goto WStr;
                      end;
                  end;
                  {$IFDEF UNICODE}vtString,{$ENDIF} vtUnicodeString: begin
WStr:                 PLen^ := Length(TUnicodeStringDynArray(ZData)[J]) shl 1;
                      if PLen^ > 0 then
                        if wType = DBTYPE_WSTR then begin
                          Move(Pointer(TUnicodeStringDynArray(ZData)[J])^, PWideChar(Data)^, ({$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(PLen^, MaxL)+2));
                          goto W_Len
                        end else
                          PPointer(Data)^ := Pointer(TUnicodeStringDynArray(ZData)[J])
                      else if wType = DBTYPE_WSTR
                        then PWord(Data)^ := 0
                        else PPointer(Data)^ := PEmptyUnicodeString;
                    end;
                  vtCharRec: begin
                      if TZCharRecDynArray(ZData)[J].CP = zCP_UTF16 then begin
                        PLen^ := TZCharRecDynArray(ZData)[J].Len shl 1;
                        if wType = DBTYPE_WSTR
                        then Move(PWideChar(TZCharRecDynArray(ZData)[J].P)^, PWideChar(Data)^, ({$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(PLen^, MaxL)+2))
                        else PPointer(Data)^ := TZCharRecDynArray(ZData)[J].P;
                      end else begin
                        if wType = DBTYPE_WSTR
                        then PLen^ := PRaw2PUnicode(PAnsiChar(TZCharRecDynArray(ZData)[J].P), PWideChar(Data), TZCharRecDynArray(ZData)[J].CP, LengthInt(TZCharRecDynArray(ZData)[J].Len), LengthInt(MaxL))
                        else begin
                          Dyn_W_Convert(I, Length(TZCharRecDynArray(ZData)), ZArray);
                          ZData := ZArray.VArray;
                          goto WStr;
                        end;
                      end;
W_Len:                if PLen^ > MaxL then
                        RaiseExceeded(I);
                    end;
                  else
                    raise Exception.Create('Unsupported String Variant');
                end;
              end;
              (*stAsciiStream, stUnicodeStream:
                begin
                  TempLob := TInterfaceDynArray(ZData)[J] as IZBLob;
                  if TempLob.IsClob then
                    TempLob.GetPWideChar //make internal conversion first
                  else begin
                    TmpStream := GetValidatedUnicodeStream(TempLob.GetBuffer, TempLob.Length, ConSettings, False);
                    TempLob := TZAbstractClob.CreateWithStream(TmpStream, zCP_UTF16, ConSettings);
                    TInterfaceDynArray(ZData)[J] := TempLob; //keep mem alive!
                    TmpStream.Free;
                  end;
                end;
              else
                raise Exception.Create('Unsupported AnsiString-Array Variant');
            end;
          end;
        else RaiseUnsupportedParamType(I, WType, SQLType);
        //DBTYPE_UDT: ;
        //DBTYPE_HCHAPTER:;
        //DBTYPE_PROPVARIANT:;
        //DBTYPE_VARNUMERIC:;
      end;//*)
    for J := 0 to fDBParams.cParamSets-1 do begin
      if IsNullFromArray(ZArray, J) {or (wType = DBTYPE_NULL)} then begin
        PDBSTATUS(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obStatus + BuffOffSet))^ := DBSTATUS_S_ISNULL;
        Inc(BuffOffSet, fRowSize);
        Continue;
      end else
        PDBSTATUS(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obStatus + BuffOffSet))^ := DBSTATUS_S_OK;
      Data := Pointer(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obValue + BuffOffSet));
      //note PLen is valid only if DBPART_LENGTH was set in Bindings.dwFlags!!!
      PLen := PDBLENGTH(NativeUInt(fDBParams.pData)+(fDBBindingArray[i].obLength + BuffOffSet));
      case wType of
        DBTYPE_I1:    if Native
                      then PShortInt(Data)^   := TShortIntDynArray(ZData)[j]
                      else PShortInt(Data)^   := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI1:   if Native
                      then PByte(Data)^       := TByteDynArray(ZData)[j]
                      else PByte(Data)^       := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I2:    if Native
                      then PSmallInt(Data)^   := TSmallIntDynArray(ZData)[j]
                      else PSmallInt(Data)^   := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI2:   if Native
                      then PWord(Data)^       := TWordDynArray(ZData)[j]
                      else PWord(Data)^       := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I4:    if Native
                      then PInteger(Data)^    := TIntegerDynArray(ZData)[j]
                      else PInteger(Data)^    := ArrayValueToInteger(ZArray, j);
        DBTYPE_UI4:   if Native
                      then PCardinal(Data)^   := TCardinalDynArray(ZData)[j]
                      else PCardinal(Data)^   := ArrayValueToCardinal(ZArray, j);
        DBTYPE_I8:    if Native
                      then PInt64(Data)^      := TInt64DynArray(ZData)[j]
                      else PInt64(Data)^      := ArrayValueToInt64(ZArray, j);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
        DBTYPE_UI8:   if Native
                      then PUInt64(Data)^     := TUInt64DynArray(ZData)[j]
                      else PUInt(Data)^       := ArrayValueToUInt64(ZArray, j);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
        DBTYPE_R4:    if Native
                      then PSingle(Data)^     := TSingleDynArray(ZData)[j]
                      else PSingle(Data)^     := ArrayValueToDouble(ZArray, j);
        DBTYPE_R8:    if Native
                      then PDouble(Data)^     := TDoubleDynArray(ZData)[j]
                      else PDouble(Data)^     := ArrayValueToDouble(ZArray, j);
        DBTYPE_CY:    if Native
                      then PCurrency(Data)^   := TCurrencyDynArray(ZData)[j]
                      else PCurrency(Data)^   := ArrayValueToCurrency(ZArray, j);
        DBType_BOOL:  if Native
                      then PWordBool(Data)^   := TBooleanDynArray(ZData)[j]
                      else PWordBool(Data)^   := ArrayValueToBoolean(ZArray, j);
        DBTYPE_NUMERIC: begin
                        if Native
                        then P_BCD := @TBCDDynArray(ZData)[j]
                        else begin
                          ArrayValueToBCD(ZArray, J, BCD);
                          P_BCD := @BCD;
                        end;
                        BCD2SQLNumeric(P_BCD^, DB_NUMERIC)
                      end;
        DBTYPE_DATE:  PDateTime(Data)^ := ArrayValueToDateTime(ZArray, j, ConSettings.WriteFormatSettings);
        DBTYPE_DBDATE: begin
                        if ZArray.VArrayVariantType = vtDate then
                          PD := @TZDateDynArray(ZData)[J]
                        else begin
                          PD := @D;
                          if (ZArray.VArrayVariantType in [vtNull, vtDateTime])
                          then DecodeDateTimeToDate(TDateTimeDynArray(ZData)[J], D)
                          else begin
                            DateTimeTemp := ArrayValueToDate(ZArray, J, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToDate(DateTimeTemp, D);
                          end;
                        end;
                        DBDate^.year := PD^.Year;
                        if PD^.IsNegative then
                          DBDate^.year := -DBDate^.year;
                        DBDate^.month := PD^.Month;
                        DBDate^.day := PD^.Day;
                      end;

        DBTYPE_DBTIME, DBTYPE_DBTIME2: begin
                        if ZArray.VArrayVariantType = vtTime then
                          PT := @TZTimeDynArray(ZData)[J]
                        else begin
                          PT := @T;
                          if (ZArray.VArrayVariantType in [vtNull, vtDateTime])
                          then DecodeDateTimeToTime(TDateTimeDynArray(ZData)[J], T)
                          else begin
                            DateTimeTemp := ArrayValueToTime(ZArray, J, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToTime(DateTimeTemp, T);
                          end;
                        end;
                        if wType = DBTYPE_DBTIME then begin
                          DBTime.hour := PT^.Hour;
                          DBTime.minute := PT^.Minute;
                          DBTime.second := PT^.Second;
                        end else begin
                          DBTIME2.hour := PT^.Hour;
                          DBTIME2.minute := PT^.Minute;
                          DBTIME2.second := PT^.Second;
                          DBTIME2.fraction := PT^.Fractions;
                        end;
                      end;
        DBTYPE_DBTIMESTAMP, DBTYPE_DBTIMESTAMPOFFSET: begin
                        if ZArray.VArrayVariantType = vtTimeStamp then
                          PTS := @TZTimeStampDynArray(ZData)[J]
                        else begin
                          PTS := @TS;
                          if (ZArray.VArrayVariantType in [vtNull, vtDateTime])
                          then DecodeDateTimeToTimeStamp(TDateTimeDynArray(ZData)[J], TS)
                          else begin
                            DateTimeTemp := ArrayValueToDatetime(ZArray, J, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToTimeStamp(DateTimeTemp, TS);
                          end;
                        end;
                        if wType = DBTYPE_DBTIMESTAMP then begin
                          DBTimeStamp.year := PTS^.Year;
                          if PTS^.IsNegative then
                            DBTimeStamp^.year := -DBTimeStamp^.year;
                          DBTimeStamp^.month := PTS^.Month;
                          DBTimeStamp^.day := PTS^.Day;
                          DBTimeStamp.hour := PTS^.Hour;
                          DBTimeStamp.minute := PTS^.Minute;
                          DBTimeStamp.second := PTS^.Second;
                          DBTimeStamp.fraction := PTS^.Fractions;
                        end else begin
                          DBTIMESTAMPOFFSET.year := PTS^.Year;
                          if PTS^.IsNegative then
                            DBTIMESTAMPOFFSET^.year := -DBTIMESTAMPOFFSET^.year;
                          DBTIMESTAMPOFFSET^.month := PTS^.Month;
                          DBTIMESTAMPOFFSET^.day := PTS^.Day;
                          DBTIMESTAMPOFFSET.hour := PTS^.Hour;
                          DBTIMESTAMPOFFSET.minute := PTS^.Minute;
                          DBTIMESTAMPOFFSET.second := PTS^.Second;
                          DBTIMESTAMPOFFSET.fraction := PTS^.Fractions;
                          DBTIMESTAMPOFFSET.timezone_hour := PTS^.TimeZoneHour;
                          DBTIMESTAMPOFFSET.timezone_minute := PTS^.TimeZoneMinute;
                        end;
                      end;
        { next types are automatically prepared on binding the arrays }
        DBTYPE_GUID: ArrayValueToGUID(ZArray, j, PGUID(Data));
        DBTYPE_GUID or DBTYPE_BYREF: ArrayValueToGUID(ZArray, j, PGUID(PPointer(Data)^));
        DBTYPE_BYTES: Bind_DBTYPE_BYTES(False);
        DBTYPE_BYTES or DBTYPE_BYREF: Bind_DBTYPE_BYTES(True);
        DBTYPE_WSTR, DBTYPE_WSTR or DBTYPE_BYREF: begin
            case SQLType of
             { stBoolean:      FUniTemp := BoolToUnicodeEx(TBooleanDynArray(ZData)[J]);
              stByte:         FUniTemp := IntToUnicode(TByteDynArray(ZData)[J]);
              stShort:        FUniTemp := IntToUnicode(TShortIntDynArray(ZData)[J]);
              stWord:         FUniTemp := IntToUnicode(TWordDynArray(ZData)[J]);
              stSmall:        FUniTemp := IntToUnicode(TSmallIntDynArray(ZData)[J]);
              stLongWord:     FUniTemp := IntToUnicode(TCardinalDynArray(ZData)[J]);
              stInteger:      FUniTemp := IntToUnicode(TIntegerDynArray(ZData)[J]);
              stULong:        FUniTemp := IntToUnicode(TUInt64DynArray(ZData)[J]);
              stLong:         FUniTemp := IntToUnicode(TInt64DynArray(ZData)[J]);
              stFloat:        FUniTemp := FloatToUnicode(TSingleDynArray(ZData)[J]);
              stDouble:       FUniTemp := FloatToUnicode(TDoubleDynArray(ZData)[J]);
              stCurrency:     FUniTemp := FloatToUnicode(TCurrencyDynArray(ZData)[J]);
              stBigDecimal:   FUniTemp := FloatToUnicode(TExtendedDynArray(ZData)[J]);
              stTime:         FUniTemp := DateTimeToUnicodeSQLTime(TDateTimeDynArray(ZData)[J], ConSettings.WriteFormatSettings, False);}
              stDate:         if (WType = DBTYPE_WSTR) and (ConSettings.WriteFormatSettings.DateFormatLen <= MaxL)
                              then DateTimeToUnicodeSQLDate(TDateTimeDynArray(ZData)[J], PWideChar(Data), ConSettings.WriteFormatSettings, False)
                              else RaiseExceeded(I);
              (*stTimeStamp:    FUniTemp := DateTimeToUnicodeSQLTimeStamp(TDateTimeDynArray(ZData)[J], ConSettings.WriteFormatSettings, False);}*)
              stString, stUnicodeString: begin
                case ZArray.VArrayVariantType of
                  {$IFNDEF UNICODE}vtString, {$ENDIF}
                  vtAnsiString,vtUTF8String,vtRawByteString:
                      if wType = DBTYPE_WSTR then begin
                        P := Pointer(TRawByteStringDynArray(ZData)[J]);
                        PLen^ := PRaw2PUnicode(PAnsiChar(P), PWideChar(Data), W1, LengthInt(Length(TRawByteStringDynArray(ZData)[J])), LengthInt(CPL)) shl 1;
                        goto W_Len;
                      end else begin
                        Dyn_W_Convert(I, Length(TRawByteStringDynArray(ZData)), ZArray);
                        ZData := ZArray.VArray;
                        goto WStr;
                      end;
                  {$IFDEF UNICODE}vtString,{$ENDIF} vtUnicodeString: begin
WStr:                 PLen^ := Length(TUnicodeStringDynArray(ZData)[J]) shl 1;
                      if PLen^ > 0 then
                        if wType = DBTYPE_WSTR then begin
                          Move(Pointer(TUnicodeStringDynArray(ZData)[J])^, PWideChar(Data)^, ({$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(PLen^, MaxL)+2));
                          goto W_Len
                        end else
                          PPointer(Data)^ := Pointer(TUnicodeStringDynArray(ZData)[J])
                      else if wType = DBTYPE_WSTR
                        then PWord(Data)^ := 0
                        else PPointer(Data)^ := PEmptyUnicodeString;
                    end;
                  vtCharRec: begin
                      if TZCharRecDynArray(ZData)[J].CP = zCP_UTF16 then begin
                        PLen^ := TZCharRecDynArray(ZData)[J].Len shl 1;
                        if wType = DBTYPE_WSTR
                        then Move(PWideChar(TZCharRecDynArray(ZData)[J].P)^, PWideChar(Data)^, ({$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Min(PLen^, MaxL)+2))
                        else PPointer(Data)^ := TZCharRecDynArray(ZData)[J].P;
                      end else begin
                        if wType = DBTYPE_WSTR
                        then PLen^ := PRaw2PUnicode(PAnsiChar(TZCharRecDynArray(ZData)[J].P), PWideChar(Data), TZCharRecDynArray(ZData)[J].CP, LengthInt(TZCharRecDynArray(ZData)[J].Len), LengthInt(MaxL))
                        else begin
                          Dyn_W_Convert(I, Length(TZCharRecDynArray(ZData)), ZArray);
                          ZData := ZArray.VArray;
                          goto WStr;
                        end;
                      end;
W_Len:                if PLen^ > MaxL then
                        RaiseExceeded(I);
                    end;
                  else
                    raise Exception.Create('Unsupported String Variant');
                end;
              end;
              stAsciiStream, stUnicodeStream: Bind_Long_DBTYPE_WSTR_BY_REF;
              else
                raise Exception.Create('Unsupported AnsiString-Array Variant');
            end;
          end;
        else raise CreateOleDBConvertErrror(I, WType, SQLType);
        //DBTYPE_UDT: ;
        //DBTYPE_HCHAPTER:;
        //DBTYPE_PROPVARIANT:;
        //DBTYPE_VARNUMERIC:;
      end;
      Inc(BuffOffSet, fRowSize);
    end;  //*)
  end;
  {$IF defined (RangeCheckEnabled)}{$R+}{$IFEND}
end;

procedure TZOleDBPreparedStatement.BindInParameters;
begin
  if BindList.Count = 0 then
    Exit;
  if not fBindImmediat or (BatchDMLArrayCount > 0) then
    try
      fBindImmediat := True;
      if fBindAgain or (FDBParams.hAccessor = 0) then
        PrepareInParameters;
      if BatchDMLArrayCount = 0
      then BindList.BindValuesToStatement(Self)
      else BindBatchDMLArrays;
      fBindAgain := False;
    finally
      fBindImmediat := fDEFERPREPARE;
    end;
end;

procedure TZOleDBPreparedStatement.BindRaw(Index: Integer;
  const Value: RawByteString; CP: Word);
var L: Cardinal;
  PLen: PDBLENGTH;
  Bind: PDBBINDING;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat and (FDBBindingArray[Index].wType = DBTYPE_WSTR) then begin
    Bind := @FDBBindingArray[Index];
    PLen := PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength);
    L := Bind.cbMaxLen-2;
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    PLen^ := PRaw2PUnicode(Pointer(Value), Pointer(NativeUInt(fDBParams.pData)+Bind.obValue), CP, LengthInt(Length(Value)), LengthInt(L shr 1)) shl 1;
    if PLen^ > L then
      RaiseExceeded(Index)
  end else begin
    FUniTemp := PRawToUnicode(Pointer(Value), Length(Value), CP);
    BindList.Put(Index, stUnicodeString, FUniTemp);
    L := Length(FUniTemp);
    if fBindImmediat then
      if Value <> ''
      then SetPWideChar(Index, Pointer(FUniTemp), L)
      else SetPWideChar(Index, PEmptyUnicodeString, 0)
    else InitVaryBind(Index, (L+1) shl 1, DBTYPE_WSTR);
  end;
end;

procedure TZOleDBPreparedStatement.CalcParamSetsAndBufferSize;
var
  FAccessorRefCount: DBREFCOUNT;
begin
  FDBParams.cParamSets := Max(1, BatchDMLArrayCount); //indicate rows for single executions
  if (FDBParams.hAccessor <> 0) and fBindAgain then begin
    FParameterAccessor.ReleaseAccessor(FDBParams.hAccessor, @FAccessorRefCount);
    FDBParams.hAccessor := 0;
  end;
  SetLength(FParamsBuffer, FDBParams.cParamSets * FRowSize);
  FDBParams.pData := Pointer(FParamsBuffer); //set entry pointer
  if (FDBParams.hAccessor = 0) then
    CheckError(FParameterAccessor.CreateAccessor(DBACCESSOR_PARAMETERDATA,
      FDBUPARAMS, Pointer(FDBBindingArray), FRowSize, @FDBParams.hAccessor,
      Pointer(FDBBINDSTATUSArray)), lcOther, FDBBINDSTATUSArray);
end;

procedure TZOleDBPreparedStatement.CheckParameterIndex(var Value: Integer);
begin
  if not Prepared then
    Prepare;
  if (BindList.Capacity < Value+1) then
    if fBindImmediat
    then raise EZSQLException.Create(SInvalidInputParameterCount)
    else inherited CheckParameterIndex(Value);
end;

constructor TZOleDBPreparedStatement.Create(const Connection: IZConnection;
  const SQL: string; const Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  FClientCP := ConSettings^.ClientCodePage.CP;
end;

function TZOleDBPreparedStatement.CreateOleDBConvertErrror(Index: Integer;
  WType: Word; SQLType: TZSQLType): EZOleDBConvertError;
begin
  Result := EZOleDBConvertError.Create('Index: '+ZFastCode.IntToStr(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF})+
    ', OleType: '+ZFastCode.IntToStr(wType)+', SQLType: '+GetEnumName(TypeInfo(TZSQLType), Ord(SQLType))+
    LineEnding+SUnsupportedParameterType+LineEnding+ 'Stmt: '+GetSQL);
end;

function TZOleDBPreparedStatement.CreateResultSet(
  const RowSet: IRowSet): IZResultSet;
var
  NativeResultSet: TZOleDBParamResultSet;
  CachedResultSet: TZCachedResultSet;
begin
  Result := nil;
  if (RowSet = nil) and BindList.HasOutOrInOutOrResultParam then begin
    NativeResultSet := TZOleDBParamResultSet.Create(Self, FParamsBuffer,
      FDBBindingArray, FParamNamesArray);
    if (ResultSetConcurrency = rcUpdatable) or (ResultSetType <> rtForwardOnly) then begin
      CachedResultSet := TZOleDBCachedResultSet.Create(NativeResultSet, SQL,
        TZGenerateSQLCachedResolver.Create(Self, NativeResultSet.GetMetaData), ConSettings);
      CachedResultSet.SetConcurrency(ResultSetConcurrency);
      Result := CachedResultSet;
    end else
      Result := NativeResultSet;
  end else
    Result := inherited CreateResultSet(RowSet);
  FOpenResultSet := Pointer(Result);
end;

procedure TZOleDBPreparedStatement.Dyn_W_Convert(Index, Len: Integer; var Arr: PZArray);
var
  W_Dyn: TUnicodeStringDynArray;
  CP: Word;
  I: Integer;
  NewArr: TZArray;
label SetUniArray;
begin
  SetLength(W_Dyn, Len);
  CP := zCP_NONE;
  case TZSQLType(Arr.VArrayType) of
    stString, stUnicodeString:
      case Arr.VArrayVariantType of
        {$IFNDEF UNICODE}
        vtString:   if not ConSettings^.AutoEncode then
                      CP := ConSettings^.CTRL_CP;
        {$ENDIF}
        vtUTF8String: CP := zCP_UTF8;
        vtAnsiString: CP := ZOSCodePage;
        vtRawByteString: CP := FClientCP;
        vtCharRec: begin
                    W_Dyn := CharRecArray2UnicodeStrArray(TZCharRecDynArray(Arr.VArray));
                    goto SetUniArray;
                   end;
      end;
  end;
  for I := 0 to High(W_Dyn) do
    W_Dyn[i] := ZRawToUnicode(TRawByteStringDynArray(Arr.VArray)[i], CP);
SetUniArray:
  NewArr := Arr^; //localize
  NewArr.VArrayType := Ord(stUnicodeString);
  NewArr.VArrayVariantType := vtUnicodeString;
  NewArr.VArray := Pointer(W_Dyn);
  BindList.Put(Index, NewArr, True);
  Arr := BindList[Index].Value;
end;

function TZOleDBPreparedStatement.GetCompareFirstKeywordStrings: PPreparablePrefixTokens;
begin
  Result := @DefaultPreparableTokens;
end;

procedure TZOleDBPreparedStatement.InitDateBind(Index: Integer;
  SQLType: TZSQLType);
var Bind: PDBBINDING;
begin
  Bind := @FDBBindingArray[Index];
  fBindAgain := fBindAgain or ((BindList.ParamTypes[Index] = pctUnknown) and (Bind.wType <> SQLType2OleDBTypeEnum[SQLType]));
  if fBindagain then begin
    Bind.wType := SQLType2OleDBTypeEnum[SQLType];
    Bind.dwFlags := FDBBindingArray[Index].dwFlags and not DBPARAMFLAGS_ISLONG;
    case SQLType of
      stDate: Bind.cbMaxLen := SizeOf(TDBDate);
      stTime: Bind.cbMaxLen := SizeOf(TDBTime2);
      else    Bind.cbMaxLen := SizeOf(Double); //DBTYPE_DATE
    end;
    Bind.dwPart := DBPART_VALUE or DBPART_STATUS;
  end;
end;

procedure TZOleDBPreparedStatement.InitFixedBind(Index: Integer; Size: Cardinal;
  _Type: DBTYPE);
var Bind: PDBBINDING;
begin
  Bind := @FDBBindingArray[Index];
  fBindAgain := fBindAgain or ((BindList.ParamTypes[Index] = pctUnknown) and ((Bind.wType <> _Type) or (Bind.cbMaxLen <> Size)));
  if fBindagain then begin
    Bind.wType := _Type;
    Bind.dwFlags := FDBBindingArray[Index].dwFlags and not DBPARAMFLAGS_ISLONG;
    Bind.cbMaxLen := Size;
    Bind.dwPart := DBPART_VALUE or DBPART_STATUS;
  end;
end;

procedure TZOleDBPreparedStatement.InitLongBind(Index: Integer; _Type: DBTYPE);
var Bind: PDBBINDING;
begin
  Bind := @FDBBindingArray[Index];
  fBindAgain := fBindAgain or ((BindList.ParamTypes[Index] = pctUnknown) and (Bind.wType <> _Type or DBTYPE_BYREF));
  if fBindagain then begin
    Bind.wType := _Type or DBTYPE_BYREF;
    Bind.dwFlags := FDBBindingArray[Index].dwFlags and DBPARAMFLAGS_ISLONG;
    Bind.cbMaxLen := SizeOf(Pointer);
    Bind.dwPart := DBPART_VALUE or DBPART_LENGTH or DBPART_STATUS;
  end;
end;

procedure TZOleDBPreparedStatement.InitVaryBind(Index: Integer; Len: Cardinal;
  _Type: DBTYPE);
var Bind: PDBBINDING;
begin
  Bind := @FDBBindingArray[Index];
  fBindAgain := fBindAgain or ((BindList.ParamTypes[Index] = pctUnknown) and ((Bind.wType <> _Type) or (Bind.cbMaxLen < Len)));
  if fBindagain then begin
    Bind.wType := _Type;
    Bind.dwFlags := FDBBindingArray[Index].dwFlags and not DBPARAMFLAGS_ISLONG;
    Bind.cbMaxLen := {$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Max(512,
      {$IFDEF MISS_MATH_NATIVEUINT_MIN_MAX_OVERLOAD}ZCompatibility.{$ENDIF}Max(Bind.cbMaxLen, Len));
    Bind.dwPart := DBPART_VALUE or DBPART_LENGTH or DBPART_STATUS;
  end;
end;

procedure TZOleDBPreparedStatement.InternalBindDbl(Index: Integer;
  SQLType: TZSQLType; const Value: Double);
var Bind: PDBBINDING;
  Data: PAnsichar;
  L: Cardinal;
  MS: Word;
label DWConv, TWConv, TSWConv;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_I1, DBTYPE_I2, DBTYPE_I4, DBTYPE_I8,
      DBTYPE_UI1, DBTYPE_UI2, DBTYPE_UI4, DBTYPE_UI8:
                        SetLong(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, Trunc(Value));
      DBTYPE_DATE:        PDateTime(Data)^ := Value;
      DBTYPE_DBDATE:      DecodeDate(Value, PWord(@PDBDate(Data).year)^, PDBDate(Data).month, PDBDate(Data).day);
      DBTYPE_DBTIME:      DecodeTime(Value, PDBTIME(Data)^.hour,
                              PDBTIME(Data)^.minute, PDBTIME(Data)^.second, MS);
      DBTYPE_DBTIME2:     begin
                            DecodeTime(Value, PDBTIME2(Data)^.hour,
                              PDBTIME2(Data)^.minute, PDBTIME2(Data)^.second, MS);
                            PDBTIME2(Data)^.fraction := MS * 1000000;
                          end;
      DBTYPE_DBTIMESTAMP: begin
          DecodeDateTime(Value, PWord(@PDBTimeStamp(Data)^.year)^, PDBTimeStamp(Data).month, PDBTimeStamp(Data).day,
            PDBTimeStamp(Data).hour, PDBTimeStamp(Data)^.minute, PDBTimeStamp(Data)^.second, MS);
          PDBTimeStamp(Data)^.fraction := MS * 1000000;
        end;
      DBTYPE_WSTR: case SQLType of
            stFloat, stDouble: if Bind.cbMaxLen < 128 then begin
                  L := FloatToUnicode(Value, @fWBuffer[0]) shl 1;
                  if L < Bind.cbMaxLen
                  then Move(fWBuffer[0], Data^, L)
                  else RaiseExceeded(Index);
                  PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := L;
                end else
                  PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := FloatToUnicode(Value, PWideChar(Data)) shl 1;
            stDate: if Bind.cbMaxLen >= 22 then
DWConv:               PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        DateTimeToUnicodeSQLDate(Value, PWideChar(Data), ConSettings.WriteFormatSettings, False) shl 1
                    else RaiseExceeded(Index);
            stTime: if (Bind.cbMaxLen >= 26 ){00.00.00.000#0} or ((Bind.cbMaxLen-2) shr 1 = DBLENGTH(ConSettings.WriteFormatSettings.TimeFormatLen)) then
TWConv:               PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        DateTimeToUnicodeSQLTime(Value, PWideChar(Data), ConSettings.WriteFormatSettings, False) shl 1
                      else RaiseExceeded(Index);
            stTimeStamp: if (Bind.cbMaxLen >= 48){0000-00-00T00.00.00.000#0}  or ((Bind.cbMaxLen-2) shr 1 = DBLENGTH(ConSettings.WriteFormatSettings.DateTimeFormatLen)) then
TSWConv:              PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        DateTimeToUnicodeSQLTime(Value, PWideChar(Data), ConSettings.WriteFormatSettings, False) shl 1
                    else RaiseExceeded(Index);
            else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
          end;
      (DBTYPE_WSTR or DBTYPE_BYREF): case SQLType of
            stFloat, stDouble: begin
                PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 128);
                PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := FloatToUnicode(Value, ZPPWideChar(Data)^) shl 1;
              end;
            stDate: begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 24);
                      Data := PPointer(Data)^;
                      goto DWConv;
                    end;
            stTime: begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 26);
                      Data := PPointer(Data)^;
                      goto TWConv;
                    end;
            stTimeStamp: begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 48);
                      Data := PPointer(Data)^;
                      goto TSWConv;
                    end;
            else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
        end;
      DBTYPE_NUMERIC: begin
                        Double2BCD(Value, PBCD(@fWBuffer[0])^);
                        BCD2SQLNumeric(PBCD(@fWBuffer[0])^, PDB_NUMERIC(Data));
                      end;
      //DBTYPE_VARNUMERIC:;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
    end;
  end else begin//Late binding
    if SQLtype in [stDate, stTime, stTimeStamp]
    then InitDateBind(Index, SQLType)
    else InitFixedBind(Index, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType]);
    BindList.Put(Index, SQLType, P8Bytes(@Value));
  end;
end;

procedure TZOleDBPreparedStatement.InternalBindSInt(Index: Integer;
  SQLType: TZSQLType; Value: NativeInt);
var Bind: PDBBINDING;
  Data: Pointer;
  C: NativeUInt; //some delphis can't determine the overload of GetOrdinalDigits if a NativeUInt is uses
  L: Cardinal;
  Negative: Boolean;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := Value;
      DBTYPE_I4:        PInteger(Data)^ := Value;
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_UI1:       PByte(Data)^ := Value;
      DBTYPE_I1:        PShortInt(Data)^ := Value;
      DBTYPE_UI2:       PWord(Data)^ := Value;
      DBTYPE_UI4:       PCardinal(Data)^ := Value;
      DBTYPE_I8:        PInt64(Data)^ := Value;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI8:       PUInt64(Data)^ := Value;
      DBTYPE_WSTR, (DBTYPE_WSTR or DBTYPE_BYREF): begin
          L := GetOrdinalDigits(Value, C, Negative);
          if Bind.wType = (DBTYPE_WSTR or DBTYPE_BYREF) then begin
            PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 24);
            Data := PPointer(Data)^;
          end else if (Bind.cbMaxLen <= (L +Byte(Ord(Negative))) shl 1) then
            RaiseExceeded(Index);
          if Negative then
            PWord(Data)^ := Ord('-');
          IntToUnicode(C, PWideChar(Data)+Ord(Negative), L);
          PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := L shl 1 + Byte(Ord(Negative));
        end;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_NUMERIC: begin
                        PDB_NUMERIC(Data)^.precision := GetOrdinalDigits(Value, {$IFDEF CPU64}PUInt64{$ELSE}PCardinal{$ENDIF}(@PDB_NUMERIC(Data).val[0])^, Negative);
                        PDB_NUMERIC(Data)^.scale := 0;
                        PDB_NUMERIC(Data)^.sign := Ord(not Negative);
                        FillChar(PDB_NUMERIC(Data)^.val[SizeOf(NativeUInt)], SQL_MAX_NUMERIC_LEN-SizeOf(NativeUInt), #0);
                      end;
      //DBTYPE_VARNUMERIC:;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
    end;
  end else begin//Late binding
    InitFixedBind(Index, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType]);
    BindList.Put(Index, SQLType, {$IFDEF CPU64}P8Bytes{$ELSE}P4Bytes{$ENDIF}(@Value));
  end;
end;

procedure TZOleDBPreparedStatement.InternalBindUInt(Index: Integer;
  SQLType: TZSQLType; Value: NativeUInt);
var Bind: PDBBINDING;
  Data: PAnsichar;
  L: Cardinal;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := SmallInt(Value);
      DBTYPE_I4:        PInteger(Data)^ := Value;
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_UI1:       PByte(Data)^ := Byte(Value);
      DBTYPE_I1:        PShortInt(Data)^ := ShortInt(Value);
      DBTYPE_UI2:       PWord(Data)^ := Word(Value);
      DBTYPE_UI4:       PCardinal(Data)^ := Cardinal(Value);
      DBTYPE_I8:        PInt64(Data)^ := Value;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI8:       PUInt64(Data)^ := Value;
      DBTYPE_WSTR, (DBTYPE_WSTR or DBTYPE_BYREF): begin
          L := GetOrdinalDigits(Value);
          if Bind.wType = (DBTYPE_WSTR or DBTYPE_BYREF) then begin
            PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 24);
            Data := PPointer(Data)^;
          end else if (L shl 1 >= Bind.cbMaxLen) then
            RaiseExceeded(Index);
          PWord(PWideChar(Data)+ L)^ := Ord(#0);
          IntToUnicode(Value, PWideChar(Data), L);
          PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := L shl 1;
        end;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      DBTYPE_NUMERIC: begin
                        PDB_NUMERIC(Data)^.precision := GetOrdinalDigits(Value);
                        PDB_NUMERIC(Data)^.scale := 0;
                        PDB_NUMERIC(Data)^.sign := 0;
                        FillChar(PDB_NUMERIC(Data)^.val[0], SQL_MAX_NUMERIC_LEN, #0);
                        PNativeUInt(@PDB_NUMERIC(Data)^.val[0])^ := Value;
                      end;
      //DBTYPE_VARNUMERIC:;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
    end;
  end else begin//Late binding
    InitFixedBind(Index, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType]);
    BindList.Put(Index, SQLType, {$IFDEF CPU64}P8Bytes{$ELSE}P4Bytes{$ENDIF}(@Value));
  end;
end;

procedure TZOleDBPreparedStatement.Prepare;
var
  FOlePrepareCommand: ICommandPrepare;
  DBInfo: IZDataBaseInfo;
begin
  if Not Prepared then begin//prevent PrepareInParameters
    fDEFERPREPARE := StrToBoolEx(ZDbcUtils.DefineStatementParameter(Self, DSProps_PreferPrepared, 'True')) and (FTokenMatchIndex <> -1);
    FCommand := (Connection as IZOleDBConnection).CreateCommand;
    try
      SetOleCommandProperties;
      CheckError(fCommand.SetCommandText(DBGUID_DEFAULT, Pointer(WSQL)), lcOther);
      OleCheck(fCommand.QueryInterface(IID_ICommandPrepare, FOlePrepareCommand));
      if fDEFERPREPARE then begin
        CheckError(FOlePrepareCommand.Prepare(0), lcOther);
        fBindImmediat := True;
      end else
        fBindImmediat := False;
    finally
      FOlePrepareCommand := nil;
    end;
    DBInfo := Connection.GetMetadata.GetDatabaseInfo;
    if FSupportsMultipleResultSets
    then fMoreResultsIndicator := mriUnknown
    else fMoreResultsIndicator := mriHasNoMoreResults;
    fSupportsByRef := (DBInfo as IZOleDBDatabaseInfo).SupportsByRefAccessors;
    DBInfo := nil;
    inherited Prepare;
  end else begin
    if FCallResultCache <> nil then
      ClearCallResultCache;
    FMultipleResults := nil; //release this interface! else we can't free the command in some tests
    if Assigned(FParameterAccessor) and ((BatchDMLArrayCount > 0) and
       (FDBParams.cParamSets = 0)) or //new arrays have been set
       ((BatchDMLArrayCount = 0) and (FDBParams.cParamSets > 1)) then //or single exec follows
      CalcParamSetsAndBufferSize;
  end;
end;

{**
  Prepares eventual structures for binding input parameters.
}
procedure TZOleDBPreparedStatement.PrepareInParameters;
var
  FNamesBuffer: PPOleStr; //we don't need this here except as param!
  FParamInfoArray: PDBParamInfoArray;
  FCommandWithParameters: ICommandWithParameters;
  DescripedDBPARAMINFO: TDBParamInfoDynArray;
  Status: HResult;
begin
  if not fBindImmediat then
    Exit;
  if not Prepared then begin
    {check out the parameter informations }
    FParamInfoArray := nil; FNamesBuffer := nil; DescripedDBPARAMINFO := nil;
    OleCheck(fcommand.QueryInterface(IID_ICommandWithParameters, FCommandWithParameters));
    Status := FCommandWithParameters.GetParameterInfo(FDBUPARAMS,PDBPARAMINFO(FParamInfoArray), FNamesBuffer);
    if Status = DB_E_PARAMUNAVAILABLE then begin
      fDEFERPREPARE := false;
      Exit;
    end else if Failed(Status) then
      CheckError(Status, lcOther, FDBBINDSTATUSArray);
    try
      SetParamCount(FDBUPARAMS);
      if FDBUPARAMS > 0 then begin
        OleCheck(FCommand.QueryInterface(IID_IAccessor, FParameterAccessor));
        FRowSize := PrepareOleParamDBBindings(FDBUPARAMS, FDBBindingArray,
          FParamInfoArray);
        CalcParamSetsAndBufferSize;
        if not (FDBParams.hAccessor = 1) then
          raise EZSQLException.Create('Accessor handle should be unique!');
      end else begin
        { init ! }
        FDBParams.pData := nil;
        FDBParams.cParamSets := 0;
        FDBParams.hAccessor := 0;
      end;
    finally
      if Assigned(FParamInfoArray) and (Pointer(FParamInfoArray) <> Pointer(DescripedDBPARAMINFO)) then
        (GetConnection as IZOleDBConnection).GetMalloc.Free(FParamInfoArray);
      if Assigned(FNamesBuffer) then (GetConnection as IZOleDBConnection).GetMalloc.Free(FNamesBuffer);
      FCommandWithParameters := nil;
    end;
  end else begin
    FDBUPARAMS := BindList.Count;
    SetBindOffsets;
    if FParameterAccessor = nil then
      OleCheck(FCommand.QueryInterface(IID_IAccessor, FParameterAccessor));
    CalcParamSetsAndBufferSize;
  end;
end;

procedure TZOleDBPreparedStatement.RaiseExceeded(Index: Integer);
begin
  raise EZSQLException.Create(Format(cSParamValueExceeded, [Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}])+LineEnding+
    'Stmt: '+GetSQL);
end;

procedure TZOleDBPreparedStatement.RegisterParameter(Index: Integer;
  SQLType: TZSQLType; ParamType: TZProcedureColumnType; const Name: String;
  PrecisionOrSize, Scale: LengthInt);
var Bind: PDBBINDING;
begin
  CheckParameterIndex(Index);
  if (Name <> '') then begin
    if (High(FParamNamesArray) < Index) then
      SetLength(FParamNamesArray, Index+1);
    FParamNamesArray[Index] := Name;
  end;
  Bind := @FDBBindingArray[Index];
  if fDEFERPREPARE then begin
    case ParamType of
      pctReturn, pctOut: if Bind.dwFlags and DBPARAMFLAGS_ISINPUT <> 0 then
                           Bind.dwFlags := (Bind.dwFlags and not DBPARAMFLAGS_ISINPUT) or DBPARAMFLAGS_ISOUTPUT;
      pctIn, pctInOut: if Bind.dwFlags and DBPARAMFLAGS_ISINPUT = 0 then
                           Bind.dwFlags := Bind.dwFlags or DBPARAMFLAGS_ISINPUT;
    end;
  end else begin
    Bind.wType := SQLType2OleDBTypeEnum[SQLType];
    if (Ord(SQLType) < Ord(stBigDecimal)) or (SQLtype = stGUID) then
      InitFixedBind(Index, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType])
    else if Ord(SQLType) <= Ord(stTimestamp) then
       InitDateBind(Index, SQLType)
    else if Ord(SQLType) < Ord(stAsciiStream) then
      InitVaryBind(Index, Max(512, PrecisionOrSize), SQLType2OleDBTypeEnum[SQLType])
    else InitLongBind(Index, SQLType2OleDBTypeEnum[SQLType]);
  end;
  Bind.eParamIO :=  ParamType2OleIO[ParamType];
  inherited RegisterParameter(Index, SQLType, ParamType, Name, PrecisionOrSize, Scale);
end;

procedure TZOleDBPreparedStatement.ReleaseImmediat(
  const Sender: IImmediatelyReleasable; var AError: EZSQLConnectionLost);
begin
  FParameterAccessor := nil;
  SetLength(FDBBindingArray, 0);
  SetLength(FParamsBuffer, 0);
  inherited ReleaseImmediat(Sender, AError);
end;

{**
  Sets the designated parameter to a Java <code>AnsiString</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFNDEF NO_ANSISTRING}
procedure TZOleDBPreparedStatement.SetAnsiString(Index: Integer;
  const Value: AnsiString);
begin
  BindRaw(Index, Value, zOSCodePage);
end;
{$ENDIF}

{**
  Sets the designated parameter to a <code>java.math.BigDecimal</code> value.
  The driver converts this to an SQL <code>NUMERIC</code> value when
  it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFDEF NO_CONST_ZEROBCD}
const ZeroBCDFraction: packed array [0..31] of Byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
               0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
{$ENDIF}
procedure TZOleDBPreparedStatement.SetBigDecimal(Index: Integer;
  const Value: TBCD);
var Bind: PDBBINDING;
  Data: PAnsiChar;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NUMERIC:   BCD2SQLNumeric(Value, PDB_Numeric(Data));
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      {$IFDEF CPU64}
      DBTYPE_I1, DBTYPE_I2, DBTYPE_I4, DBTYPE_I8: InternalBindSInt(Index, stLong, BCD2Int64(Value));
      DBTYPE_UI1, DBTYPE_UI2, DBTYPE_UI4, DBTYPE_UI8: InternalBindUInt(Index, stULong, BCD2UInt64(Value));
      {$ELSE}
      DBTYPE_I1, DBTYPE_I2, DBTYPE_I4: InternalBindSInt(Index, stInteger, Integer(BCD2Int64(Value)));
      DBTYPE_I8:        PInt64(Data)^ := BCD2Int64(Value);
      DBTYPE_UI1, DBTYPE_UI2, DBTYPE_UI4: InternalBindUInt(Index, stLongWord, Cardinal(BCD2UInt64(Value)));
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI8:       PUInt64(Data)^ := BCD2UInt64(Value);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      {$ENDIF}
      DBTYPE_R4:        PSingle(Data)^ := BCDToDouble(Value);
      DBTYPE_R8:        PDouble(Data)^ := BCDToDouble(Value);
      DBTYPE_CY:        BCDToCurr(Value, PCurrency(Data)^);
      DBTYPE_BOOL:      PWordBool(Data)^ := not CompareMem(@Value.Fraction[0], @{$IFDEF NO_CONST_ZEROBCD}ZeroBCDFraction[0]{$ELSE}NullBcd.Fraction[0]{$ENDIF}, MaxFMTBcdDigits);
      DBTYPE_VARIANT:   POleVariant(Data)^ := BcdToSQLUni(Value);
      DBTYPE_WSTR: if Bind.cbMaxLen < {$IFDEF FPC}Byte{$ENDIF}(Value.Precision+2) shl 1 then begin //(64nibbles+dot+neg sign) -> test final length
                    PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := BcdToUni(Value, @fWBuffer[0], '.') shl 1;
                    if PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ < Bind.cbMaxLen
                    then Move(fWBuffer[0], Data^, PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^)
                    else RaiseExceeded(Index);
                  end else begin
                    PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := BcdToUni(Value, PWideChar(Data), '.') shl 1;
                  end;
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                   PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 68); //8Byte align
                   PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := BcdToUni(Value, ZPPWideChar(Data)^, '.') shl 1;;
                 end;
      //DBTYPE_VARNUMERIC:;
     else raise CreateOleDBConvertErrror(Index, Bind.wType, stBigDecimal);
    end;
  end else begin//Late binding
    InitFixedBind(Index, SizeOf(TDB_NUMERIC), DBTYPE_NUMERIC);
    BindList.Put(Index, Value);
  end;
end;

procedure TZOleDBPreparedStatement.SetBindCapacity(Capacity: Integer);
begin
  inherited SetBindCapacity(Capacity);
  if not fBindImmediat and not fDEFERPREPARE and (Bindlist.Count < Capacity) then
    SetParamCount(Capacity);
end;

procedure TZOleDBPreparedStatement.SetBindOffsets;
var I: Integer;
  Bind: PDBBINDING;
begin
  FRowSize := 0;
  for I := 0 to BindList.Count -1 do begin
    Bind := @FDBBindingArray[I];
    Bind.iOrdinal := I +1;
    Bind.obStatus := FRowSize;
    Inc(FRowSize, SizeOf(DBSTATUS));
    Bind.obLength := FRowSize;
    if Bind.dwPart and DBPART_LENGTH <> 0 then
      Inc(FRowSize, SizeOf(DBLENGTH));
    Bind.obValue := FRowSize;
    Inc(FRowSize, Bind.cbMaxLen);
    Bind.eParamIO := ParamType2OleIO[BindList.ParamTypes[I]];
    if Ord(BindList.ParamTypes[I]) >= Ord(pctInOut) then begin
      if BindList.ParamTypes[I] = pctInOut then
        Bind.dwFlags := Bind.dwFlags or DBPARAMFLAGS_ISINPUT or DBPARAMFLAGS_ISOUTPUT
      else
        Bind.dwFlags := Bind.dwFlags or DBPARAMFLAGS_ISOUTPUT;
    end else
      Bind.dwFlags := Bind.dwFlags or DBPARAMFLAGS_ISINPUT;
  end;
end;

{**
  Sets the designated parameter to the given input stream, which will have
  the specified number of bytes.
  When a very large binary value is input to a <code>LONGVARBINARY</code>
  parameter, it may be more practical to send it via a
  <code>java.io.InputStream</code> object. The data will be read from the stream
  as needed until end-of-file is reached.

  <P><B>Note:</B> This stream object can either be a standard
  Java stream object or your own subclass that implements the
  standard interface.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the java input stream which contains the binary parameter value
}
procedure TZOleDBPreparedStatement.SetBlob(Index: Integer; SQLType: TZSQLType;
  const Value: IZBlob);
var Bind: PDBBINDING;
  Data: PAnsichar;
  DBStatus: PDBSTATUS;
  DBLENGTH: PDBLENGTH;
label Fix_CLob;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  BindList.Put(Index, SQLType, Value);//keep alive
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    DBStatus := PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus);
    if (Value = nil) or Value.IsEmpty then begin
      DBSTATUS^ := DBSTATUS_S_ISNULL;
      Exit;
    end;
    DBSTATUS^ := DBSTATUS_S_OK;
    DBLENGTH := PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength);
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      (DBTYPE_STR or DBTYPE_BYREF):
        if Value.IsClob then begin
          PPointer(Data)^ := Value.GetPAnsiChar(FClientCP);
          DBLENGTH^ := Value.Length;
        end else begin
Fix_CLob: FRawTemp := GetValidatedAnsiStringFromBuffer(Value.GetBuffer, Value.Length, ConSettings);
          SetBLob(Index, stAsciiStream, TZAbstractCLob.CreateWithData(Pointer(FRawTemp),
            Length(FRawTemp), FClientCP, ConSettings));
        end;
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
              PPointer(Data)^ := Value.GetPWideChar;
              DBLENGTH^ := Value.Length;
            end;
      (DBTYPE_GUID or DBTYPE_BYREF):;
      (DBTYPE_BYTES or DBTYPE_BYREF): begin
          PPointer(Data)^ := Value.GetBuffer;
          DBLENGTH^ := Value.Length;
        end;
      DBTYPE_BYTES: begin
              DBLENGTH^ := Value.Length;
              if DBLENGTH^ < Bind.cbMaxLen
              then Move(Value.GetBuffer^, Data^, DBLENGTH^)
              else RaiseExceeded(Index);
            end;
      DBTYPE_STR: if Value.IsClob then begin
                Value.GetPAnsiChar(FClientCP);
                DBLENGTH^ := Value.Length;
                if DBLENGTH^ < Bind.cbMaxLen
                then Move(Value.GetBuffer^, Data^, DBLENGTH^)
                else RaiseExceeded(Index);
              end else
                goto Fix_CLob;
      DBTYPE_WSTR: begin
              Value.GetPWideChar;
              DBLENGTH^ := Value.Length;
              if DBLENGTH^ < Bind.cbMaxLen
              then Move(Value.GetBuffer^, Data^, DBLENGTH^)
              else RaiseExceeded(Index);
            end;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, SQLType);
    end;
  end else
    InitLongBind(Index, SQLType2OleDBTypeEnum[SQLType]);
end;

{**
  Sets the designated parameter to a Java <code>boolean</code> value.
  The driver converts this
  to an SQL <code>BIT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetBoolean(Index: Integer; Value: Boolean);
begin
  InternalBindUInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stBoolean, Ord(Value));
end;

{**
  Sets the designated parameter to a Java <code>unsigned 8Bit int</code> value.
  The driver converts this
  to an SQL <code>BYTE</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetByte(Index: Integer; Value: Byte);
begin
  InternalBindUInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stByte, Value);
end;

{**
  Sets the designated parameter to a Java array of bytes.  The driver converts
  this to an SQL <code>VARBINARY</code> or <code>LONGVARBINARY</code>
  (depending on the argument's size relative to the driver's limits on
  <code>VARBINARY</code> values) when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetBytes(Index: Integer;
  const Value: TBytes);
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  BindList.Put(Index, stBytes, Value); //localize
  if fBindImmediat
  then SetPAnsiChar(Index, Pointer(Value), Length(Value))
  else InitVaryBind(Index, Length(Value), DBTYPE_BYTES);
end;

procedure TZOleDBPreparedStatement.SetCharRec(Index: Integer;
  const Value: TZCharRec);
label set_from_tmp;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then
    if Value.CP = zCP_UTF16 then
      case FDBBindingArray[Index].wType of
        DBTYPE_STR, (DBTYPE_STR or DBTYPE_BYREF):
          SetRawByteString(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, PUnicodeToRaw(Value.P, Value.Len, FClientCP));
        else SetPWideChar(Index, Value.P, Value.Len)
      end
    else case FDBBindingArray[Index].wType of
      DBTYPE_WSTR, (DBTYPE_WSTR or DBTYPE_BYREF):
        goto set_from_tmp;
      DBTYPE_STR, (DBTYPE_STR or DBTYPE_BYREF):
        if FClientCP = Value.CP then
          SetPAnsiChar(Index, Value.P, Value.Len);
        else begin
set_from_tmp:
          FUniTemp := PRawToUnicode(Value.P, Value.Len, Value.CP);
          SetPWideChar(Index, Pointer(FUniTemp), Length(FUniTemp));
        end;
    end
  else begin
    InitVaryBind(Index, (Value.Len+1) shl 1, DBTYPE_WSTR);
    BindList.Put(Index, stString, Value.P, Value.Len, Value.CP);
  end;
end;

{**
  Sets the designated parameter to a Java <code>currency</code> value.
  The driver converts this
  to an SQL <code>CURRENCY</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetCurrency(Index: Integer;
  const Value: Currency);
var Bind: PDBBINDING;
  Data, PEnd: PAnsiChar;
  Negative: Boolean;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_I4:        PInteger(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_UI1:       PByte(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_I1:        PShortInt(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_UI2:       PWord(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_UI4:       PCardinal(Data)^ := PInt64(@Value)^ div 10000;
      DBTYPE_I8:        PInt64(Data)^ := PInt64(@Value)^ div 10000;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI8:       PUInt64(Data)^ := PInt64(@Value)^ div 10000;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      DBTYPE_WSTR: if Bind.cbMaxLen < 44 then begin //(19digits+dot+neg sign) -> test final length
                    CurrToUnicode(Value, @fWBuffer[0], @PEnd);
                    PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := PEnd-PAnsiChar(@fWBuffer[0]);
                    if PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ < Bind.cbMaxLen
                    then Move(fWBuffer[0], Data^, PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^)
                    else RaiseExceeded(Index);
                  end else begin
                    CurrToUnicode(Value, PWideChar(Data), @PEnd);
                    PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := PEnd-Data;
                  end;
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                   PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 48); //8Byte align
                   CurrToUnicode(Value, ZPPWideChar(Data)^, @PEnd);
                   PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := PEnd-PPAnsiChar(Data)^;
                 end;
      DBTYPE_NUMERIC: begin
                        PDB_NUMERIC(Data)^.precision := GetOrdinalDigits(PInt64(@Value)^, PUInt64(@PDB_NUMERIC(Data)^.val[0])^, Negative);
                        PDB_NUMERIC(Data)^.scale := 4;
                        PDB_NUMERIC(Data)^.sign := Ord(not Negative);
                        FillChar(PDB_NUMERIC(Data)^.val[SizeOf(Currency)], SQL_MAX_NUMERIC_LEN-SizeOf(Currency), #0);
                      end;
      //DBTYPE_VARNUMERIC:;
     else raise CreateOleDBConvertErrror(Index, Bind.wType, stCurrency);
    end;
  end else begin//Late binding
    InitFixedBind(Index, SizeOf(Currency), DBTYPE_CY);
    BindList.Put(Index, stCurrency, P8Bytes(@Value));
  end;
end;

procedure TZOleDBPreparedStatement.SetDataArray(ParameterIndex: Integer;
  const Value; const SQLType: TZSQLType; const VariantType: TZVariantType);
var arr: TZArray;
  GUID_Dyn: TGUIDDynArray;
  i,L: LengthInt;
  P: Pointer;
begin
  inherited SetDataArray(ParameterIndex, Value, SQLType, VariantType);
  if (ParameterIndex = FirstDbcIndex) and (BindList.ParamTypes[ParameterIndex {$IFNDEF GENERIC_INDEX}-1{$ENDIF}] <> pctResultSet) then
    FDBParams.cParamSets := 0;
  if (SQLType = stGUID) and not (VariantType in [vtNull, vtBytes]) then begin
    SetLength(GUID_Dyn, Length(TRawByteStringDynArray(Value)));
    Arr := PZArray(BindList[ParameterIndex {$IFNDEF GENERIC_INDEX}-1{$ENDIF}].Value)^;
    for I := 0 to High(GUID_Dyn) do
      ArrayValueToGUID(@Arr, i, @GUID_Dyn[i]);
    Arr.VArrayType := Ord(stGUID);
    Arr.VArrayVariantType := vtNull;
    BindList.Put(ParameterIndex {$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Arr, True);
  end;
  if not fDEFERPREPARE then begin
    {$IFNDEF GENERIC_INDEX}ParameterIndex := ParameterIndex -1;{$ENDIF}
    case SQLtype of
      stBigDecimal: InitFixedBind(ParameterIndex, SizeOf(Double), DBTYPE_R8);
      stDate: InitFixedBind(ParameterIndex, SizeOf(TDBDate), DBTYPE_DBDATE);
      stTime: InitFixedBind(ParameterIndex, SizeOf(TDBTIME2), DBTYPE_DBTIME2);
      stTimestamp: InitFixedBind(ParameterIndex, SizeOf(Double), DBTYPE_DATE);
      stString,
      stUnicodeString: begin
         P := PZArray(BindList[ParameterIndex].Value).VArray;
         L := 0;
         for I := 0 to {%H-}PArrayLenInt({%H-}NativeUInt(Value) - ArrayLenOffSet)^{$IFNDEF FPC}-1{$ENDIF} do
           case PZArray(BindList[ParameterIndex].Value).VArrayVariantType of
              {$IFNDEF UNICODE}vtString,{$ENDIF}
              vtAnsiString, vtUTF8String, VtRawByteString:  L := Max(L, Length(TRawByteStringDynArray(P)[I]));
              vtCharRec:                                    L := Max(L, TZCharRecDynArray(P)[I].Len);
              {$IFDEF UNICODE}vtString,{$ENDIF}
              vtUnicodeString:                              L := Max(L, Length(TUnicodeStringDynArray(P)[I]));
            end;
          InitVaryBind(ParameterIndex, (L+1) shl 1, DBTYPE_WSTR);
        end;
      stBytes: begin
          L := 0;
          for I := 0 to High(TBytesDynArray(Value)) do
            L := Max(L, Length(TBytesDynArray(Value)[I]));
          InitVaryBind(ParameterIndex, L, DBTYPE_BYTES);
        end;
      stAsciiStream,
      stUnicodeStream,
      stBinaryStream: InitLongBind(ParameterIndex, SQLType2OleDBTypeEnum[SQLType]);
      stUnknown, stArray, stDataSet: raise CreateOleDBConvertErrror(ParameterIndex, DBTYPE_WSTR, SQLType);
      else InitFixedBind(ParameterIndex, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType]);
    end;
  end;
end;

{**
  Sets the designated parameter to a <code<java.sql.Date</code> value.
  The driver converts this to an SQL <code>DATE</code>
  value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetDate(Index: Integer;
  const Value: TZDate);
var Bind: PDBBINDING;
  Data: PAnsichar;
  DT: TDateTime;
label DWConv;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:        PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_DATE:        if not TryDateToDateTime(Value, PDateTime(Data)^) then
                            raise CreateOleDBConvertErrror(Index, Bind.wType, stDate);
      DBTYPE_DBDATE:      begin
                            PDBDate(Data).year := Value.Year;
                            if Value.IsNegative then
                              PDBDate(Data).year := -PDBDate(Data).year;
                            PDBDate(Data).month := Value.Month;
                            PDBDate(Data).day := Value.Day;
                          end;
      DBTYPE_DBTIME:      FillChar(Data^, SizeOf(TDBTIME), #0);
      DBTYPE_DBTIME2:     FillChar(Data^, SizeOf(TDBTIME2), #0);
      DBTYPE_DBTIMESTAMP: begin
                            Fillchar(Data^, SizeOf(TDBTimeStamp), #0);
                            PDBTimeStamp(Data)^.year := Value.Year;
                            if Value.IsNegative then
                              PDBTimeStamp(Data)^.year := -PDBTimeStamp(Data)^.year;
                            PDBTimeStamp(Data)^.month := Value.Month;
                            PDBTimeStamp(Data)^.day := Value.Day;
                          end;
      DBTYPE_DBTIMESTAMPOFFSET: begin
                            Fillchar(Data^, SizeOf(TDBTIMESTAMPOFFSET), #0);
                            PDBTIMESTAMPOFFSET(Data)^.year := Value.Year;
                            if Value.IsNegative then
                              PDBTIMESTAMPOFFSET(Data)^.year := -PDBTimeStamp(Data)^.year;
                            PDBTIMESTAMPOFFSET(Data)^.month := Value.Month;
                            PDBTIMESTAMPOFFSET(Data)^.day := Value.Day;
                          end;
      DBTYPE_WSTR:  if Bind.cbMaxLen >= 22 then
DWConv:               PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        DateToUni(Value.Year, Value.Month, Value.Day,
                          PWideChar(Data), ConSettings.WriteFormatSettings.DateFormat,
                          False, Value.IsNegative) shl 1
                    else RaiseExceeded(Index);
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 24);
                      Data := PPointer(Data)^;
                      goto DWConv;
                    end;
      else          if TryDateToDateTime(Value, DT)
                    then InternalBindDbl(Index, stDate, DT)
                    else InternalBindSInt(Index, stDate, 1);
    end;
  end else begin//Late binding
    InitDateBind(Index, stDate);
    BindList.Put(Index, Value);
  end;
end;

{**
  Sets the designated parameter to a Java <code>double</code> value.
  The driver converts this
  to an SQL <code>DOUBLE</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetDouble(Index: Integer;
  const Value: Double);
begin
  InternalBindDbl(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stDouble, Value);
end;

{**
  Sets the designated parameter to a Java <code>float</code> value.
  The driver converts this
  to an SQL <code>FLOAT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetFloat(Index: Integer; Value: Single);
begin
  InternalBindDbl(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stFloat, Value);
end;

procedure TZOleDBPreparedStatement.SetGUID(Index: Integer; const Value: TGUID);
var Bind: PDBBINDING;
  Data: Pointer;
label set_uni_len, set_uid_len;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_GUID:  PGUID(Data)^ := Value;
      (DBTYPE_GUID or DBTYPE_BYREF): begin
                        BindList.Put(Index, Value); //localize
                        PPointer(Data)^ := BindList[Index].Value;
                      end;
      DBTYPE_BYTES: if Bind.cbMaxLen < SizeOf(TGUID) then
                      RaiseExceeded(Index)
                    else begin
                      PGUID(Data)^ := Value;
                      goto set_uid_len;
                    end;
      DBTYPE_BYTES or DBTYPE_BYREF: begin
                        BindList.Put(Index, Value); //localize
                        PPointer(Data)^ := BindList[Index].Value;
set_uid_len:            PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=  SizeOf(TGUID);
                      end;
(*      DBTYPE_STR: if Bind.cbMaxLen < 37 then
                    RaiseExceeded(Index)
                  else begin
                    GUIDToBuffer(@Value.D1, PAnsiChar(Data), [guidSet0Term]);
                    goto set_raw_len;
                  end;
      (DBTYPE_STR or DBTYPE_BYREF): begin
                    PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 37);
                    GUIDToBuffer(@Value.D1, PPAnsiChar(Data)^, [guidSet0Term]);
set_raw_len:        PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := 36;
                  end; *)
      DBTYPE_WSTR:if Bind.cbMaxLen < 74 then
                    RaiseExceeded(Index)
                  else begin
                    GUIDToBuffer(@Value.D1, PWideChar(Data), [guidSet0Term]);
                    goto set_uni_len;
                  end;
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                    PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 74);
                    GUIDToBuffer(@Value.D1, ZPPWideChar(Data)^, [guidSet0Term]);
set_uni_len:        PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := 72;
                  end;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, stGUID);
    end;
  end else begin
    InitFixedBind(Index, SizeOf(TGUID), DBTYPE_GUID);
    BindList.Put(Index, Value);
  end;
end;

{**
  Sets the designated parameter to a Java <code>int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.AddParamLogValue(ParamIndex: Integer;
  SQLWriter: TZRawSQLStringWriter; var Result: RawByteString);
var Bind: PDBBINDING;
  Data: Pointer;
  Len: NativeUInt;
begin
  case BindList.ParamTypes[ParamIndex] of
    pctReturn: SQLWriter.AddText('(RETURN_VALUE)', Result);
    pctOut: SQLWriter.AddText('(OUT_PARAM)', Result);
    else begin
      Bind := @FDBBindingArray[ParamIndex];
      if PDBSTATUS(NativeUInt(FDBParams.pData)+Bind.obStatus)^ = DBSTATUS_S_ISNULL then
        SQLWriter.AddText('(NULL)', Result)
      else begin
        Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
        case Bind.wType of
          DBTYPE_NULL:  SQLWriter.AddText('(NULL)', Result);
          (DBTYPE_STR   or DBTYPE_BYREF): SQLWriter.AddText('(CLOB/VARCHAR(MAX))', Result);
          (DBTYPE_WSTR  or DBTYPE_BYREF): SQLWriter.AddText('(NCLOB/NVARCHAR(MAX))', Result);
          (DBTYPE_BYTES or DBTYPE_BYREF): SQLWriter.AddText('(BLOB/VARBINARY(MAX))', Result);
          DBTYPE_BOOL:  if PWordBool(Data)^
                        then SQLWriter.AddText('(TRUE)', Result)
                        else SQLWriter.AddText('(FALSE)', Result);
          DBTYPE_I1:    SQLWriter.AddOrd(PShortInt(Data)^, Result);
          DBTYPE_UI1:   SQLWriter.AddOrd(PByte(Data)^, Result);
          DBTYPE_I2:    SQLWriter.AddOrd(PSmallInt(Data)^, Result);
          DBTYPE_UI2:   SQLWriter.AddOrd(PWord(Data)^, Result);
          DBTYPE_I4:    SQLWriter.AddOrd(PInteger(Data)^, Result);
          DBTYPE_UI4:   SQLWriter.AddOrd(PCardinal(Data)^, Result);
          DBTYPE_I8:    SQLWriter.AddOrd(PInt64(Data)^, Result);
          DBTYPE_UI8:   SQLWriter.AddOrd(PUInt64(Data)^, Result);
          DBTYPE_R4:    SQLWriter.AddFloat(PSingle(Data)^, Result);
          DBTYPE_R8:    SQLWriter.AddFloat(PDouble(Data)^, Result);
          DBTYPE_CY:    SQLWriter.AddDecimal(PCurrency(Data)^, Result);
          DBTYPE_GUID:  SQLWriter.AddGUID(PGUID(Data)^, [guidWithBrackets, guidQuoted], Result);
          DBTYPE_NUMERIC: begin
                        SQLNumeric2Raw(PDB_Numeric(Data), @fABuffer[0], Len);
                        SQLWriter.AddText(@fABuffer[0], Len, Result);
                      end;
          DBTYPE_BYTES: SQLWriter.AddHexBinary(Data, PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^, True, Result);
          DBTYPE_WSTR:  SQLWriter.AddText(SQLQuotedStr(PUnicodeToRaw(Data, PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^, ConSettings.CTRL_CP),#39), Result);
          DBTYPE_DBDATE:begin
                        Len := DateToRaw(Abs(PDBDATE(Data)^.year), PDBDATE(Data)^.month,
                          PDBDATE(Data)^.day, PAnsiChar(@fABuffer[0]), ConSettings.WriteFormatSettings.DateFormat, True, PDBDATE(Data)^.year <0);
                        SQLWriter.AddText(@fABuffer[0], Len, Result);
                      end;
          DBTYPE_DATE:  SQLWriter.AddDate(PDateTime(Data)^, ConSettings.WriteFormatSettings.DateFormat, Result);
          DBTYPE_DBTIME: begin
                        Len := TimeToRaw(PDBTIME(Data)^.hour, PDBTIME(Data)^.minute,
                          PDBTIME(Data)^.second, 0, @fABuffer[0],  ConSettings.WriteFormatSettings.TimeFormat, True, False);
                        SQLWriter.AddText(@fABuffer[0], Len, Result);
                      end;
          DBTYPE_DBTIME2: begin
                        Len := TimeToRaw(PDBTIME2(Data)^.hour, PDBTIME2(Data)^.minute,
                          PDBTIME2(Data)^.second, PDBTIME2(Data)^.fraction, @fABuffer[0],
                          ConSettings.WriteFormatSettings.DateTimeFormat, True, False);
                        SQLWriter.AddText(@fABuffer[0], Len, Result);
                      end;
          DBTYPE_DBTIMESTAMP: begin
                        Len := DateTimeToRaw(Abs(PDBTimeStamp(Data)^.year),
                          PDBTimeStamp(Data).month, PDBTimeStamp(Data).day, PDBTimeStamp(Data).hour,
                          PDBTimeStamp(Data)^.minute, PDBTimeStamp(Data)^.second,  PDBTimeStamp(Data)^.fraction,
                          @fABuffer[0],  ConSettings.WriteFormatSettings.DateTimeFormat, True, PDBTimeStamp(Data)^.year < 0);
                        SQLWriter.AddText(@fABuffer[0], Len, Result);
                      end;
          else Result := '(unknown)';
        end;
      end;
    end;
  end;
end;

procedure TZOleDBPreparedStatement.SetInt(Index, Value: Integer);
begin
  InternalBindSInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stInteger, Value);
end;

{**
  Sets the designated parameter to a Java <code>long</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetLong(Index: Integer; const Value: Int64);
{$IFDEF CPU64}
begin
  InternalBindSInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stLong, Value);
{$ELSE}
var Bind: PDBBINDING;
  Data: PAnsichar;
  u64: UInt64;
  L: Cardinal;
  Negative: Boolean;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := Value;
      DBTYPE_I4:        PInteger(Data)^ := Value;
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_UI1:       PByte(Data)^ := Value;
      DBTYPE_I1:        PShortInt(Data)^ := Value;
      DBTYPE_UI2:       PWord(Data)^ := Value;
      DBTYPE_UI4:       PCardinal(Data)^ := Value;
      DBTYPE_I8:        PInt64(Data)^ := Value;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI8:       PUInt64(Data)^ := Value;
      DBTYPE_WSTR, (DBTYPE_WSTR or DBTYPE_BYREF): begin
          L := GetOrdinalDigits(Value, u64, Negative);
          if Bind.wType = (DBTYPE_WSTR or DBTYPE_BYREF) then begin
            PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 24); //8Byte align
            Data := PPointer(Data)^; //-9.223.372.036.854.775.808
          end else if (Bind.cbMaxLen <= (L +Byte(Ord(Negative))) shl 1) then
            RaiseExceeded(Index);
          if Negative then
            PWord(PPointer(Data)^)^ := Ord('-');
          IntToUnicode(u64, PWideChar(Data)+Ord(Negative), L);
          PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := L shl 1 + Byte(Ord(Negative));
        end;
      DBTYPE_NUMERIC: begin
                        PDB_NUMERIC(Data)^.precision := GetOrdinalDigits(PInt64(@Value)^, PUInt64(@PDB_NUMERIC(Data)^.val[0])^, Negative);
                        PDB_NUMERIC(Data)^.scale := 0;
                        PDB_NUMERIC(Data)^.sign := Ord(not Negative);
                        FillChar(PDB_NUMERIC(Data)^.val[SizeOf(UInt64)], SQL_MAX_NUMERIC_LEN-SizeOf(UInt64), #0);
                      end;
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      //DBTYPE_VARNUMERIC:;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, stLong);
    end;
  end else begin//Late binding
    InitFixedBind(Index, SizeOf(Int64), DBTYPE_I8);
    BindList.Put(Index, stLong, P8Bytes(@Value));
  end;
  {$ENDIF}
end;

{**
  Sets the designated parameter to SQL <code>NULL</code>.
  <P><B>Note:</B> You must specify the parameter's SQL type.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param sqlType the SQL type code defined in <code>java.sql.Types</code>
}
procedure TZOleDBPreparedStatement.SetNull(Index: Integer; SQLType: TZSQLType);
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then
    PDBSTATUS(NativeUInt(FDBParams.pData)+FDBBindingArray[Index].obStatus)^ := DBSTATUS_S_ISNULL
  else begin
    if SQLType = stUnknown then
      SQLtype := BindList.SQLTypes[Index];
    BindList.SetNull(Index, SQLType);
    if Ord(SQLType) < Ord(stString) then
      if SQLType in [stDate, stTime, stTimeStamp]
      then InitDateBind(Index, SQLType)
      else InitFixedBind(Index, ZSQLTypeToBuffSize[SQLType], SQLType2OleDBTypeEnum[SQLType])
    else if Ord(SQLType) < Ord(stAsciiStream) then
      InitFixedBind(Index, 512, SQLType2OleDBTypeEnum[SQLType])
    else InitLongBind(Index, SQLType2OleDBTypeEnum[SQLType])
  end;
end;

procedure TZOleDBPreparedStatement.SetOleCommandProperties;
var
  FCmdProps: ICommandProperties;
  rgCommonProperties: array[0..20] of TDBProp;
  rgProviderProperties: TDBProp;
  rgPropertySets: array[0..1] of TDBPROPSET;
  Provider: TZServerProvider;
  Status: HResult;

  procedure SetProp(var PropSet: TDBPROPSET; PropertyID: DBPROPID; Value: SmallInt);
  begin
    //initialize common property options
    //VariantInit(PropSet.rgProperties^[PropSet.cProperties].vValue);
    PropSet.rgProperties^[PropSet.cProperties].dwPropertyID := PropertyID;
    PropSet.rgProperties^[PropSet.cProperties].dwOptions    := DBPROPOPTIONS_REQUIRED;
    PropSet.rgProperties^[PropSet.cProperties].dwStatus     := 0;
    PropSet.rgProperties^[PropSet.cProperties].colid        := DB_NULLID;
    PropSet.rgProperties^[PropSet.cProperties].vValue       := Value;
    Inc(PropSet.cProperties);
  end;
begin
  FCmdProps := nil; //init
  if Succeeded(fCommand.QueryInterface(IID_ICommandProperties, FCmdProps)) then begin
    Provider := Connection.GetServerProvider;
    //http://msdn.microsoft.com/en-us/library/windows/desktop/ms723066%28v=vs.85%29.aspx
    rgPropertySets[0].cProperties     := 0; //init
    rgPropertySets[0].guidPropertySet := DBPROPSET_ROWSET;
    rgPropertySets[0].rgProperties    := @rgCommonProperties[0];
    rgPropertySets[1].cProperties     := 0;
    case Provider of
      spMSSQL: rgPropertySets[1].guidPropertySet := DBPROPSET_SQLSERVERROWSET
      else rgPropertySets[1].guidPropertySet := DBPROPSET_ROWSET;
    end;
    rgPropertySets[1].rgProperties    := @rgProviderProperties;

    SetProp(rgPropertySets[0], DBPROP_COMMANDTIMEOUT,    Max(0, fStmtTimeOut)); //Set command time_out static!
    SetProp(rgPropertySets[0], DBPROP_SERVERCURSOR,      VARIANT_TRUE); //force a server side cursor
    if (Provider = spMSSQL) then begin
      //turn off deferred prepare -> raise exception on Prepare if command can't be executed!
      //http://msdn.microsoft.com/de-de/library/ms130779.aspx
      if fDEFERPREPARE
      then SetProp(rgPropertySets[1], SSPROP_DEFERPREPARE, VARIANT_FALSE)
      else SetProp(rgPropertySets[1], SSPROP_DEFERPREPARE, VARIANT_TRUE);
    end else begin
      //to avoid http://support.microsoft.com/kb/272358/de we need a
      //FAST_FORWARD(RO) server cursor
      {common sets which are NOT default: according the cursor models of
      http://msdn.microsoft.com/de-de/library/ms130840.aspx }
      SetProp(rgPropertySets[0], DBPROP_UNIQUEROWS,        VARIANT_FALSE);
      if (Connection as IZOleDBConnection).SupportsMARSConnection then begin
        SetProp(rgPropertySets[0], DBPROP_OWNINSERT,         VARIANT_FALSE);
        SetProp(rgPropertySets[0], DBPROP_OWNUPDATEDELETE,   VARIANT_FALSE);
      end else begin
        SetProp(rgPropertySets[0], DBPROP_OWNINSERT,         VARIANT_TRUE);  //slow down by 20% but if isn't set it breaks multiple connection ):
        SetProp(rgPropertySets[0], DBPROP_OWNUPDATEDELETE,   VARIANT_TRUE);  //slow down by 20% but if isn't set it breaks multiple connection ):
      end;
      SetProp(rgPropertySets[0], DBPROP_OTHERINSERT,       VARIANT_TRUE);
      SetProp(rgPropertySets[0], DBPROP_OTHERUPDATEDELETE, VARIANT_TRUE);
      SetProp(rgPropertySets[0], DBPROP_UNIQUEROWS,         VARIANT_FALSE);
      SetProp(rgPropertySets[0], DBPROP_CANFETCHBACKWARDS,  VARIANT_FALSE);
      SetProp(rgPropertySets[0], DBPROP_CANSCROLLBACKWARDS, VARIANT_FALSE);
    end;
    try
      Status := FCmdProps.SetProperties(2,@rgPropertySets[0]);
      if Failed(Status) then
        OleDBCheck(Status, SQL, Self, nil);
    finally
      FCmdProps := nil;
    end;
  end;
end;

procedure TZOleDBPreparedStatement.SetPAnsiChar(Index: Word; Value: PAnsiChar;
  Len: Cardinal);
var Bind: PDBBINDING;
  Data: PAnsichar;
  TS: TZTimeStamp;
  T: TZTime absolute TS;
  D: TZDate absolute TS;
label Fail;
begin
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := RawToIntDef(Value, Value+Len, 0);
      DBTYPE_I4:        PInteger(Data)^  := RawToIntDef(Value, Value+Len, 0);
      DBTYPE_R4:        SQLStrToFloatDef(Value, 0, PSingle(Data)^, Len);
      DBTYPE_R8:        SQLStrToFloatDef(Value, 0, PDouble(Data)^, Len);
      DBTYPE_CY:        SQLStrToFloatDef(Value, 0, PCurrency(Data)^, Len);
      DBTYPE_DATE:      if not TryPCharToDateTime(Value, Len, ConSettings^.WriteFormatSettings, PDateTime(Data)^) then
                          goto Fail;
      //DBTYPE_IDISPATCH	= 9;
      //DBTYPE_ERROR	= 10;
      DBTYPE_BOOL:      PWordBool(Data)^ := StrToBoolEx(Value, Value+Len, True, False);
      //DBTYPE_VARIANT	= 12;
      //DBTYPE_IUNKNOWN	= 13;
      DBTYPE_UI1:       PByte(Data)^    := RawToIntDef(Value, Value+Len, 0);
      DBTYPE_I1:        PShortInt(Data)^:= RawToIntDef(Value, Value+Len, 0);
      DBTYPE_UI2:       PWord(Data)^    := RawToIntDef(Value, Value+Len, 0);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI4:       PCardinal(Data)^:= RawToUInt64Def(Value, Value+Len, 0);
      DBTYPE_UI8:       PUInt64(Data)^  := RawToUInt64Def(Value, Value+Len, 0);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      DBTYPE_GUID:      if Len = SizeOf(TGUID)
                        then Move(Value^, Data^, SizeOf(TGUID))
                        else ValidGUIDToBinary(Value, Data);
      (DBTYPE_GUID or DBTYPE_BYREF): if Len = SizeOf(TGUID) then
                          PPointer(Data)^ := Value
                        else begin
                          ValidGUIDToBinary(Value, @fWBuffer[0]);
                          BindList.Put(Index, PGUID(@fWBuffer[0])^);
                          PPointer(Data)^ := BindList[Index].Value;
                        end;
      DBTYPE_BYTES,
      DBTYPE_STR:       if Bind.cbMaxLen < Len+Byte(Ord(Bind.wType = DBTYPE_STR)) then
                          RaiseExceeded(Index)
                        else begin
                          Move(Value^, Data^, Len+Byte(Ord(Bind.wType = DBTYPE_STR)));
                          PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len;
                        end;
      (DBTYPE_BYTES or DBTYPE_BYREF),
      (DBTYPE_STR or DBTYPE_BYREF): begin
              PPointer(Data)^ := Value;
              PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len;
            end;
      DBTYPE_DBDATE:  if TryPCharToDate(Value, Len, ConSettings^.WriteFormatSettings, D) then begin
                        PDBDate(Data)^.year := D.Year;
                        if D.IsNegative then
                          PDBDate(Data)^.year := -PDBDate(Data)^.year;
                        PDBDate(Data)^.month := D.Month;
                        PDBDate(Data)^.day := D.Day;
                      end else goto Fail;
      DBTYPE_DBTIME:  if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T) then begin
                        PDBTime(Data)^.hour := T.Hour;
                        PDBTime(Data)^.minute := T.Minute;
                        PDBTime(Data)^.second := t.Second;
                      end else goto Fail;
      DBTYPE_DBTIME2: if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T) then begin
                        PDBTIME2(Data)^.hour := T.Hour;
                        PDBTIME2(Data)^.minute := T.Minute;
                        PDBTIME2(Data)^.second := T.Second;
                        PDBTIME2(Data)^.fraction := T.Fractions;
                      end else goto Fail;
      DBTYPE_DBTIMESTAMP:if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                        PDBTimeStamp(Data)^.year := TS.Year;
                        if Ts.IsNegative then
                          PDBTimeStamp(Data)^.year := -PDBTimeStamp(Data)^.year;
                        PDBTimeStamp(Data)^.month := TS.Month;
                        PDBTimeStamp(Data)^.day := TS.Day;
                        PDBTimeStamp(Data)^.hour := TS.Hour;
                        PDBTimeStamp(Data)^.minute := TS.Minute;
                        PDBTimeStamp(Data)^.second := TS.Second;
                        PDBTimeStamp(Data)^.fraction := TS.Fractions;
                      end else goto Fail;
      DBTYPE_DBTIMESTAMPOFFSET:if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                        PDBTimeStamp(Data)^.year := TS.Year;
                        if Ts.IsNegative then
                          PDBTIMESTAMPOFFSET(Data)^.year := -PDBTIMESTAMPOFFSET(Data)^.year;
                        PDBTIMESTAMPOFFSET(Data)^.month := TS.Month;
                        PDBTIMESTAMPOFFSET(Data)^.day := TS.Day;
                        PDBTIMESTAMPOFFSET(Data)^.hour := TS.Hour;
                        PDBTIMESTAMPOFFSET(Data)^.minute := TS.Minute;
                        PDBTIMESTAMPOFFSET(Data)^.second := TS.Second;
                        PDBTIMESTAMPOFFSET(Data)^.fraction := TS.Fractions;
                        PDBTIMESTAMPOFFSET(Data)^.timezone_hour := TS.TimeZoneHour;
                        PDBTIMESTAMPOFFSET(Data)^.timezone_minute := TS.TimeZoneMinute;
                      end else goto Fail;
     else
Fail:    raise CreateOleDBConvertErrror(Index, Bind.wType, stString);
      //DBTYPE_UDT: ;
      //DBTYPE_HCHAPTER:;
      //DBTYPE_PROPVARIANT:;
      //DBTYPE_VARNUMERIC:;
    end;
  end;
end;

procedure TZOleDBPreparedStatement.SetParamCount(NewParamCount: Integer);
var OldParamCount: Integer;
begin
  OldParamCount := BindList.Count;
  if OldParamCount <> NewParamCount then begin
    inherited SetParamCount(NewParamCount);
    SetLength(FDBBindingArray, NewParamCount);
    SetLength(FDBBINDSTATUSArray, NewParamCount);
  end;
end;

procedure TZOleDBPreparedStatement.SetPWideChar(Index: Word; Value: PWideChar;
  Len: Cardinal);
var Bind: PDBBINDING;
  Data: PAnsichar;
  TS: TZTimeStamp;
  T: TZTime absolute TS;
  D: TZDate absolute TS;
label Fail, set_Raw;
begin
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := UnicodeToIntDef(Value, Value+Len, 0);
      DBTYPE_I4:        PInteger(Data)^  := UnicodeToIntDef(Value, Value+Len, 0);
      DBTYPE_R4:        SQLStrToFloatDef(Value, 0, PSingle(Data)^, Len);
      DBTYPE_R8:        SQLStrToFloatDef(Value, 0, PDouble(Data)^, Len);
      DBTYPE_CY:        SQLStrToFloatDef(Value, 0, PCurrency(Data)^, Len);
      DBTYPE_DATE:      if not TryPCharToDateTime(Value, Len, ConSettings^.WriteFormatSettings, PDateTime(Data)^) then
                          goto Fail;
      //DBTYPE_IDISPATCH	= 9;
      //DBTYPE_ERROR	= 10;
      DBTYPE_BOOL:      PWordBool(Data)^ := StrToBoolEx(Value, Value+Len, True, False);
      //DBTYPE_VARIANT	= 12;
      //DBTYPE_IUNKNOWN	= 13;
      DBTYPE_UI1:       PByte(Data)^    := UnicodeToIntDef(Value, Value+Len, 0);
      DBTYPE_I1:        PShortInt(Data)^:= UnicodeToIntDef(Value, Value+Len, 0);
      DBTYPE_UI2:       PWord(Data)^    := UnicodeToIntDef(Value, Value+Len, 0);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      DBTYPE_UI4:       PCardinal(Data)^:= UnicodeToUInt64Def(Value, Value+Len, 0);
      DBTYPE_UI8:       PUInt64(Data)^  := UnicodeToUInt64Def(Value, Value+Len, 0);
      {$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      DBTYPE_I8:        PInt64(Data)^   := UnicodeToInt64Def(Value, Value+Len, 0);
      DBTYPE_GUID:      ValidGUIDToBinary(Value, Data);
      DBTYPE_GUID or DBTYPE_BYREF: begin
                          ValidGUIDToBinary(Value, @fWBuffer[0]);
                          BindList.Put(Index, PGUID(@fWBuffer[0])^);
                          PPointer(Data)^ := BindList[Index].Value;
                        end;
      DBTYPE_BYTES, (DBTYPE_BYTES or DBTYPE_BYREF): begin
            FRawTemp := UnicodeStringToAscii7(Value, Len);
            goto set_Raw;
          end;
      DBTYPE_STR, (DBTYPE_STR or DBTYPE_BYREF): begin
            FRawTemp := PUnicodeToRaw(Value, Len, FClientCP);
            Len := Length(FRawTemp);
set_Raw:    if Bind.wType and DBTYPE_BYREF <> 0 then begin
              BindList.Put(Index, stString, FRawTemp, FClientCP); //keep alive
              PPointer(Data)^ := Pointer(FRawTemp);
              PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len;
            end else if Bind.cbMaxLen < Len then
              RaiseExceeded(Index)
            else begin
              Move(Pointer(FRawTemp)^, Data^, Len);
              PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len;
            end;
          end;
      DBTYPE_WSTR:  if Bind.cbMaxLen < Len*2 then
                      RaiseExceeded(Index)
                    else begin
                      Move(Value^, Data^, Len shl 1);
                      PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len shl 1;
                    end;
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                  PPointer(Data)^ := Value;
                  PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := Len shl 1;
                end;
      DBTYPE_DBDATE:  if TryPCharToDate(Value, Len, ConSettings^.WriteFormatSettings, D) then begin
                        PDBDate(Data)^.year := D.Year;
                        if D.IsNegative then
                          PDBDate(Data)^.year := -PDBDate(Data)^.year;
                        PDBDate(Data)^.month := D.Month;
                        PDBDate(Data)^.day := D.Day;
                      end else goto Fail;
      DBTYPE_DBTIME:  if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T) then begin
                        PDBTime(Data)^.hour := T.Hour;
                        PDBTime(Data)^.minute := T.Minute;
                        PDBTime(Data)^.second := t.Second;
                      end else goto Fail;
      DBTYPE_DBTIME2: if TryPCharToTime(Value, Len, ConSettings^.WriteFormatSettings, T) then begin
                        PDBTIME2(Data)^.hour := T.Hour;
                        PDBTIME2(Data)^.minute := T.Minute;
                        PDBTIME2(Data)^.second := T.Second;
                        PDBTIME2(Data)^.fraction := T.Fractions;
                      end else goto Fail;
      DBTYPE_DBTIMESTAMP:if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                        PDBTimeStamp(Data)^.year := TS.Year;
                        if Ts.IsNegative then
                          PDBTimeStamp(Data)^.year := -PDBTimeStamp(Data)^.year;
                        PDBTimeStamp(Data)^.month := TS.Month;
                        PDBTimeStamp(Data)^.day := TS.Day;
                        PDBTimeStamp(Data)^.hour := TS.Hour;
                        PDBTimeStamp(Data)^.minute := TS.Minute;
                        PDBTimeStamp(Data)^.second := TS.Second;
                        PDBTimeStamp(Data)^.fraction := TS.Fractions;
                      end else goto Fail;
      DBTYPE_DBTIMESTAMPOFFSET:if TryPCharToTimeStamp(Value, Len, ConSettings^.WriteFormatSettings, TS) then begin
                        PDBTimeStamp(Data)^.year := TS.Year;
                        if Ts.IsNegative then
                          PDBTIMESTAMPOFFSET(Data)^.year := -PDBTIMESTAMPOFFSET(Data)^.year;
                        PDBTIMESTAMPOFFSET(Data)^.month := TS.Month;
                        PDBTIMESTAMPOFFSET(Data)^.day := TS.Day;
                        PDBTIMESTAMPOFFSET(Data)^.hour := TS.Hour;
                        PDBTIMESTAMPOFFSET(Data)^.minute := TS.Minute;
                        PDBTIMESTAMPOFFSET(Data)^.second := TS.Second;
                        PDBTIMESTAMPOFFSET(Data)^.fraction := TS.Fractions;
                        PDBTIMESTAMPOFFSET(Data)^.timezone_hour := TS.TimeZoneHour;
                        PDBTIMESTAMPOFFSET(Data)^.timezone_minute := TS.TimeZoneMinute;
                      end else goto Fail;
      else
Fail:     raise CreateOleDBConvertErrror(Index, Bind.wType, stUnicodeString);
      //DBTYPE_UDT: ;
      //DBTYPE_HCHAPTER:;
      //DBTYPE_PROPVARIANT:;
      //DBTYPE_VARNUMERIC:;
    end;
  end;
end;

{**
  Sets the designated parameter to a Java <code>raw encoded string</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetRawByteString(Index: Integer;
  const Value: RawByteString);
begin
  BindRaw(Index, Value, FClientCP);
end;

{**
  Sets the designated parameter to a Java <code>ShortInt</code> value.
  The driver converts this
  to an SQL <code>ShortInt</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetShort(Index: Integer; Value: ShortInt);
begin
  InternalBindSInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stShort, Value);
end;

{**
  Sets the designated parameter to a Java <code>SmallInt</code> value.
  The driver converts this
  to an SQL <code>ShortInt</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetSmall(Index: Integer; Value: SmallInt);
begin
  InternalBindSInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stSmall, Value);
end;

{**
  Sets the designated parameter to a Java <code>String</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetString(Index: Integer;
  const Value: String);
begin
  {$IFDEF UNICODE}
  SetUnicodeString(Index, Value);
  {$ELSE}
  if ConSettings^.AutoEncode
  then BindRaw(Index, Value, zCP_NONE)
  else BindRaw(Index, Value, ConSettings^.CTRL_CP);
  {$ENDIF}
end;

{**
  Sets the designated parameter to a <code>java.sql.Time</code> value.
  The driver converts this to an SQL <code>TIME</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetTime(Index: Integer;
  const Value: TZTime);
var Bind: PDBBINDING;
  Data: PAnsichar;
  DT: TDateTime;
label TWConv;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:        PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_DATE:        if not TryTimeToDateTime(Value, PDateTime(Data)^) then
                            raise CreateOleDBConvertErrror(Index, Bind.wType, stTime);
      DBTYPE_DBDATE:      FillChar(Data^, SizeOf(TDBDate), #0);
      DBTYPE_DBTIME:      begin
                            PDBTIME(Data)^.hour := Value.Hour;
                            PDBTIME(Data)^.minute := Value.Minute;
                            PDBTIME(Data)^.second := Value.Second;
                          end;
      DBTYPE_DBTIME2:     begin
                            PDBTIME2(Data)^.hour := Value.Hour;
                            PDBTIME2(Data)^.minute := Value.Minute;
                            PDBTIME2(Data)^.second := Value.Second;
                            PDBTIME2(Data)^.fraction := Value.Fractions;
                          end;
      DBTYPE_DBTIMESTAMP: begin
                            PDBTimeStamp(Data)^.year := cPascalIntegralDatePart.Year;
                            PDBTimeStamp(Data)^.month := cPascalIntegralDatePart.Month;
                            PDBTimeStamp(Data)^.day := cPascalIntegralDatePart.Day;
                            PDBTimeStamp(Data)^.hour := Value.Hour;
                            PDBTimeStamp(Data)^.minute := Value.Minute;
                            PDBTimeStamp(Data)^.second := Value.Second;
                            PDBTimeStamp(Data)^.fraction := Value.Fractions;
                          end;
      DBTYPE_DBTIMESTAMPOFFSET: begin
                            PDBTIMESTAMPOFFSET(Data)^.year := cPascalIntegralDatePart.Year;
                            PDBTIMESTAMPOFFSET(Data)^.month := cPascalIntegralDatePart.Month;
                            PDBTIMESTAMPOFFSET(Data)^.day := cPascalIntegralDatePart.Day;
                            PDBTIMESTAMPOFFSET(Data)^.hour := Value.Hour;
                            PDBTIMESTAMPOFFSET(Data)^.minute := Value.Minute;
                            PDBTIMESTAMPOFFSET(Data)^.second := Value.Second;
                            PDBTIMESTAMPOFFSET(Data)^.fraction := Value.Fractions;
                            PDBTIMESTAMPOFFSET(Data)^.timezone_hour := 0;
                            PDBTIMESTAMPOFFSET(Data)^.timezone_minute := 0;
                          end;
      DBTYPE_WSTR:  if (Bind.cbMaxLen >= 26 ){00.00.00.000#0} or ((Bind.cbMaxLen-2) shr 1 = DBLENGTH(ConSettings.WriteFormatSettings.TimeFormatLen)) then
TWConv:               PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        TimeToUni(Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                        PWideChar(Data), ConSettings.WriteFormatSettings.TimeFormat, False, Value.IsNegative) shl 1
                      else RaiseExceeded(Index);
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 24);
                      Data := PPointer(Data)^;
                      goto TWConv;
                    end;
      else          if TryTimeToDateTime(Value, DT)
                    then InternalBindDbl(Index, stTime, DT)
                    else InternalBindSint(Index, stTime, 1);
    end;
  end else begin//Late binding
    InitDateBind(Index, stTime);
    BindList.Put(Index, Value);
  end;
end;

{**
  Sets the designated parameter to a <code>java.sql.Timestamp</code> value.
  The driver converts this to an SQL <code>TIMESTAMP</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetTimestamp(Index: Integer;
  const Value: TZTimeStamp);
var Bind: PDBBINDING;
  Data: PAnsichar;
  DT: TDateTime;
label TSWConv;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:        PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_DATE:        if not TryTimeStampToDateTime(Value, PDateTime(Data)^) then
                            raise CreateOleDBConvertErrror(Index, Bind.wType, stTimeStamp);
      DBTYPE_DBDATE:      begin
                            PDBDate(Data).year := Value.Year;
                            if Value.IsNegative then
                              PDBDate(Data).year := -PDBDate(Data).year;
                            PDBDate(Data).month := Value.Month;
                            PDBDate(Data).day := Value.Day;
                          end;
      DBTYPE_DBTIME:      begin
                            PDBTIME(Data)^.hour := Value.Hour;
                            PDBTIME(Data)^.minute := Value.Minute;
                            PDBTIME(Data)^.second := Value.Second;
                          end;
      DBTYPE_DBTIME2:     begin
                            PDBTIME2(Data)^.hour := Value.Hour;
                            PDBTIME2(Data)^.minute := Value.Minute;
                            PDBTIME2(Data)^.second := Value.Second;
                            PDBTIME2(Data)^.fraction := Value.Fractions;
                          end;
      DBTYPE_DBTIMESTAMP: begin
                            PDBTimeStamp(Data)^.year := Value.Year;
                            if Value.IsNegative then
                              PDBTimeStamp(Data)^.year := -PDBTimeStamp(Data)^.year;
                            PDBTimeStamp(Data)^.month := Value.Month;
                            PDBTimeStamp(Data)^.day := Value.Day;
                            PDBTimeStamp(Data)^.hour := Value.Hour;
                            PDBTimeStamp(Data)^.minute := Value.Minute;
                            PDBTimeStamp(Data)^.second := Value.Second;
                            PDBTimeStamp(Data)^.fraction := Value.Fractions;
                          end;
      DBTYPE_DBTIMESTAMPOFFSET: begin
                            PDBTIMESTAMPOFFSET(Data)^.year := Value.Year;
                            if Value.IsNegative then
                              PDBTIMESTAMPOFFSET(Data)^.year := -PDBTIMESTAMPOFFSET(Data)^.year;
                            PDBTIMESTAMPOFFSET(Data).month := Value.Month;
                            PDBTIMESTAMPOFFSET(Data).day := Value.Day;
                            PDBTIMESTAMPOFFSET(Data)^.hour := Value.Hour;
                            PDBTIMESTAMPOFFSET(Data)^.minute := Value.Minute;
                            PDBTIMESTAMPOFFSET(Data)^.second := Value.Second;
                            PDBTIMESTAMPOFFSET(Data)^.fraction := Value.Fractions;
                            PDBTIMESTAMPOFFSET(Data)^.timezone_hour := Value.TimeZoneHour;
                            PDBTIMESTAMPOFFSET(Data)^.timezone_minute := Value.TimeZoneMinute;
                          end;
      DBTYPE_WSTR:  if (Bind.cbMaxLen >= 48){0000-00-00T00.00.00.000#0}  or ((Bind.cbMaxLen-2) shr 1 = DBLENGTH(ConSettings.WriteFormatSettings.DateTimeFormatLen)) then
TSWConv:              PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ :=
                        DateTimeToUni(Value.Year, Value.Month, Value.Day,
                          Value.Hour, Value.Minute, Value.Second, Value.Fractions, PWideChar(Data),
                          ConSettings.WriteFormatSettings.DateTimeFormat, False, Value.IsNegative) shl 1
                    else RaiseExceeded(Index);
      (DBTYPE_WSTR or DBTYPE_BYREF): begin
                      PPointer(Data)^ := BindList.AquireCustomValue(Index, stUnicodeString, 24);
                      Data := PPointer(Data)^;
                      goto TSWConv;
                    end;
      else          if ZSysUtils.TryTimeStampToDateTime(Value, DT)
                    then InternalBindDbl(Index, stTimeStamp, DT)
                    else InternalBindSInt(Index, stTimeStamp, 1);
    end;
  end else begin//Late binding
    InitDateBind(Index, stTime);
    BindList.Put(Index, Value);
  end;
end;

{**
  Sets the designated parameter to a Java <code>usigned 32bit int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetUInt(Index: Integer; Value: Cardinal);
begin
  InternalBindUInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stLongWord, Value);
end;

{**
  Sets the designated parameter to a Java <code>unsigned long long</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
procedure TZOleDBPreparedStatement.SetULong(Index: Integer;
  const Value: UInt64);
{$IFDEF CPU64}
begin
  InternalBindUInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stULong, Value);
{$ELSE}
var Bind: PDBBINDING;
  Data: PAnsichar;
  L: Cardinal;
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    Bind := @FDBBindingArray[Index];
    PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_OK;
    Data := PAnsiChar(fDBParams.pData)+Bind.obValue;
    case Bind.wType of
      DBTYPE_NULL:      PDBSTATUS(PAnsiChar(FDBParams.pData)+Bind.obStatus)^ := DBSTATUS_S_ISNULL; //Shouldn't happen
      DBTYPE_I2:        PSmallInt(Data)^ := Value;
      DBTYPE_I4:        PInteger(Data)^ := Value;
      DBTYPE_R4:        PSingle(Data)^ := Value;
      DBTYPE_R8:        PDouble(Data)^ := Value;
      DBTYPE_CY:        PCurrency(Data)^ := Value;
      DBTYPE_BOOL:      PWordBool(Data)^ := Value <> 0;
      DBTYPE_VARIANT:   POleVariant(Data)^ := Value;
      DBTYPE_UI1:       PByte(Data)^ := Value;
      DBTYPE_I1:        PShortInt(Data)^ := Value;
      DBTYPE_UI2:       PWord(Data)^ := Value;
      DBTYPE_UI4:       PCardinal(Data)^ := Value;
      DBTYPE_I8:        PInt64(Data)^ := Value;
      DBTYPE_UI8:       PUInt64(Data)^ := Value;
      DBTYPE_WSTR, (DBTYPE_WSTR or DBTYPE_BYREF): begin
          L := GetOrdinalDigits(Value);
          if Bind.wType = (DBTYPE_WSTR or DBTYPE_BYREF) then begin
            PPointer(Data)^ := BindList.AquireCustomValue(Index, stString, 48); //8Byte align
            Data := PPointer(Data)^; //18.446.744.073.709.551.615
          end else if (Bind.cbMaxLen <= L shl 1) then
            RaiseExceeded(Index);
          IntToUnicode(Value, PWideChar(Data), L);
          PDBLENGTH(PAnsiChar(fDBParams.pData)+Bind.obLength)^ := L shl 1;
        end;
      DBTYPE_NUMERIC: begin
                        PDB_NUMERIC(Data)^.precision := GetOrdinalDigits(Value);
                        PDB_NUMERIC(Data)^.scale := 0;
                        PDB_NUMERIC(Data)^.sign := 1;
                        PUInt64(@PDB_NUMERIC(Data)^.val[0])^ := Value;
                        FillChar(PDB_NUMERIC(Data)^.val[SizeOf(UInt64)], SQL_MAX_NUMERIC_LEN-SizeOf(UInt64), #0);
                      end;
      //DBTYPE_VARNUMERIC:;
      else raise CreateOleDBConvertErrror(Index, Bind.wType, stULong);
    end;
  end else begin//Late binding
    InitFixedBind(Index, SizeOf(UInt64), DBTYPE_UI8);
    BindList.Put(Index, stULong, P8Bytes(@Value));
  end;
  {$ENDIF}
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

{**
  Sets the designated parameter to a Object Pascal <code>WideString</code>
  value. The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetUnicodeString(Index: Integer;
  const Value: ZWideString);
begin
  {$IFNDEF GENERIC_INDEX}
  Index := Index -1;
  {$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then
    if Value <> ''
    then SetPWideChar(Index, Pointer(Value), Length(Value))
    else SetPWideChar(Index, PEmptyUnicodeString, 0)
  else begin
    BindList.Put(Index, stUnicodeString, Value);
    InitVaryBind(Index, (Length(Value)+1) shl 1, DBTYPE_WSTR);
  end;
end;

{**
  Sets the designated parameter to a Java <code>UTF8String</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
{$IFNDEF NO_UTF8STRING}
procedure TZOleDBPreparedStatement.SetUTF8String(Index: Integer;
  const Value: UTF8String);
begin
  BindRaw(Index, Value, zCP_UTF8);
end;
{$ENDIF}

{**
  Sets the designated parameter to a Java <code>unsigned 16bit int</code> value.
  The driver converts this
  to an SQL <code>WORD</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZOleDBPreparedStatement.SetWord(Index: Integer; Value: Word);
begin
  InternalBindUInt(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stWord, Value);
end;

{**
  Removes eventual structures for binding input parameters.
}
procedure TZOleDBPreparedStatement.UnPrepareInParameters;
var FAccessorRefCount: DBREFCOUNT;
begin
  if Assigned(FParameterAccessor) then begin
    //don't forgett to release the Accessor else we're leaking mem on Server!
    FParameterAccessor.ReleaseAccessor(FDBParams.hAccessor, @FAccessorRefCount);
    FDBParams.hAccessor := 0;
    FParameterAccessor := nil;
  end;
  inherited UnPrepareInParameters;
end;

{ TZOleDBStatement }

constructor TZOleDBStatement.Create(const Connection: IZConnection;
  const Info: TStrings);
begin
  inherited Create(Connection, '', Info);
end;

{ TZOleDBCallableStatementMSSQL }

function TZOleDBCallableStatementMSSQL.CreateExecutionStatement(
  const StoredProcName: String): TZAbstractPreparedStatement;
var  I: Integer;
  SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND};
  SQLWriter: TZSQLStringWriter;
begin
  //https://docs.microsoft.com/en-us/sql/relational-databases/native-client-ole-db-how-to/results/execute-stored-procedure-with-rpc-and-process-output?view=sql-server-2017
  SQL := '{? = CALL ';
  SQLWriter := TZSQLStringWriter.Create(Length(StoredProcName)+BindList.Count shl 2);
  SQLWriter.AddText(StoredProcName, SQL);
  if BindList.Count > 1 then
    SQLWriter.AddChar(Char('('), SQL);
  for i := 1 to BindList.Count-1 do
    SQLWriter.AddText('?,', SQL);
  if BindList.Count > 1 then
    SQLWriter.ReplaceOrAddLastChar(',', ')', SQL);
  SQLWriter.AddChar('}', SQL);
  SQLWriter.Finalize(SQL);
  FreeAndNil(SQLWriter);
  Result := TZOleDBPreparedStatement.Create(Connection, SQL, Info);
  TZOleDBPreparedStatement(Result).Prepare;
end;

initialization

SetLength(DefaultPreparableTokens, 6);
DefaultPreparableTokens[0].MatchingGroup := 'DELETE';
DefaultPreparableTokens[1].MatchingGroup := 'INSERT';
DefaultPreparableTokens[2].MatchingGroup := 'UPDATE';
DefaultPreparableTokens[3].MatchingGroup := 'SELECT';
DefaultPreparableTokens[4].MatchingGroup := 'CALL';
DefaultPreparableTokens[5].MatchingGroup := 'SET';

{$ENDIF ZEOS_DISABLE_OLEDB} //if set we have an empty unit
end.
