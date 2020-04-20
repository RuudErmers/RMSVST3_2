unit UVST3Controller;

interface

uses Forms,UVST3Processor,Vst3Base,UVSTBase,UCDataLayer,Generics.Collections,ExtCtrls,Types,SysUtils;

const PROGRAMCOUNT = 16;

// I REFUSE to use the word Component, because
// 1. This is a 'reserved' word in many applications
// 2. On Page 1 of the VST3 docs there is a picture where the correct name is used: Processor
type  IProcessorHandler = IComponentHandler;

type TVST3Program = class
                    strict private
                      values:array of double;
                    public
                      // retrieves value from sl, using paramDEF.IDs as key
                      procedure SetState(const paramDEF:TVST3ParameterArray;numParams:integer;sl:TDataLayer);
                      // copies values to sl, using paramDEF.ID as key
                      procedure GetState(const paramDEF:TVST3ParameterArray;numParams:integer;sl:TDataLayer);
                      // copies paramFROM.Values to values, with a maximum of numParams values
                      procedure SaveParams(paramFROM:TVST3ParameterArray;numParams:integer);
                      // retrieves values[index]
                      function getParam (index:integer):double;
                    end;

 IVST3Controller = interface(IVSTBase)
        function CreateForm(parent:pointer):Tform;
        procedure EditOpen(form:TForm);
        procedure EditClose;
        procedure OnSize(newSize: TRect);
        function GetParameterCount:integer;
        function GetParameterInfo(paramIndex: integer;VAR info: TParameterInfo):boolean;
        function getParameterValue(id:integer):double;
        function GetParamStringByValue(id: integer; valueNormalized: double): string;
        function GetState:string;
        procedure SetState(state:string);
        procedure ControllerSetProcessorState(state:string);
        function NormalizedParamToPlain(id:integer;  valueNormalized: double): double;
        function PlainParamToNormalized(id:integer; plainValue: double): double;
        procedure ControllerTerminate;
        procedure SetProcessorHandler( handler: IProcessorHandler);
        procedure ParameterSetValue(id:integer;value:double);
        function GetMidiCCParamID(channel,midiControllerNumber:integer):integer;
        function GetNumPrograms:integer;
        function GetProgramName(index:integer):string;
     end;
   TVST3ControllerBase = class(TVSTBase,IVST3Controller)
   private
        FCurProgram:integer;
        FPrograms: TList<TVST3Program>;
        Fparameters:TVST3ParameterArray;
        FeditorForm:TForm;
        FnumUserParameters:integer;
        FInitialized,fFinalized:boolean;
        FProcessorHandler:IProcessorHandler;
        FIdleTimer:TTimer;
        FSomethingDirty:boolean;
        FMidiEventQueue:TArray<integer>;
        procedure saveCurrentToProgram(prgm:integer);
        procedure SetProgram(prgm:integer;saveCurrent:boolean);
        function ParmLookup(id: integer): integer;
        function CreateForm(parent:pointer):Tform;
        procedure EditOpen(form:TForm);
        procedure EditClose;
        function GetParameterCount:integer;
        function GetParameterInfo(paramIndex: integer;VAR info: TParameterInfo):boolean;
        function GetParamStringByValue(id: integer; valueNormalized: double): string;

        function GetState:string;
        procedure SetState(state:string);
        procedure ControllerSetProcessorState(state:string);
        procedure Initialize;override;
        procedure Terminate;
        procedure ControllerTerminate;
        function NormalizedParamToPlain(id:integer;  valueNormalized: double): double;
        function PlainParamToNormalized(id:integer; plainValue: double): double;
        procedure SetProcessorHandler( handler: IProcessorHandler);
        procedure ParameterSetValue(id:integer;value:double);
        procedure UpdateCurrentFromProgram(prgm: integer);
        function GetMidiCCParamID(channel,midiControllerNumber:integer):integer;
        function GetNumPrograms:integer;
        function GetProgramName(index:integer):string;
        function  getParameterValue(id:integer):double;
        procedure SetIdleTimer(enabled: boolean);
        procedure TimerOnIdle(Sender: TObject);
        procedure InternalSetParameter(const Index: Integer;  const Value: Single);
        procedure ReceiveMessage(msg:TBytes);override;
   protected
        procedure GetParametersDescription(params:TVST3ParameterArray);virtual;
        procedure ResendParameters;
        procedure UpdateHostParameter(id:integer;value:double);
        property  EditorForm: TForm read FEditorForm;
        function getParameterAsString(id: integer; value: double): string; virtual;
        procedure OnProgramChange(prgm:integer);virtual;
        function  GetEditorClass: TFormClass;virtual;
        procedure OnEditOpen;virtual;
        procedure OnEditClose;virtual;
        procedure OnEditIdle;virtual;
        procedure UpdateParameter(id:integer;value:double);virtual;
        procedure OnInitialize;virtual;
        procedure OnFinalize;virtual;
        procedure MidiOut(byte0, byte1, byte2: integer);
        procedure MidiEventToProcessor(byte0, byte1, byte2: integer);
        procedure OnMidiEvent(byte0, byte1, byte2: integer);virtual;

        procedure doProgramChange(prgm:integer);
        procedure OnSize(newSize:TRect);virtual;
        procedure SendMessageToProcessor(msg:TBytes);
   public
        constructor Create; override;
   end;

   TVST3Controller = class(TVST3ControllerBase,IEditController,IMidiMapping,IUnitInfo,IConnectionPoint,IPluginBase)
