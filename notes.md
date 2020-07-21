## Internal remarks for Ruud

Midi In / CCs and Note On/Off and Parameters

The system generates Midi events and simulated Parameters, but how does it work?

||VST2|VST3*|FruityPlug|
|-|-|-|-|
|OnMidiEvent|HostCallProcessEvents<br>This seams to be called from UI Thread..|Notes: Processor thread, not UI. Parameters (CC): Processor thread, not UI.|MidiIn procedure (GM) (GUI / Mixer Thread)=ThreadSafe
|UpdateEditorParameter|HostCallSetParameter NOT from UI gets Cached and send in OnIdle.<br>Also calls to UpdateHostParameter are treated the same way 	Controller thread, UI thread|See VST2|
|UpdateProcessorParameter|HostCallSetParameter and 
UpdateHostParameter call this, on NON-UI	Processor thread, not UI.|See VST2|
|UpdateEditorMidiEvent|Not used|Parameters(CC)
Controller thread, UI thread|Not used|

In VST3 MIDI CC is constructed with Parameter Changes.

There is a BIG difference between OnMidiEvent for VST3 vs. VST2/Fruityplug..

My plugins process OnMidiCC as follows:
-	Parameters CC event:	-> Update Model (=Processor) and call UpdateHostParameters
-	Note Events		-> Update Model (=Processor) and UI::Keyboard but this does not use the UI

“Thus”, this works with all formats: VST2 and FP use the Loopback in HostCallSetParameter. VST3 works because UpdateEditorMidiEvent gets called. 
	Note that in Fruity Loops the parameter trick does not work (and MIDI CC don’t get called) and that in Reaper I get ‘faultly’ receive on a ParameterCC message (luckily!)
So, for now MIDI support is at least to say ‘buggy’…but it’s not my fault.. (nor Steinberg)

OK, I changed this for VST3. There is now an OnIdle thingie… 
