unit UMyVst;

interface

uses UVSTInstrument,Forms, Classes,UVSTBase,UMyVSTDSP,UVST3Processor,UVST3Controller;

const ID_CUTOFF = 17;
const ID_RESONANCE = 18;
const ID_PULSEWIDTH = 19;

type TMyVSTPluginProcessor = class (TVST3Processor)
private
  FSimpleSynth:TSimpleSynth;
protected
  procedure Process32(samples,channels:integer;inputp, outputp: PPSingle);override;
  procedure UpdateParameter(id:integer;value:double);override;
  procedure OnInitialize;override;
  procedure OnMidiEvent(byte0, byte1, byte2: integer);override;
  procedure GetParametersDescription(params:TVST3ParameterArray);override;
public
end;

type TMyVSTPluginController = class (TVST3Controller)
private
  procedure DoUpdateHostParameter(id: integer; value: double);   // called from UI
  procedure doKeyEvent(key: integer; _on: boolean);              // called from UI
protected
  procedure OnInitialize;override;
  procedure UpdateParameter(id:integer;value:double);override;
  procedure OnEditOpen;override;
  procedure OnProgramChange(prgm:integer);override;
  procedure OnMidiEvent(byte0, byte1, byte2: integer);override;
  procedure GetParametersDescription(params:TVST3ParameterArray);override;
public
end;

function GetVSTInstrumentInfo:TVSTInstrumentInfo;
implementation

{ TmyVST }

uses UMyVSTForm,SysUtils,Windows,UCodeSiteLogger;

const MIDI_NOTE_ON = $90;
      MIDI_NOTE_OFF = $80;
      MIDI_CC = $B0;

{$POINTERMATH ON}
{$define DebugLog}

procedure AddParameters(params:TVST3ParameterArray);
begin
  params.AddParameter(ID_CUTOFF,'Cutoff','Cutoff','Hz',20,20000,10000,74);
  params.AddParameter(ID_RESONANCE,'Resonance','Resonance','',0,1,0);
  params.AddParameter(ID_PULSEWIDTH,'Pulse Width','PWM','%',0,100,50);
end;

procedure TMyVSTPluginProcessor.UpdateParameter(id:integer;value:double);
begin
  FSimpleSynth.UpdateParameter(id,value);
end;

procedure TMyVSTPluginProcessor.Process32(samples, channels: integer; inputp, outputp: PPSingle);
VAR i,channel:integer;
    sample:single;
begin
  for i:=0 to samples-1 do
  begin
    sample:=FSimpleSynth.process;
    for channel:=0 to 1 do
      outputp[channel][i]:=sample;
  end;
end;

procedure TMyVSTPluginProcessor.GetParametersDescription(params: TVST3ParameterArray);
begin
  AddParameters(params);
end;

procedure TMyVSTPluginProcessor.OnInitialize;
begin
  FSimpleSynth:=TSimpleSynth.Create(44100);
end;

procedure TMyVSTPluginProcessor.OnMidiEvent(byte0, byte1, byte2: integer);
VAR status:integer;
begin
  WriteLog('TMyVSTPlugin.OnMidiEvent:'+byte0.ToString+' '+byte1.ToString+' '+byte2.ToString);
  status:=byte0 and $F0;
  if status=MIDI_NOTE_ON then FSimpleSynth.OnKeyEvent(byte1,byte2>0)
  else if status=MIDI_NOTE_OFF then FSimpleSynth.OnKeyEvent(byte1,false)
end;

//////////////////////////////////////////////////////////////////////////////////////

procedure TMyVSTPluginController.OnInitialize;
begin
//  AddProgram('Program 1');
//  AddProgram('Program 2');
//  AddProgram('Program 3');
end;

procedure TMyVSTPluginController.OnMidiEvent(byte0, byte1, byte2: integer);
VAR status:integer;
begin
  status:=byte0 and $F0;
  if status=MIDI_NOTE_ON then TFormMyVST(EditorForm).SetKey(byte1,byte2>0)
  else if status=MIDI_NOTE_OFF then TFormMyVST(EditorForm).SetKey(byte1,false)
end;

procedure TMyVSTPluginController.OnProgramChange(prgm: integer);
begin
  if EditorForm<>NIL then
    TFormMyVST(EditorForm).SetProgram(prgm);
end;

procedure TMyVSTPluginController.OnEditOpen;
begin
  ResendParameters;
  TFormMyVST(EditorForm).HostUpdateParameter:=DoUpdateHostParameter;
  TFormMyVST(EditorForm).HostKeyEvent:=DoKeyEvent;
  TFormMyVST(EditorForm).HostPrgmChange:=DoProgramChange;
end;

procedure TMyVSTPluginController.doKeyEvent(key:integer;_on:boolean); // from UI
begin
  MidiEventToProcessor(MIDI_NOTE_ON,key,127*ord(_on));
end;

procedure TMyVSTPluginController.DoUpdateHostParameter(id: integer; value: double); // from UI
const MIDI_CC = $B0;
begin
  UpdateHostParameter(id,value);
  MidiOut(MIDI_CC,id,round(127*value));   // just a test
end;

procedure TMyVSTPluginController.GetParametersDescription(params:TVST3ParameterArray);
begin
  AddParameters(params);
end;

procedure TMyVSTPluginController.UpdateParameter(id: integer;  value: double);
begin
  TFormMyVST(EditorForm).UpdateParameter(id,value);
end;

const UID_CProcessorMyVSTPlugin: TGUID =  '{FF8E679B-05F1-4D21-A750-4C4B9BBF26EE}';
const UID_CControllerMyVSTPlugin: TGUID = '{6CF78B9E-D088-48D4-9DD4-C5D376DAD447}';
function GetVSTInstrumentInfo:TVSTInstrumentInfo;
begin
  with result do
  begin
    with PluginDef do
    begin
      vst3processorid := UID_CProcessorMyVSTPlugin;
      vst3controllerid:=UID_CControllerMyVSTPlugin;
      vst3processorclass:=TMyVSTPluginProcessor;
      vst3controllerclass:=TMyVSTPluginController;
      name:= 'SimpleSynth4';
      vst3editorclass := TFormMyVST;
      isSynth:=true;
    end;
    with factoryDef do
    begin
      vendor:='Ermers Consultancy';
      url:='www.ermers.org';
      email:='ruud@ermers.org';
    end;
  end;
end;

end.
