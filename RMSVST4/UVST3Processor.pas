unit UVST3Processor;

interface

uses UVSTBase, Vst3Base, UVst3Utils,Generics.Collections,SysUtils;

type
     IVST3Processor = interface(IVSTBase)
        procedure OnSysexEvent(s:string);
        procedure OnMidiEvent(fromQueue:boolean;byte0,byte1,byte2:integer);
        procedure ProcessorParameterSetValue(id:integer;value:double);
        procedure Process32(samples,channels:integer;inputp, outputp: PPSingle);
        procedure SamplerateChanged(samplerate:single);
        procedure TempoChanged(tempo:single);
        procedure PlayStateChanged(playing:boolean;ppq:integer);
        function GetMidiOutputEvents:TArray<integer>;
        function GetState:string;
        procedure SetState(state:string);
        procedure SetActive(active:boolean);
//        procedure Initialize;
        procedure ProcessorTerminate;
     end;
     TVST3ProcessorBase = class(TVSTBase,IVST3Processor)
      private
        Factive:boolean;
        Fparameters:TVST3ParameterArray;
        FMidiOutQueue:TArray<integer>;
        function GetState:string;
        procedure SetState(state:string);
        procedure SetActive(active:boolean);
        procedure OnMidiEvent(fromQueue:boolean;byte0,byte1,byte2:integer);overload;
        procedure MidiEventToController(byte0, byte1, byte2: integer);
        procedure SendMessageToController(msg:TBytes);
      protected
        procedure Initialize;override;
        procedure ReceiveMessage(msg:TBytes);override;
        procedure MidiOut(byte0, byte1, byte2: integer);
        procedure OnInitialize;virtual;
        procedure GetParametersDescription(params:TVST3ParameterArray);virtual;
        procedure ProcessorTerminate;virtual;
        procedure ProcessorParameterSetValue(id:integer;value:double);virtual;
        procedure OnSysexEvent(s:string);virtual;
        procedure OnMidiEvent(byte0, byte1, byte2: integer);overload;virtual;
        function GetMidiOutputEvents:TArray<integer>;virtual;
        procedure Process32(samples,channels:integer;inputp, outputp: PPSingle);virtual;
        procedure SamplerateChanged(samplerate:single);virtual;
        procedure PlayStateChanged(playing:boolean;ppq:integer);virtual;
        procedure TempoChanged(tempo:single);virtual;
        procedure UpdateParameter(id:integer;value:double);virtual;
        procedure InternalUpdateParameter(id:integer;value:double);

      public
   end;

     TVST3Processor = class(TVST3ProcessorBase,IComponent,IAudioProcessor,IConnectionPoint,IPluginBase)
protected
  FAudioProcessor:IAudioProcessor;
  FComponent:IComponent;
  FConnectionPoint: IConnectionPoint;
  property AudioProcessor: IAudioProcessor read FAudioProcessor implements IAudioProcessor;
  property Component: IComponent read FComponent implements IComponent,IPluginBase;
  property ConnectionPoint: IConnectionPoint read FConnectionPoint implements IConnectionPoint;
public
  constructor Create; override;
end;



implementation

uses UCodeSiteLogger,UCAudioProcessor,UCComponent,UCDataLayer,UCConnectionPoint;

procedure TVST3ProcessorBase.TempoChanged(tempo: single);
begin
// virtual
end;

procedure TVST3ProcessorBase.UpdateParameter(id: integer; value: double);
begin
// virtual
end;

procedure TVST3ProcessorBase.SendMessageToController(msg:TBytes);
begin
  SendMessage(msg);
end;

procedure TVST3ProcessorBase.SetActive(active: boolean);
begin
  Factive:=active;
end;

procedure TVST3ProcessorBase.ProcessorParameterSetValue(id:integer;value:double);
VAR index:integer;
const   MIDI_CC = $B0;
begin
//  WriteLog('ProcessorOnUpdateParameter: '+id.ToString+' '+value.ToString);
  if isMidiCCId(id) then
  begin
    index:=id-MIDICC_SIMULATION_START;
    OnMidiEvent(true,index DIV 128 + MIDI_CC,index MOD 128,round(127*value))
  end
  else
  begin // do some validation on the input..
  //  index:=ParmLookup(id);
  //  if index=-1 then exit;
    if id<> IDPARMProgram then
      InternalUpdateParameter(id,value);
  end;