protected
   FEditController:IEditController;
   FMidiMapping:IMidiMapping;
   FUnitInfo: IUnitInfo;
   FConnectionPoint: IConnectionPoint;
   property EditController: IEditController read FEditController implements IEditController,IPluginBase;
   property MidiMapping:IMidiMapping read FMidiMapping implements IMidiMapping;
   property UnitInfo:IUnitInfo read FUnitInfo implements IUnitInfo;
   property ConnectionPoint: IConnectionPoint read FConnectionPoint implements IConnectionPoint;
public
   constructor Create; override;
end;


implementation

uses UCodeSiteLogger,Windows,Math, UVst3Utils,UCEditController,UCMIdiMapping,UCUnitInfo,UCConnectionPoint;

constructor TVST3ControllerBase.Create;
begin
  WriteLog('TVST3ControllerBase.Create');
  inherited;
  FPrograms:=TList<TVST3Program>.Create;
end;

function TVST3ControllerBase.GetProgramName(index: integer): string;
begin
  result:='Program '+format('%.2d',[index+1]);
end;

function TVST3ControllerBase.GetState:string;
VAR i,n:integer;
    sl,ssl:TDataLayer;
begin
  saveCurrentToProgram(FCurProgram);
  WriteLog('Get State Called with Program='+ FCurProgram.ToString);
  sl:=TDataLayer.Create;

  sl.setAttributeI('CurProgram',FCurProgram);
  ssl:=TDataLayer.Create;
  for i:=0 to PROGRAMCOUNT-1 do
  begin
    ssl.Clear;
    FPrograms[i].GetState(FParameters,FnumUserParameters,ssl);
    sl.SaveSection('Program'+i.ToString,ssl);
  end;
  ssl.Free;
  result:=sl.Text;
  sl.Free;
end;

procedure TVST3ControllerBase.MidiEventToProcessor(byte0, byte1, byte2: integer);
VAR buf:TBytes;
begin
  SetLength(buf,4);
  buf[0]:=MSG_MIDIINT;
  buf[1]:=byte0;
  buf[2]:=byte1;
  buf[3]:=byte2;
  SendMessageToProcessor(buf);
end;

procedure TVST3ControllerBase.MidiOut(byte0, byte1, byte2: integer);
VAR buf:TBytes;
begin
  SetLength(buf,4);
  buf[0]:=MSG_MIDIOUT;
  buf[1]:=byte0;
  buf[2]:=byte1;
  buf[3]:=byte2;
  SendMessageToProcessor(buf);
end;

procedure TVST3ControllerBase.doProgramChange(prgm: integer);
begin
  SetProgram(prgm,true);
end;

procedure TVST3ControllerBase.SetState(state:string);
VAR i,TempProgram:integer;
    sl,ssl:TDataLayer;
begin
  WriteLog('Set State: LOADING...');
  sl:=TDataLayer.Create;
  sl.Text:=state;
  TempProgram:=sl.getAttributeI('CurProgram',-1);
  ssl:=TDataLayer.Create;
  for i:=0 to PROGRAMCOUNT-1 do
  begin
    sl.LoadSection('Program'+i.ToString,ssl);
    FPrograms[i].SetState(FParameters,FnumUserParameters,ssl);
  end;
  ssl.free;
  sl.free;
  if TempProgram<>-1 then
    SetProgram(TempProgram,false);
