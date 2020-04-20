unit UVSTBase;

interface

uses Forms,  Generics.Collections,UCDataLayer,Vst3Base,SysUtils;

type PSingle           = ^single;
     PPSingle          = ^PSingle;
     PDouble           = ^double;
     PPDouble          = ^PDouble;
const MIDICC_SIMULATION_START = 1024;
const MIDICC_SIMULATION_LAST  = 1024+128*16-1;  // = 3071
const IDPARMProgram = 4788;


function isMidiCCId(id:integer):boolean;

type
     TVSTBase = class;
     TVST3Parameter  = record
                        id,steps,cc:integer;
                        title,shorttitle,units:string;
                        min,max,defVal,value:double;
                        automate,isProgram,dirty:boolean;
                      end;
     TVST3ParameterArray = class
                             params:TArray<TVST3Parameter>;
                             procedure AddParameter(id:integer;title,shorttitle,units:string;min,max,val:double;cc:integer=-1;automate:boolean=true;steps:integer=0;ProgramChange:boolean=false);
                             procedure GetState(sl:TDataLayer);
                             procedure SetState(sl:TDataLayer);
                             procedure UpdateParameter(id:integer;value:double);
                           end;
     TVSTProcessorClass = class of TVSTBase;
     TVSTControllerClass = class of TVSTBase;
     TVSTPluginDef =  record
                              vst3processorid:TGUID;
                              vst3controllerid:TGUID;
                              vst3processorclass : TVSTProcessorClass;
                              vst3controllerclass : TVSTControllerClass;
                              vst3editorclass :  TFormClass;
                              name:string;
                              isSynth,softMidiThru:boolean;
                            end;
     TVSTFactoryDef =     record
                             vendor,url,email:string;
                           end;
     TVSTInstrumentInfo = record
                        PluginDef:TVSTPluginDef;
                        factoryDef:TVSTFactoryDef;
                      end;
     TSendMessageHandler = procedure (msg:TBytes) of object;
    IVSTBase = interface
        function GetPluginInfo:TVSTInstrumentInfo;
        procedure OnCreate(pluginInfo:TVSTInstrumentInfo);
        procedure Initialize2(context: FUnknown);
        procedure SetMessageSendHandler(handler:TSendMessageHandler);
        procedure ReceiveMessage(msg:TBytes);
        function Host: IHostApplication;
     end;
     TVSTBase = class(TInterfacedObject,IVSTBase)
     private
        FPluginInfo:TVSTInstrumentInfo;
        FHost:IHostApplication;
        FMessageSendHandler:TSendMessageHandler;
        procedure Initialize2(context: FUnknown);
        procedure SetMessageSendHandler(handler:TSendMessageHandler);
     protected
        procedure Initialize;overload;virtual;
        procedure ReceiveMessage(msg:TBytes);virtual;
     public
        function Host: IHostApplication;
        procedure SendMessage(msg:TBytes);
        function GetPluginInfo:TVSTInstrumentInfo;
        procedure OnCreate(pluginInfo:TVSTInstrumentInfo); virtual;
        constructor Create; virtual;
     end;

const MSG_MIDIOUT = 0;
const MSG_MIDIINT = 1;

implementation

uses UCodeSiteLogger;

function isMidiCCId(id:integer):boolean;
begin
  result:=(id>=MIDICC_SIMULATION_START) and (id<=MIDICC_SIMULATION_LAST);
end;

constructor TVSTBase.Create;
begin
//
end;

function TVSTBase.GetPluginInfo: TVSTInstrumentInfo;
begin
  result:=FPluginInfo;
end;

function TVSTBase.Host: IHostApplication;
begin
  result:=FHost;
end;

procedure TVSTBase.Initialize;
begin
// virtual
end;

procedure TVSTBase.Initialize2(context: FUnknown);
begin
  WriteLog('>>>>>>>>>>>>>> TVSTBase.Initialize <<<<<<<<<<<<<<<<<<<<<<<<<<');
  context.QueryInterface(UID_IHostApplication,FHost);
  Initialize;
end;

procedure TVSTBase.OnCreate(pluginInfo: TVSTInstrumentInfo);
begin
  FPluginInfo:=pluginInfo;
end;

procedure TVSTBase.ReceiveMessage(msg:TBytes);
begin
end;

procedure TVSTBase.SendMessage(msg:TBytes);
begin
  if assigned(FMessageSendHandler) then FMessageSendHandler(msg);
end;

procedure TVSTBase.SetMessageSendHandler(handler: TSendMessageHandler);
begin
  FMessageSendHandler:=handler;
end;

{ TVST3ParameterArray }

procedure TVST3ParameterArray.AddParameter(id: integer; title, shorttitle,
  units: string; min, max, val: double; cc:integer;automate: boolean; steps: integer;
  ProgramChange: boolean);
VAR n:integer;
    param:TVST3Parameter;
begin
  param.id:=id;
  param.title:=title;
  param.shorttitle:=shorttitle;
  param.units:=units;
  param.min:=min;
  param.max:=max;
  param.cc:=cc;
  if (max<=min) then param.max:=param.min+1;
  if (val<param.min) then val:=param.min;
  if (val>param.max) then val:=param.max;
  val:=(val-min)/(max-min);
  param.defval:=val;
  param.value:=val;
  param.automate:=automate;
  param.steps:=steps;
  param.isProgram:=ProgramChange;
  n:=Length(params);
  SetLength(params,n+1);
  params[n]:=param;
end;

procedure TVST3ParameterArray.GetState(sl: TDataLayer);
VAR i,len:integer;
begin
  sl.setAttributeI('MAGIC',2136);
  for i:=0 to length(params)-1 do with params[i] do
    sl.SetAttributeI('PARAM'+id.ToString,round(value*16384));
end;

procedure TVST3ParameterArray.SetState(sl: TDataLayer);
VAR i:integer;
begin
  if sl.getAttributeI('MAGIC')<>2136 then
  begin
    WriteLog('SetState; Invalid magic UNEXPECTED');
    exit;
  end;
  for i:=0 to length(params)-1 do with params[i] do
    value:=sl.GetAttributeI('PARAM'+id.ToString)/16384;
end;

procedure TVST3ParameterArray.UpdateParameter(id: integer; value: double);
VAR i:integer;
begin
  for i:=0 to length(params)-1 do
    if params[i].id=id then begin params[i].value:=value;exit; end;
end;

end.
