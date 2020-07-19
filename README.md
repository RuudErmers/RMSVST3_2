# RMSVST3_2
Delphi VST3 wrapper

Highlights:

- Implements VST3 protocol
- Implements Fruityplug
- Separate Processor and Controller

## Description
Many VST3 aspects are supported, but not all.

The main class is TVSTInstrument which implements the functionality of a VST3/Fruityplug Plugin.

It is a combined Processor/Controller and implements the following:
- Audio processing (synth or effect), two channel only. 
- Midi CC processing
- Parameter processing
- Presets
- Tempo / Playstate

There is a simple example that implements some of the basics in a Simple Synthesizer VSTi. 
There is documentation on how to implement this wrapper code. Tested in Reaper and FL Studio.

I am planning to expand this software if some people are interested in it.
But I am not sure if anyone is still developing in Delphi. 
So if you have any interest, let me know.

I really would like to expand this to something like (the VST part of ) the old DelphiAsioVST stuff which was popular in the past.
Delphi is still a very strong language and with the community edition is my favorite platform. See my website www.ermers.org for other stuff.

So..if you want to give it a try... just load the example project(s) and hit Build. (You must have CodeSite installed, see the GetIt Package manager).
Copy the VST3 to your plugin directory and who knows...


## TVSTInstrument API
In this framework you find Delphi wrapper code to create VST2, VST3 and FruityPlug Instruments. For this, there’s a translation between a new wrapper-type TVSTInstrument and the various platforms. 
Instead of having three versions for these platforms, you create a derivative from TVSTInstrument.
An example of this is the class TMyVSTPlugin, found in the SimplesynthCommon directory.
In this document, the API of TVSTInstrument is discussed. 
In the document Description SimpleSynth, the working of the simple synth is explained.
You can read this and that document in any order.

To make the TMyVSTPlugin available as plug-in, you have to describe it in a VSTInstrumentInfo record and make it available through the function  GetVSTInstrumentInfo. If all goes well your plugin will be instantiated in your DAW. From there you have control over it with this API.
Please use the RMSMyVST2, RMSMyVST3, FruityPlug projects as a starting base as they include the startup code.

Declaration:	

The function `GetVSTInstrumentInfo` must be implemented delivering the following information:

|||
|-|-|
|vst3id|A unique UUID for you’re a VST3 plugin|
|vst2id|A unique 4 letter string for a VST2 plugin|
|cl|The class name: here: TMyVSTPlugin. It must me derived from TVST3Instrument.|
|Ecl|The class name for your editor: here: TFormMyVST|
|isSynth|true if this is a synth.|
|softMidThru|if you want to pass all midi events to the next plugin and a few other information fields.|

 
## API

The API is split into two parts:

1. **Processor**<br>
Methods concerned with the audio processing part. You should not update the UI from a Processor call. 

2. **Controller**<br>
Methods concerned with the parameters, presets and editor

|Processor|All methods are virtual and optional for processing|
|-|-|
|proc OnSysexEvent(s:string);|s starts with $F0 and ends with $F7|
|proc OnMidiEvent(byte0,byte1,byte2:byte);|Remark: NOT called from UI Thread|
|proc MidiOut(const b1, b2, b3: byte);|Remark: NOT called from UI Thread|
|proc Process32(samples,channels:integer; inputp, outputp: PPSingle);|Here you process your audio. Inputp and outputp are arrays of array with the first subscribe the channel and the second the sampleposition. See example.|
|proc OnSamplerateChanged(samplerate:single);	| |
|proc OnPlayStateChanged(playing:boolean;ppq:inte);|Called when the DAW changes play state, or position|
|proc OnTempoChanged(tempo:single);	| |
|proc updateProcessorParameter(id,value)|Virtual method called when a Host parameter changes (NON-UI thread). You should update your ‘Processor’ or ‘Model’|
|proc OnInitialize;|Called after creation. Here you should add your parameters|
|proc AddParameter(id:integer;title, shorttitle,units:string;min,max,val:double)|Adds a parameter to the system. Each parameter has an unique id and some other values|
|func getParameterAsString(id:integer;value:double):string;	|Value is between 0 and 1!|
|proc updateHostParameter(id,value)	|Updates a parameter on the Host|
|proc updateEditorParameter(id,value)	|Virtual method called when a Host parameter changes (UI thread). You should update your UI.|
|proc ResendParameters	|Resends all parameters through UpdateEditorParameter (must be called from UI thread, e.g. when opening your plugin editor)|
|function getEditorClass:TformClass;|	Virtual method. You can override the default creation of the editor class (as defined in GetVST3InstrumentInfo) here (normally not needed) 
|proc OnEditOpen|Virtual method. Called when the editor opens. It could be wise to call ResendParameters and to create a mechanism so when a UI element changes you send the changed value to the host.|
|proc OnPresetChange(prgm:integer);	|Virtual method. Only needed if you want to show the preset number in the UI. |
|proc OnEditClose|	Virtual method. For cleanup, but normally not necessary.|
|proc OnFinalize|	Virtual method. For cleanup, you should release all resources, especially timers.|
|Proc OnEditIdle	|Called regularly if the Editor is open|

Missing from the API (will be implemented on request)
-	Setting/Getting preset names. Setting the preset number (to host)
-	MidiOut (for  VST3) 
-	MidiIn stuff like MPC, aftertouch (for VST3)

## Description SimpleSynth

SimpleSynth is an example of how to use TVSTInstrument. 
As you can see in the RMSVST2, RMSVST3 and FruityPlug directories, you can create various versions of a plugin for various frameworks.
This document describes the architecture of TMyVstPlugin

TMyVSTPlugin inherits from TVSTInstrument to create a simple synth plugin: It only reacts to Midi Note On/Off and has a few parameters for Cutoff, Resonance and PulseWidth.

### UMyVST.pas

Defines the `TMyVSTPlugin`. In `GetVSTInstrumentInfo` it describes the architecture: 
The class to create is TMyVSTPlugin and the editor class is `TFormMyVST`.

In OnInitialize 
-	the real synth is created: TSImpleSynth.Create.
-	Three parameters are added.
In Process we need to fill the audiobuffer. 
For this we call FsimpleSynth.process which generates 1 sample. We copy it to all channels and call this function ‘samples’ time.
In OnEditOpen we are notified that the editor will open. Note that the actual editor is an instance of TFormMyVST. This form gets two callbacks when a parameter is changed in the editor or a key is pressed. Then we call resendParameters which resends the parameter values.
In UpdateEditorParameter we update the editor
In UpdateUpdateProcessorParameter we update the synth

When a key is pressed this is forwarded to the SimpleSynth (onKeyEvent)

### UMyVSTDSP.pas

Here `TSimpleSynth` is implemented. Although the internals might be interesting, the main focus are the public methods, `updateParameter`, `Process` and `onKeyEvent`. These have been discussed in UMyVST.

### UMyVSTForm.pas

The OnKeyEvent and UpdateHostParameter are filled in from UMyVST and make it possible to send keys to the SimpleSynth and send parameter changes to the Host. UpdateEditorPreset and SetKey are used to show the correct settings. SetPreset is just a simple call showing the current preset. Note that when changing preset, the parameters will automagically update here and in the SimpleSynth.