end;

procedure TVST3ControllerBase.saveCurrentToProgram(prgm:integer);
begin
  FPrograms[prgm].saveParams(FParameters,FnumUserParameters);
end;

procedure TVST3ControllerBase.UpdateCurrentFromProgram(prgm:integer);
VAR i:integer;
    value:double;
begin
  for i:=0 to FnumUserParameters-1 do
  begin
    value:=FPrograms[prgm].getParam(i);
      InternalSetParameter(i,value);
  end;
end;

procedure TVST3ControllerBase.SetProcessorHandler(handler: IProcessorHandler);
begin
  FProcessorHandler:=handler;
end;

procedure TVST3ControllerBase.ControllerSetProcessorState(state:string);
VAR sl:TDataLayer;
begin
  sl:=TDataLayer.Create;
  sl.Text:=state;
  FParameters.SetState(sl);
  sl.free;
end;

procedure TVST3ControllerBase.Terminate;
begin
  if fFinalized then exit;
  fFinalized:=true;
  OnFinalize;
end;

procedure TVST3ControllerBase.Initialize;
VAR title:string;
    i:integer;
begin
  if fInitialized then exit;
  fInitialized:=true;
  for i:=0 to PROGRAMCOUNT-1 do
    FPrograms.Add(TVST3Program.Create);
  FParameters:=TVST3ParameterArray.Create;
  GetParametersDescription(FParameters);
  OnInitialize;
  FnumUserParameters:=length(FParameters.params);
  // Copy initial Parameters to ALL Programs
  for i:=0 to PROGRAMCOUNT-1 do
    saveCurrentToProgram(i);
  //////////////////////////////////////////
  WriteLog('INIT: NumParams = '+FnumUserParameters.ToString);
  FParameters.AddParameter(IDPARMProgram, 'Program','Program','',0,PROGRAMCOUNT-1,0,-1,false,PROGRAMCOUNT-1,true);
  for i:=0 to 127 do
  begin
    title:='CCSIM_'+i.ToString;
    FParameters.AddParameter(MIDICC_SIMULATION_START+i,title,title,'CC',0,127,0.3,-1,false);
  end;
  SetProgram(0,false);
end;

function TVST3ControllerBase.GetMidiCCParamID(channel,midiControllerNumber: integer): integer;
VAR i:integer;
begin
  if (channel=0) and (midiControllerNumber<128) then
  begin
    result:=MIDICC_SIMULATION_START+midiControllerNumber+channel*128;
    for i:=0 to length(FParameters.params)-1 do with FParameters.params[i] do
     if cc=midiControllerNumber then
        result:=id;
  end
  else
    result:=-1;
end;

function TVST3ControllerBase.GetNumPrograms: integer;
begin
  result:=PROGRAMCOUNT;
end;

function TVST3ControllerBase.getParameterAsString(id: integer;  value: double): string;
begin
  result:='';
end;

procedure TVST3ControllerBase.ControllerTerminate;
begin
  Terminate;
end;

procedure TVST3ControllerBase.SetProgram(prgm:integer;saveCurrent:boolean);
begin
  if saveCurrent then
   saveCurrentToProgram(FCurProgram);
  FCurProgram:=prgm;
  UpdateCurrentFromProgram(prgm);
  OnProgramChange(prgm);
end;

function TVST3ControllerBase.GetParameterCount: integer;
begin
  result:=length(Fparameters.params);
end;

function TVST3ControllerBase.GetEditorClass:TFormClass;
begin
  result:=NIL;
end;

function TVST3ControllerBase.CreateForm(parent:pointer):TForm;
VAR FeditorFormClass:TFormClass;
begin
  FeditorFormClass:=GetEditorClass;
  if FeditorFormClass = NIL then FeditorFormClass:=GetPluginInfo.PluginDef.vst3editorclass;
  if FeditorFormClass = NIL then result:=NIL
  else result:=FeditorFormClass.CreateParented(HWND(parent));
end;

