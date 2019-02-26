(
//1. server config
s = Server.local;
s.options.outDevice_(
	"Fireface UCX (23732049)"
	 //"Built-in Output"

);

s.options.numOutputBusChannels_(2);
s.options.inDevice_(
	"Fireface UCX (23732049)"
	//"Built-in Microph"
);

s.options.numInputBusChannels_(2);
s.options.sampleRate_(48000);
s.options.memSize_(2.pow(20));
s.latency_(0.1);
s.newBusAllocators;

ServerBoot.removeAll;
ServerTree.removeAll;
ServerQuit.removeAll;
MIDIIn.connectAll;

~oscout = NetAddr("localhost",6448);

~makeBusses = {
~bus = Dictionary.new;
	~bus.add(\ears -> Bus.audio(s, 2));
	~bus.add(\dynamics -> Bus.audio(s, 2));
	~bus.add(\grains -> Bus.audio(s, 2));
	~bus.add(\wekOut_1 -> Bus.control(s, 1));
	~bus.add(\wekOut_2 -> Bus.control(s, 1));
	~bus.add(\wekOut_3 -> Bus.control(s, 1));
	~bus.add(\wekOut_4 -> Bus.control(s, 1));
	~bus.add(\wekOut_5 -> Bus.control(s, 1));
	~bus.add(\freqDiff -> Bus.control(s, 1));
	~bus.add(\ampDiff -> Bus.control(s, 1));
	~bus.add(\entropyDiff -> Bus.control(s, 1));
	~bus.add(\centroidDiff -> Bus.control(s, 1));
	~bus.add(\flatnessDiff -> Bus.control(s, 1));
	~bus.add(\freqSc -> Bus.control(s, 1));
	~bus.add(\ampSc -> Bus.control(s, 1));
	~bus.add(\entropySc -> Bus.control(s, 1));
	~bus.add(\centroidSc -> Bus.control(s, 1));
	~bus.add(\flatnessSc -> Bus.control(s, 1));
};

~cleanup = {
	s.newBusAllocators;
ServerBoot.removeAll;
ServerTree.removeAll;
ServerQuit.removeAll;
};

~makeNodes = {
	s.bind({
		~synthGrp =Group.new(~inGrp, \addAfter);
		~dynGrp =Group.new(~synthGrp, \addAfter);
		~listenGrp = Group.new(~dynGrp, \addAfter);
			a= Synth(\input, target:~inGrp);
		b= Synth(\grains, target:~synthGrp);
		c= Synth(\buffers, target:~synthGrp);
		d =Synth(\dynamics, target: ~dynGrp);
		i =Synth(\ears, target: ~listenGrp);
	});
};

~makeBuffers = {
	f = Buffer.alloc(s, s.sampleRate * 1);
};
	// pitch1, pitch2, onset, entropySc_1, entropySc_2,
	//centroidSc_1, centroidSc_2, flatnessSc_1, flatnessSc_2, ampSc_1, ampSc_

ServerBoot.add(~makeBusses);
ServerBoot.add(~makeBuffers);
ServerQuit.add(~cleanup);

s.waitForBoot({

	s.sync;

SynthDef(\input,
		{ arg lpf = 15000, hpf=30;
			var lowpass = LPF.ar(SoundIn.ar([0,1]), lpf); // Channel 1 and 2 summed
			var highpass = HPF.ar(lowpass, LinExp.kr(In.kr(~bus[\wekOut_3]).lag(2),0,1,20,100));
			Out.ar(~bus[\dynamics], highpass);
			Out.ar(~bus[\grains],highpass);
}).add;

		SynthDef(\buffers,
		{		var in= Mix(In.ar(~bus[\grains]));
		var rec = RecordBuf.ar(in, f);
}).add;

		SynthDef(\grains,
	{|t_trig=0,hpf=100 gSpeed=10, gBuf, gRate =1, gInt=4, limlev=1, glengthmin = 0.005, glengthmax=0.15, gdensmin = 0.5, gdensmax=60, amp=0, lag =3|
			var gDur = LinExp.kr(In.kr(~bus[\wekOut_2]).lag(lag),0,1,glengthmin,glengthmax);
			var gPan = WhiteNoise.kr;
			var trigger = Impulse.ar((In.kr(~bus[\wekOut_4]).poll.lag(lag).linexp(0,1,gdensmax, gdensmin)));
			var phRate = LinExp.kr(In.kr(~bus[\wekOut_3]).lag(lag),0,1,0.1,1);
			var gPos = Phasor.ar(0, phRate/SampleRate.ir);
			var grains = GrainBuf.ar(2, trigger, gDur, f, gRate, gPos,4, gPan, -1);
			Out.ar(0, LeakDC.ar(LPF.ar(grains,7000)*amp.lag(0.2)));
}).add;


	SynthDef(\dynamics,
		{arg thresh=0.01, compRatio=2, compAttk=0.01, compRel=0.2, amp=0;
			var in = In.ar(~bus[\dynamics],2);
			var comp = Compander.ar(in, Mix(in).sanitize,
				thresh: thresh, slopeBelow: 1,
				slopeAbove: 1/compRatio,clampTime:  compAttk,
				relaxTime:  compRel);
			var limiter = Limiter.ar(comp);
			Out.ar(0,limiter.scope*amp.lag(0.2));
			Out.ar(~bus[\ears],limiter);
	}).add;

	SynthDef(\ears, // Feature extractor: _1 = Input (mics/pickups), _2 = output (speakers)
		{|onsetTresh=0.1, reset=0, lag=0.3, trig|
			var freq_1, hasFreq_1, freq_2, hasFreq_2, trigger, in_1, in_2, amp_1, ampSc_1, amp_2, ampSc_2, chain_1, chain_2, fft_1, fft_2, onset_1, entropic_1, entropy_1, entropySc_1, entropic_2, entropy_2, entropySc_2, centroid_1, centroidSc_1,centroid_2, centroidSc_2, flatness_1, flatnessSc_1, flatness_2, flatnessSc_2, ampDiff, entropyDiff, centroidDiff, flatnessDiff, oscsend, freqSc_1, freqSc_2, freqDiff, melScale;
			trigger = Impulse.kr(10);
			in_1 = Mix(SoundIn.ar([0,1])); // Audio in, what the inputs hear
			in_2 = Mix(In.ar(~bus[\ears], 2)); // What the outputs hear
			amp_1 = Amplitude.kr(in_1).lag(lag);
			ampSc_1 = LinLin.kr(amp_1, RunningMin.kr(amp_1, reset),
			RunningMax.kr(amp_1, reset),0,1).lag(lag);
			amp_2 = Amplitude.kr(in_2).lag(lag);
			ampSc_2 = LinLin.kr(amp_2, RunningMin.kr(amp_2, reset),
			RunningMax.kr(amp_2, reset),0,1);
			# freq_1, hasFreq_1 = Tartini.kr(in_1); // Pitch detection
			# freq_2, hasFreq_2 = Tartini.kr(in_2);
			freqSc_1 = LinLin.kr(freq_1, RunningMin.kr(freq_1, reset),
				RunningMax.kr(freq_1, reset),0,1).lag(lag); // Pitch detection scaled (0-1)
			freqSc_2 = LinLin.kr(freq_2, RunningMin.kr(freq_2, reset),
			RunningMax.kr(freq_2, reset),0,1).lag(lag);
			chain_1 = FFT(LocalBuf(2048), in_1);
			chain_2 = FFT(LocalBuf(2048), in_2);
			onset_1 = Onsets.kr(chain_1, onsetTresh, \rcomplex); // Onset detection
			entropic_1 = SpectralEntropy.kr(chain_1); // Spectral entropy
			entropy_1 = entropic_1 * (amp_1.min(0.2)*5.0); // Entropy scaled by amplitude
			entropySc_1 = LinLin.kr(entropic_1, RunningMin.kr(entropic_1, reset),
			RunningMax.kr(entropic_1, reset),0,1).lag(lag); // Entropy scaled (0-1)
			entropic_2 = SpectralEntropy.kr(chain_2);
			entropySc_2 = LinLin.kr(entropic_2, RunningMin.kr(entropic_2, reset),
			RunningMax.kr(entropic_2, reset),0,1).lag(lag);
			entropy_2 = entropic_2 * (amp_2.min(0.2)*5.0);
			centroid_1 = SpecCentroid.kr(chain_1).clip(30, 6000); // Spectral centroid
			centroidSc_1 = LinLin.kr(centroid_1, RunningMin.kr(centroid_1, reset),
			RunningMax.kr(centroid_1, reset),0,1).lag(lag); // Spectral centroid scaled (0-1);
			centroid_2 = SpecCentroid.kr(chain_2).clip(30, 6000);
			centroidSc_2 = LinLin.kr(centroid_2, RunningMin.kr(centroid_2, reset),
			RunningMax.kr(centroid_2, reset),0,1).lag(lag);
			flatness_1 = SpecFlatness.kr(chain_1).lag(0.1); // Spectral Flatness
			flatnessSc_1 = LinLin.kr(flatness_1, RunningMin.kr(flatness_1, reset),
				RunningMax.kr(flatness_1, reset),0,1).lag(lag); // Spectral Flatness scaled (0,1)
			flatness_2 = SpecFlatness.kr(chain_2).lag(0.1);
			flatnessSc_2 = LinLin.kr(flatness_2, RunningMin.kr(flatness_2, reset),
			RunningMax.kr(flatness_1, reset),0,1).lag(lag);
			ampDiff = (ampSc_1-ampSc_2).abs; // Amplitude difference between scaled inputs and outputs in absolute numbers (0-1).
			freqDiff = (freqSc_1-freqSc_2).abs; // Frequency difference between scaled inputs and outputs in absolute numbers (0-1).
			entropyDiff = (entropySc_1-entropySc_2).abs; // Entropy difference between scaled inputs and outputs in absolute numbers (0-1).
			centroidDiff = (centroidSc_1-centroidSc_2).abs; // Centroid difference between scaled inputs and outputs in absolute numbers (0-1).
			flatnessDiff = (flatnessSc_1-flatnessSc_2).abs; // Flatness difference between scaled inputs and outputs in absolute numbers (0-1).
			melScale = MFCC.kr(chain_2); // Mel Frequency cepstral coefficietns
			oscsend = SendReply.kr(trigger, '/ears', [melScale++[amp_2,freq_2, entropy_2, centroid_2, flatness_2,freqDiff, ampDiff, entropyDiff, centroidDiff, flatnessDiff, freqSc_2, ampSc_2, entropySc_2, centroidSc_2, flatnessSc_2]].sanitize);
}).add;

	 OSCFunc({ arg msg, time; // Sending feature extraction OSC messages to Wekinator
		~oscout.sendMsg('/wek/inputs', *msg[3..20]);
		~bus[\freqDiff].set(msg[21]);
		~bus[\ampDiff].set(msg[22]);
		~bus[\entropyDiff].set(msg[23]);
		~bus[\centroidDiff].set(msg[24]);
		~bus[\flatnessDiff].set(msg[25]);
		~bus[\freqSc].set(msg[26]);
		~bus[\ampSc].set(msg[27]);
		~bus[\entropySc].set(msg[28]);
		~bus[\centroidSc].set(msg[29]);
		~bus[\flatnessSc].set(msg[30]);
},'/ears', s.addr);

 k = OSCdef.new(\fromWek,
{arg msg, time;
			~bus[\wekOut_1].set(msg[1]);
			~bus[\wekOut_2].set(msg[2]);
			~bus[\wekOut_3].set(msg[3]);
			~bus[\wekOut_4].set(msg[4]);
			~bus[\wekOut_5].set(msg[5]);
			//msg.postln
			},
		'/wek/outputs', NetAddr("localhost"), 12000
		);

	Window.closeAll;
w = Window("feedback", Rect(100, 100, 600, 300))
.front
.alwaysOnTop_(true);

w.view.decorator_(FlowLayout(w.bounds, 30@30, 15@15));
~arrays = Array.fill(2, {
	arg view;
	view = CompositeView(w, 250@250)
	.background_(Color.grey);
	view.decorator_(FlowLayout(view.bounds, 10@5, 10@5));
});

StaticText(~arrays[0], 200@30).string_("Ins and Outs");
~arrays[0].decorator.nextLine;
StaticText(~arrays[0], 30@15).string_("HP");
NumberBox(~arrays[0],  30@30).value_(30).clipLo_(20).action_({ arg obj; a.set(\hpf, obj.value)});
StaticText(~arrays[0], 30@15).string_("LP");
NumberBox(~arrays[0],  50@30).value_(15000).clipLo_(1000).action_({ arg obj; a.set(\lpf, obj.value)});
~arrays[0].decorator.nextLine;
	~vol1=Array.fill(2, {Slider(~arrays[0], 30@120)});
	StaticText(~arrays[0], 200@30).string_("Master  Grains  Limiter Level");
	~arrays[1].decorator.nextLine;
~vol1[0].action_( { arg obj; d.set(\amp, obj.value)});
~vol1[1].action_( { arg obj; b.set(\amp, obj.value)});
	StaticText(~arrays[1], 200@30).string_("Wekinator control");
	ToggleButton(~arrays[1],"Start Recording",{ arg button,bool;
    "Recording".postln;
		~oscout.sendMsg('/wekinator/control/startRecording');
},{
    "Not recording".postln;
		~oscout.sendMsg('/wekinator/control/stopRecording');
},false, 30, 50,Color.red, Color.white );
	ToggleButton(~arrays[1],"Stop Wekinator Input",{ arg button,bool;
    "Input stopped".postln;
		k.disable;
},{
    "Input started".postln;
		k.enable;
},false, 30, 50,Color.red, Color.white);
	~arrays[1].decorator.nextLine;
	Button(~arrays[1], 30, 50).states_([["train"]]).mouseDownAction_({~oscout.sendMsg('/wekinator/control/train')});
	~arrays[1].decorator.nextLine;
		ToggleButton(~arrays[1],"Run",{ arg button,bool;
    "Running".postln;
	~oscout.sendMsg('/wekinator/control/startRunning');
},{
    "Not running".postln;
		~oscout.sendMsg('/wekinator/control/stopRunning');
},false, 30, 50, Color.green, Color.red);
	s.sync;

	ServerTree.add(~makeNodes);

s.freeAll;
s.sync;

	"done".postln;
});
)