end;

procedure TVST3ProcessorBase.Process32(samples, channels: integer; inputp,  outputp: PPSingle);
begin
// virtual;
end;

procedure TVST3ProcessorBase.Initialize;
begin
  FParameters:=TVST3ParameterArray.Create;
  GetParametersDescription(FParameters);
  OnInitialize;
end;

procedure TVST3ProcessorBase.InternalUpdateParameter(id: integer;  value: double);
begin
  FParameters.UpdateParameter(id,value);
  UpdateParameter(id,value);
end;

procedure TVST3ProcessorBase.ProcessorTerminate;
begin
// virtual
end;

procedure TVST3ProcessorBase.ReceiveMessage(msg: TBytes);
begin
  case msg[0] of
    MSG_MIDIOUT: MidiOut(msg[1],msg[2],msg[3]);
    MSG_MIDIINT: OnMidiEvent(false,msg[1],msg[2],msg[3]);
  end;
end;

procedure TVST3ProcessorBase.SamplerateChanged(samplerate: single);
begin
// virtual;
end;

procedure TVST3ProcessorBase.OnInitialize;
begin
// virtual
end;

procedure TVST3ProcessorBase.OnMidiEvent(byte0, byte1, byte2: integer);
begin
// virtual
end;

procedure TVST3ProcessorBase.MidiEventToController(byte0, byte1, byte2: integer);
VAR buf:TBytes;
begin
  SetLength(buf,4);
  buf[0]:=MSG_MIDIINT;
  buf[1]:=byte0;
  buf[2]:=byte1;
  buf[3]:=byte2;
  SendMessageToController(buf);
end;

procedure TVST3ProcessorBase.OnMidiEvent(fromQueue:boolean;byte0, byte1, byte2: integer);
begin
  OnMidiEvent(byte0, byte1, byte2);
  if fromQueue then
    MidiEventToController(byte0,byte1,byte2);
end;

function TVST3ProcessorBase.GetMidiOutputEvents: TArray<integer>;
begin
  result:=FMidiOutQueue; // should be a ringbuffer...
  SetLength(FMidiOutQueue,0);
end;

procedure TVST3ProcessorBase.GetParametersDescription(params: TVST3ParameterArray);
begin
// virtual, default is no parameters
end;

procedure TVST3ProcessorBase.MidiOut(byte0, byte1, byte2: integer);
VAR l:integer;
begin
  l:=length(FMidiOutQueue);
  SetLength(FMidiOutQueue,l+1);
  FMidiOutQueue[l]:=byte0+byte1 SHL 8 + byte2 SHL 16;
end;

function TVST3ProcessorBase.GetState:string;
VAR i,n:integer;
    sl:TDataLayer;
begin
  sl:=TDataLayer.Create;
  FParameters.GetState(sl);
  result:=sl.Text;
  sl.Free;
end;

procedure TVST3ProcessorBase.SetState(state:string);
VAR i:integer;
    sl:TDataLayer;
    value:single;
begin
  sl:=TDataLayer.Create;
  sl.Text:=state;
  FParameters.SetState(sl);
  sl.free;
  for i:=0 to length(FParameters.params)-1 do
  begin
    value:=FParameters.params[i].value;
    UpdateParameter(FParameters.params[i].id,value);
  end;

end;

procedure TVST3ProcessorBase.OnSysexEvent(s: string);
begin
// virtual;
end;

procedure TVST3ProcessorBase.PlayStateChanged(playing: boolean; ppq: integer);
begin
// virtual
end;

//=========================================================

constructor TVST3Processor.Create;
VAR obj: pointer;
begin
  WriteLog('TVST3Processor.Create');
  inherited;
  FConnectionPoint:=CConnectionPoint.Create(self);
  FAudioProcessor:=CAudioProcessor.Create(self);
  FComponent:=CComponent.Create(self);

// I am moving away this again, lets see how Cubase reacts...  Crash , does not call ProcessorInitialize
//  Initialize;
end;

end.