function TVST3ControllerBase.GetParameterInfo(paramIndex: integer; var info: TParameterInfo): boolean;
begin
  if paramIndex>=GetParameterCount then
  begin
    result:=false;
    exit;
  end;
  with Fparameters.params[paramIndex] do
  begin
    info.id:=id;
    AssignString(info.Title,Title);
    AssignString(info.shortTitle,shortTitle);
    AssignString(info.units,units);
    info.stepCount:=steps;
    info.defaultNormalizedValue:=defVal;
    info.unitId:= kRootUnitId;
    info.flags:= ifthen(automate,kCanAutomate,0)
                  + ifthen(isProgram,kIsProgramChange,0);
  end;
  result:=true;
end;

procedure TVST3ControllerBase.GetParametersDescription(params:TVST3ParameterArray);
begin
end;

function TVST3ControllerBase.getParameterValue(id: integer): double;
VAR index:integer;
begin
  result:=0;
  index:=ParmLookup(id);
  if index < 0 then exit;
  result:=Fparameters.params[index].value;
end;


function TVST3ControllerBase.GetParamStringByValue(id: integer;valueNormalized: double): string;
VAR v:double;
    index:integer;
begin
  result:='';
  index:=ParmLookup(id);
  if (index >= 0) and (index<FnumUserParameters) then
    result:=getParameterAsString(id,valueNormalized);
  if result='' then
  begin
    v:=NormalizedParamToPlain(id,valueNormalized);
    if abs(v-round(v))<0.001 then
       result:=round(v).ToString
    else
       result:=Copy(FloatToStr(v),1,6);
     end;
end;

function TVST3ControllerBase.NormalizedParamToPlain(id: integer;valueNormalized: double): double;
VAR index:integer;
begin
  result:=0;
  index:=ParmLookup(id);
  if index < 0 then exit;
  with Fparameters.params[index] do
    result:=min+(max-min)*valueNormalized;
end;

function TVST3ControllerBase.PlainParamToNormalized(id: integer;plainValue: double): double;
VAR index:integer;
begin
  result:=0;
  index:=ParmLookup(id);
  if index < 0 then exit;
  with Fparameters.params[index] do
    result:=(plainValue-min)/(max-min);
end;

procedure TVST3ControllerBase.EditClose;
begin
  SetIdleTimer(false);
  OnEditClose;
  FeditorForm:=NIL;
end;

procedure TVST3ControllerBase.EditOpen(form: TForm);
begin
  FeditorForm:=form;
  OnEditOpen;
  SetIdleTimer(true);
  ResendParameters;
end;

procedure TVST3ControllerBase.ReceiveMessage(msg: TBytes);
begin
  case msg[0] of
    MSG_MIDIINT: OnMidiEvent(msg[1],msg[2],msg[3]);
  end;

end;

procedure TVST3ControllerBase.ResendParameters;
VAR i,id,count:integer;
begin
  if FeditorForm=NIL then exit;
  count:=FnumUserParameters;
  for i:=0 to count-1 do
  begin
    id:=Fparameters.params[i].id;
    if isMidiCCId(id) then continue;  // better safe than sorry
    if id = IDPARMProgram then continue;  // better safe than sorry
    UpdateParameter(id,Fparameters.params[i].value);
    Fparameters.params[i].dirty:=false
  end;
end;

procedure TVST3ControllerBase.TimerOnIdle(Sender:TObject);
VAR i,count:integer;
begin
  OnEditIdle;
  if not FSomethingDirty then exit;
  count:=FnumUserParameters;
  for i:=0 to count-1 do with Fparameters.params[i] do
    if dirty then
    begin
      UpdateParameter(id,value);
      dirty:=false
    end;
  FSomethingDirty:=false;
end;

procedure TVST3ControllerBase.InternalSetParameter(const Index: Integer;  const Value: Single);
begin
  FParameters.params[index].value:=value;
  FParameters.params[index].dirty:=true;
  FSomethingDirty:=true;
end;

procedure TVST3ControllerBase.SendMessageToProcessor(msg:TBytes);
begin
  SendMessage(msg);
end;

procedure TVST3ControllerBase.SetIdleTimer(enabled:boolean);
begin
  if enabled then
  begin
    if FIdleTimer=NIL then
      FIdleTimer:=TTimer.Create(NIL);
    FIdleTimer.Interval:=100;
    FIdleTimer.OnTimer:=TimerOnIdle;
    FIdleTimer.Enabled:=true;
  end
  else
    if FIdleTimer<>NIL then
      FreeAndNIL(FidlEtimer);
end;

procedure TVST3ControllerBase.UpdateParameter(id: integer;  value: double);
begin
// virtual;
end;

function TVST3ControllerBase.ParmLookup(id:integer):integer;
VAR i:integer;
begin
  for i:=0 to length(Fparameters.params)-1 do
    if FParameters.params[i].id = id then begin result:=i; exit; end;
  result:=-1;
end;

procedure TVST3ControllerBase.UpdateHostParameter(id: integer; value: double);
VAR index:integer;
begin
  index:=ParmLookup(id);
  if index<>-1 then
  begin
    if FProcessorHandler<>NIL then
      FProcessorHandler.PerformEdit(id,value);
    InternalSetParameter(index,value);
  end;
end;

procedure TVST3ControllerBase.OnEditClose;
begin

end;

procedure TVST3ControllerBase.OnEditIdle;
begin
// virtual
end;

procedure TVST3ControllerBase.OnEditOpen;
begin
//
end;

procedure TVST3ControllerBase.OnFinalize;
begin

end;

procedure TVST3ControllerBase.OnInitialize;
begin
end;

procedure TVST3ControllerBase.OnMidiEvent(byte0, byte1, byte2: integer);
begin
// virtual
end;

procedure TVST3ControllerBase.OnProgramChange(prgm: integer);
begin
// virtual
end;

procedure TVST3ControllerBase.OnSize(newSize: TRect);
begin
  if FeditorForm<>NIL then with newSize do
    FeditorForm.SetBounds(left,top,width,height);
end;

procedure TVST3ControllerBase.ParameterSetValue(id: integer; value: double);
{ this is called: From Host: ParameterSetValue}
// All CC's for MIdi are called
VAR index:integer;
const   MIDI_CC = $B0;
begin
  WriteLog('ParameterSetValue:'+id.ToString+' '+value.ToString);
  if isMidiCCId(id) then
    exit;
  index:=ParmLookup(id);
  if index=-1 then exit;
  if (value<0) or (value>1) then exit;
  if id = IDPARMProgram then
  begin
    WriteLog('Program Change');
    SetProgram(round(value*(PROGRAMCOUNT-1)),true);
  end
  else
    InternalSetParameter(index,value);
end;

{ TVST3Program }

// copies values to sl, using paramDEF.ID as key
procedure TVST3Program.GetState(const paramDEF:TVST3ParameterArray;numParams:integer;sl:TDataLayer);
VAR i,len:integer;
begin
  sl.setAttributeI('MAGIC',2136);
  len:=min(numParams,length(values));
  for i:=0 to len-1 do
    sl.SetAttributeI('PARAM'+paramdef.params[i].id.ToString,round(values[i]*16384));
end;

// retrieves value from sl, using paramDEF.IDs as key
// adjusts length(values) if needed
procedure TVST3Program.SetState(const paramDEF:TVST3ParameterArray;numParams:integer;sl:TDataLayer);
VAR i:integer;
begin
  // Copy To self
  if sl.getAttributeI('MAGIC')<>2136 then
  begin
    WriteLog('SetState; Invalid magic UNEXPECTED');
    exit;
  end;
  setLength(values,numParams);
  for i:=0 to numParams-1 do
    values[i]:=sl.GetAttributeI('PARAM'+paramdef.params[i].id.ToString)/16384;
end;

// copies paramFROM.Values to values, with a maximum of numParams values
procedure TVST3Program.SaveParams(paramFROM:TVST3ParameterArray;numParams:integer);
VAR i:integer;
begin
  SetLength(values,numParams);
  for i:=0 to numParams-1 do
    values[i]:=paramFROM.params[i].value;
end;

// retrieves values[index]
function TVST3Program.getParam (index:integer):double;
begin
  result:=0;
  if index<length(values) then
    result:=values[index];
end;


{ TVST3Controller }

constructor TVST3Controller.Create;
begin
  WriteLog('TVST3Controller.Create');

  inherited;
  FEditController:=CEditController.Create(self);
  FMidiMapping:=CMidiMapping.Create(self);
  FUnitInfo:=CUnitInfo.Create(self);
  FConnectionPoint:=CConnectionPoint.Create(self);
//  Initialize;
end;

end.

